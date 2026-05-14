import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';

class AudioRecorderBar extends StatefulWidget {
  final Function(String filePath, int durationSeconds) onRecordingComplete;
  final VoidCallback onCancel;

  const AudioRecorderBar({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<AudioRecorderBar> createState() => _AudioRecorderBarState();
}

class _AudioRecorderBarState extends State<AudioRecorderBar> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _outputPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
        widget.onCancel();
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _outputPath = path;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
    });
    if (path != null && mounted) {
      widget.onRecordingComplete(path, _elapsedSeconds);
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () async {
              _timer?.cancel();
              await _recorder.stop();
              // Delete incomplete file
              if (_outputPath != null) {
                final file = File(_outputPath!);
                if (await file.exists()) await file.delete();
              }
              widget.onCancel();
            },
          ),
          // Pulsing record icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? Colors.red : Colors.transparent,
            ),
          ),
          const SizedBox(width: 8),
          // Elapsed time
          Text(
            _formatDuration(_elapsedSeconds),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const Spacer(),
          // Send / Stop button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
