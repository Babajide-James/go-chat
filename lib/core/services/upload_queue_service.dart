import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';
import 'storage_service.dart';
import '../constants/firestore_paths.dart';

/// Manages offline-resilient media uploads via SQFlite queue.
///
/// Flow:
/// 1. `enqueue()` persists the upload intent in SQFlite
/// 2. `drainQueue()` processes pending items when online
/// 3. Each item uploads to Supabase, then updates the Firestore message doc
/// 4. Exposes per-message progress for the UI
class UploadQueueService {
  static final UploadQueueService _instance = UploadQueueService._internal();
  factory UploadQueueService() => _instance;
  UploadQueueService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final StorageService _storageService = StorageService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final _uuid = const Uuid();

  StreamSubscription<bool>? _connectivitySub;
  bool _isDraining = false;
  static const int _maxRetries = 3;

  /// Per-message upload progress: firestoreMessageId → progress (0.0 – 1.0)
  final Map<String, double> _progressMap = {};
  final StreamController<Map<String, double>> _progressController =
      StreamController<Map<String, double>>.broadcast();

  Stream<Map<String, double>> get progressStream => _progressController.stream;
  Map<String, double> get currentProgress => Map.unmodifiable(_progressMap);

  /// Start listening for connectivity changes to auto-drain the queue.
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = _connectivityService.connectionChange.listen((connected) {
      if (connected) {
        drainQueue();
      }
    });

    // Also try to drain on startup
    _connectivityService.isConnected.then((connected) {
      if (connected) drainQueue();
    });
  }

  /// Enqueue a file for upload.
  ///
  /// [conversationId] — the Firestore conversation doc ID
  /// [firestoreMessageId] — the ID of the message doc already inserted in Firestore
  /// [localFilePath] — absolute path to the compressed file on disk
  /// [mediaType] — 'image', 'video', or 'audio'
  Future<void> enqueue({
    required String conversationId,
    required String firestoreMessageId,
    required String localFilePath,
    required String mediaType,
  }) async {
    final id = _uuid.v4();
    await _localDb.insertQueueItem(
      id: id,
      conversationId: conversationId,
      firestoreMessageId: firestoreMessageId,
      localFilePath: localFilePath,
      mediaType: mediaType,
    );

    _progressMap[firestoreMessageId] = 0.0;
    _emitProgress();

    // Try to process immediately if online
    final connected = await _connectivityService.isConnected;
    if (connected) {
      drainQueue();
    }
  }

  /// Process all pending items in the queue.
  Future<void> drainQueue() async {
    if (_isDraining) return;
    _isDraining = true;

    try {
      final pendingItems = await _localDb.getQueueItems(status: 'pending');
      final failedItems = await _localDb.getQueueItems(status: 'failed');
      final allItems = [...pendingItems, ...failedItems];

      for (final item in allItems) {
        final retries = item['retries'] as int? ?? 0;
        if (retries >= _maxRetries) {
          // Mark permanently failed
          await _localDb.updateQueueItemStatus(item['id'] as String, 'permanently_failed');
          _progressMap.remove(item['firestoreMessageId'] as String);
          _emitProgress();
          continue;
        }

        await _processItem(item);
      }
    } catch (e) {
      debugPrint('Error draining upload queue: $e');
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _processItem(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final conversationId = item['conversationId'] as String;
    final firestoreMessageId = item['firestoreMessageId'] as String;
    final localFilePath = item['localFilePath'] as String;
    final mediaType = item['mediaType'] as String;

    try {
      await _localDb.updateQueueItemStatus(id, 'uploading');
      _progressMap[firestoreMessageId] = 0.05;
      _emitProgress();

      final file = File(localFilePath);
      if (!await file.exists()) {
        debugPrint('Upload queue: file not found at $localFilePath');
        await _localDb.updateQueueItemStatus(id, 'permanently_failed');
        _progressMap.remove(firestoreMessageId);
        _emitProgress();
        return;
      }

      String url;
      if (mediaType == 'audio') {
        url = await _storageService.uploadAudio(file);
      } else {
        final folder = mediaType == 'image' ? 'images' : 'videos';
        url = await _storageService.uploadMedia(
          file,
          folder,
          onProgress: (p) {
            _progressMap[firestoreMessageId] = p;
            _emitProgress();
          },
        );
        url = StorageService.cleanUrl(url);
      }

      // Update the Firestore message with the uploaded URL
      await FirebaseFirestore.instance
          .collection(FirestorePaths.conversations)
          .doc(conversationId)
          .collection(FirestorePaths.messages)
          .doc(firestoreMessageId)
          .update({
        'mediaUrl': url,
        'status': 'sent',
      });

      // Success — remove from queue
      await _localDb.deleteQueueItem(id);
      _progressMap.remove(firestoreMessageId);
      _emitProgress();

      debugPrint('Upload queue: successfully uploaded $mediaType for message $firestoreMessageId');
    } catch (e) {
      debugPrint('Upload queue: failed to upload item $id — $e');
      if (e.toString().contains('row-level security') || e.toString().contains('403') || e.toString().contains('401')) {
        debugPrint('WARNING: Supabase Storage upload failed due to permissions. Since users are authenticated via Firebase Auth, they are considered "anon" by Supabase. Please ensure your Supabase Storage bucket "$mediaType" has a public INSERT policy for anon users, or the upload will permanently fail.');
      }
      await _localDb.incrementQueueItemRetries(id);
      await _localDb.updateQueueItemStatus(id, 'failed');
      _progressMap[firestoreMessageId] = -1.0; // Signal failure to UI
      _emitProgress();
    }
  }

  /// Retry a specific failed message upload.
  Future<void> retryMessage(String firestoreMessageId) async {
    final item = await _localDb.getQueueItemByFirestoreId(firestoreMessageId);
    if (item != null) {
      await _localDb.updateQueueItemStatus(item['id'] as String, 'pending');
      // Reset retries via direct DB update
      final db = await _localDb.database;
      await db.update(
        'upload_queue',
        {'retries': 0, 'status': 'pending'},
        where: 'id = ?',
        whereArgs: [item['id']],
      );
      _progressMap[firestoreMessageId] = 0.0;
      _emitProgress();
      drainQueue();
    }
  }

  /// Check if a message is currently in the upload queue.
  Future<bool> isInQueue(String firestoreMessageId) async {
    final item = await _localDb.getQueueItemByFirestoreId(firestoreMessageId);
    return item != null;
  }

  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(Map.unmodifiable(_progressMap));
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _progressController.close();
  }
}
