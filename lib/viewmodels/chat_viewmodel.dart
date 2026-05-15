import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/services/firestore_service.dart';
import '../core/services/upload_queue_service.dart';
import '../core/constants/firestore_paths.dart';
import '../core/utils/media_compressor.dart';
import '../core/enums/message_type.dart';
import '../core/enums/message_status.dart';
import '../models/message.dart';

/// Holds before/after compression stats for the UI to display.
class CompressionResult {
  final double originalMb;
  final double compressedMb;
  final String type;

  CompressionResult({
    required this.originalMb,
    required this.compressedMb,
    required this.type,
  });

  double get savingsPercent =>
      ((originalMb - compressedMb) / originalMb * 100).clamp(0, 100);

  String get summary =>
      '${type == "image" ? "📷" : "🎬"} '
      '${originalMb.toStringAsFixed(2)} MB → '
      '${compressedMb.toStringAsFixed(2)} MB '
      '(${savingsPercent.toStringAsFixed(0)}% smaller)';
}

class ChatViewModel extends ChangeNotifier {
  final String conversationId;
  final FirestoreService _firestoreService = FirestoreService();
  final UploadQueueService _uploadQueue = UploadQueueService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController scrollController = ScrollController();

  StreamSubscription? _messagesSubscription;
  StreamSubscription<Map<String, double>>? _progressSubscription;
  Timer? _typingDebounce;
  Timer? _idleTimer;

  bool _isTyping = false;
  CompressionResult? _lastCompression;

  bool _isSearching = false;
  String _searchQuery = '';

  String? _editingMessageId;
  String? _editingMessageText;

  bool _isCompressing = false;

  CompressionResult? get lastCompression => _lastCompression;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  String? get editingMessageId => _editingMessageId;
  String? get editingMessageText => _editingMessageText;
  String? get currentUserId => _currentUserId;
  bool get isCompressing => _isCompressing;

  // --- Pending media attachment (preview before send) ---
  File? _pendingMediaFile;
  String? _pendingMediaType;
  File? get pendingMediaFile => _pendingMediaFile;
  String? get pendingMediaType => _pendingMediaType;

  // --- Per-message upload progress from the queue service ---
  Map<String, double> _uploadProgressMap = {};
  Map<String, double> get uploadProgressMap => _uploadProgressMap;

  /// Returns upload progress for a specific message, or null if not uploading.
  double? getUploadProgress(String messageId) {
    final progress = _uploadProgressMap[messageId];
    if (progress == null) return null;
    if (progress < 0) return null; // -1.0 means failed
    return progress;
  }

  /// Returns true if the message upload has failed.
  bool isUploadFailed(String messageId) {
    return _uploadProgressMap[messageId] == -1.0;
  }

  void setPendingMedia(File file, String type) {
    _pendingMediaFile = file;
    _pendingMediaType = type;
    _lastCompression = null;
    _isCompressing = true;
    notifyListeners();

    // Compress in background, then update with result
    _compressPendingMedia(file, type);
  }

  Future<void> _compressPendingMedia(File file, String type) async {
    try {
      final originalBytes = await file.length();
      final originalMb = originalBytes / (1024 * 1024);

      File compressed;
      if (type == 'image') {
        compressed = await MediaCompressor.compressImage(file);
      } else {
        compressed = await MediaCompressor.compressVideo(file);
      }

      final compressedBytes = await compressed.length();
      final compressedMb = compressedBytes / (1024 * 1024);

      _pendingMediaFile = compressed;
      _lastCompression = CompressionResult(
        originalMb: originalMb,
        compressedMb: compressedMb,
        type: type,
      );
      _isCompressing = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error compressing media: $e');
      _isCompressing = false;
      notifyListeners();
    }
  }

  void clearPendingMedia() {
    _pendingMediaFile = null;
    _pendingMediaType = null;
    _lastCompression = null;
    _isCompressing = false;
    notifyListeners();
  }

  String _partnerName = 'Chat';
  String get partnerName => _partnerName;

  ChatViewModel(this.conversationId) {
    _resolvePartnerName();
    _listenToUploadProgress();
  }

  void _listenToUploadProgress() {
    _progressSubscription = _uploadQueue.progressStream.listen((progress) {
      _uploadProgressMap = progress;
      notifyListeners();
    });
    // Also grab current state
    _uploadProgressMap = Map.from(_uploadQueue.currentProgress);
  }

  /// Fetches conversation doc → finds partner UID → fetches their displayName.
  Future<void> _resolvePartnerName() async {
    try {
      final convoDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!convoDoc.exists) return;
      final participants = List<String>.from(
        convoDoc.data()?['participants'] ?? [],
      );
      final partnerId = participants.firstWhere(
        (p) => p != _currentUserId,
        orElse: () => '',
      );
      if (partnerId.isEmpty) return;

      final userDoc = await _firestoreService.getUser(partnerId);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final name =
            data?['displayName'] as String? ??
            data?['email'] as String? ??
            'Chat';
        _partnerName = name;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error resolving partner name: $e');
    }
  }

  Stream<QuerySnapshot> get messagesStream {
    return _firestoreService.getMessages(conversationId);
  }

  Stream<DocumentSnapshot> get conversationStream {
    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .snapshots();
  }

  void onTextChanged(String text) {
    if (_currentUserId == null) return;

    if (!_isTyping && text.isNotEmpty) {
      _isTyping = true;
      _firestoreService.updateTypingStatus(
        conversationId,
        _currentUserId,
        true,
      );
    }

    if (text.isEmpty) {
      _clearTypingStatus();
      return;
    }

    _typingDebounce?.cancel();
    _idleTimer?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 600), () {
      _firestoreService.updateTypingStatus(
        conversationId,
        _currentUserId,
        true,
      );
    });
    _idleTimer = Timer(const Duration(seconds: 3), () {
      _clearTypingStatus();
    });
  }

  void _clearTypingStatus() {
    if (_currentUserId == null || !_isTyping) return;
    _isTyping = false;
    _firestoreService.updateTypingStatus(conversationId, _currentUserId, false);
  }

  Future<void> sendTextMessage(String text) async {
    final uid = _currentUserId;
    if (uid == null || text.trim().isEmpty) return;

    if (_editingMessageId != null) {
      await _editMessage(text);
      return;
    }

    final timestamp = Timestamp.now();
    final message = Message(
      id: '', // Will be generated by Firestore
      senderId: uid,
      text: text.trim(),
      type: MessageType.text,
      reactions: {},
      status: MessageStatus.sending, // Optimistic UI
      readBy: {},
      deletedFor: [],
      deletedForEveryone: false,
      createdAt: timestamp,
    );

    try {
      _clearTypingStatus(); // Clear typing status immediately on send

      await _firestoreService.sendMessage(conversationId, message.toMap());
      await _firestoreService.updateConversationLastMessage(
        conversationId,
        text.trim(),
        timestamp,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// Copy a file to a permanent local directory so it survives between sessions.
  Future<File> _copyToPermanentStorage(File file, String subfolder) async {
    final appDir = await getApplicationDocumentsDirectory();
    final uploadDir = Directory(p.join(appDir.path, 'go_chat_uploads', subfolder));
    if (!await uploadDir.exists()) {
      await uploadDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
    final permanentPath = p.join(uploadDir.path, fileName);
    return await file.copy(permanentPath);
  }

  /// Send an audio message with offline-first queue.
  ///
  /// 1. Copies the recorded file to permanent storage
  /// 2. Inserts a placeholder Firestore doc (status: sending)
  /// 3. Enqueues the upload — UploadQueueService handles the rest
  Future<void> sendAudioMessage(String filePath, int durationSeconds) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      // Copy to permanent local storage
      final file = File(filePath);
      final permanentFile = await _copyToPermanentStorage(file, 'audio');

      final timestamp = Timestamp.now();
      final message = Message(
        id: '',
        senderId: uid,
        type: MessageType.audio,
        duration: durationSeconds,
        reactions: {},
        status: MessageStatus.sending,
        readBy: {},
        deletedFor: [],
        deletedForEveryone: false,
        createdAt: timestamp,
      );

      final messageData = message.toMap();
      messageData['localFilePath'] = permanentFile.path;

      // Insert placeholder doc — Firestore offline persistence queues this
      final docRef = await _firestoreService.sendMessage(
        conversationId,
        messageData,
      );

      await _firestoreService.updateConversationLastMessage(
        conversationId,
        '🎤 Voice message',
        timestamp,
      );

      // Enqueue for upload
      await _uploadQueue.enqueue(
        conversationId: conversationId,
        firestoreMessageId: docRef.id,
        localFilePath: permanentFile.path,
        mediaType: 'audio',
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending audio: $e');
    }
  }

  /// Send an image/video message with offline-first queue.
  ///
  /// Expects the file to already be compressed (done in setPendingMedia).
  /// 1. Copies compressed file to permanent storage
  /// 2. Inserts a placeholder Firestore doc (status: sending)
  /// 3. Enqueues the upload — UploadQueueService handles the rest
  Future<void> sendMediaMessage(File file, String type) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      // Copy to permanent local storage
      final permanentFile = await _copyToPermanentStorage(
        file,
        type == 'image' ? 'images' : 'videos',
      );

      final timestamp = Timestamp.now();
      final preview = type == 'image' ? '📷 Photo' : '🎬 Video';

      final message = Message(
        id: '',
        senderId: uid,
        type: type == 'image' ? MessageType.image : MessageType.video,
        reactions: {},
        status: MessageStatus.sending,
        readBy: {},
        deletedFor: [],
        deletedForEveryone: false,
        createdAt: timestamp,
      );

      final messageData = message.toMap();
      messageData['localFilePath'] = permanentFile.path;

      // Insert placeholder doc — visible immediately in chat
      final docRef = await _firestoreService.sendMessage(
        conversationId,
        messageData,
      );

      await _firestoreService.updateConversationLastMessage(
        conversationId,
        preview,
        timestamp,
      );

      // Enqueue for upload
      await _uploadQueue.enqueue(
        conversationId: conversationId,
        firestoreMessageId: docRef.id,
        localFilePath: permanentFile.path,
        mediaType: type,
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending media: $e');
    }
  }

  /// Retry a failed upload for a specific message.
  Future<void> retryUpload(String messageId) async {
    await _uploadQueue.retryMessage(messageId);
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      // We need to read the current reactions for this message to toggle properly
      final msgDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.conversations)
          .doc(conversationId)
          .collection(FirestorePaths.messages)
          .doc(messageId)
          .get();

      if (!msgDoc.exists) return;

      final reactions = Map<String, String>.from(
        msgDoc.data()?['reactions'] ?? {},
      );
      final currentReaction = reactions[uid];

      if (currentReaction == emoji) {
        // Remove reaction
        await _firestoreService.updateMessageReaction(
          conversationId,
          messageId,
          uid,
          null,
        );
      } else {
        // Add or change reaction
        await _firestoreService.updateMessageReaction(
          conversationId,
          messageId,
          uid,
          emoji,
        );
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  Future<void> markAsRead(String messageId, Map<String, dynamic> data) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final senderId = data['senderId'] as String?;
    if (senderId == uid) return; // Don't mark our own messages as read

    final readBy = Map<String, dynamic>.from(data['readBy'] ?? {});
    if (readBy.containsKey(uid)) return; // Already marked as read by us

    try {
      await _firestoreService.markMessageAsRead(conversationId, messageId, uid);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching) {
      _searchQuery = '';
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setEditingMessage(String id, String text) {
    _editingMessageId = id;
    _editingMessageText = text;
    notifyListeners();
  }

  void cancelEditing() {
    _editingMessageId = null;
    _editingMessageText = null;
    notifyListeners();
  }

  Future<void> _editMessage(String newText) async {
    if (_editingMessageId == null) return;
    try {
      await _firestoreService.editMessage(
        conversationId,
        _editingMessageId!,
        newText,
      );
      await _firestoreService.updateConversationLastMessage(
        conversationId,
        'Edited: $newText',
        Timestamp.now(),
      );
    } catch (e) {
      debugPrint('Error editing message: $e');
    } finally {
      cancelEditing();
    }
  }

  Future<void> deleteMessageForMe(String messageId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      await _firestoreService.deleteMessageForMe(
        conversationId,
        messageId,
        uid,
      );
    } catch (e) {
      debugPrint('Error deleting message for me: $e');
    }
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _firestoreService.deleteMessageForEveryone(
        conversationId,
        messageId,
      );
      await _firestoreService.updateConversationLastMessage(
        conversationId,
        '🚫 This message was deleted.',
        Timestamp.now(),
      );
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _progressSubscription?.cancel();
    _typingDebounce?.cancel();
    _idleTimer?.cancel();
    _clearTypingStatus();
    scrollController.dispose();
    super.dispose();
  }
}
