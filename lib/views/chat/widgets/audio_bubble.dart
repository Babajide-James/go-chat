import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';

class AudioBubble extends StatefulWidget {
  final String audioUrl;
  final String? localFilePath;
  final int durationSeconds;
  final bool isMine;
  final String status; // 'sending', 'sent', 'delivered', 'seen'

  const AudioBubble({
    super.key,
    required this.audioUrl,
    this.localFilePath,
    required this.durationSeconds,
    required this.isMine,
    this.status = 'sent',
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  late AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;

  // In-session cache: reuse the same URL without re-fetching
  static final Map<String, Duration> _durationCache = {};

  bool get _isSending => widget.status == 'sending' && widget.audioUrl.isEmpty;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _duration = Duration(seconds: widget.durationSeconds);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
        final key = widget.audioUrl.isNotEmpty
            ? widget.audioUrl
            : widget.localFilePath ?? '';
        if (key.isNotEmpty) _durationCache[key] = dur;
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isSending) return; // Can't play while still uploading

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      // Prefer network URL if available, fall back to local file
      if (widget.audioUrl.isNotEmpty) {
        await _player.play(UrlSource(widget.audioUrl));
      } else if (widget.localFilePath != null &&
          widget.localFilePath!.isNotEmpty) {
        await _player.play(DeviceFileSource(widget.localFilePath!));
      }
      await _player.setPlaybackRate(_speed);
    }
  }

  void _toggleSpeed() async {
    setState(() {
      _speed = _speed == 1.0 ? 2.0 : 1.0;
    });
    await _player.setPlaybackRate(_speed);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final bubbleColor = widget.isMine ? AppTheme.primaryOrange : Colors.white;
    final iconColor = widget.isMine ? Colors.white : AppTheme.primaryOrange;
    final textColor = widget.isMine ? Colors.white : AppTheme.textDark;
    final trackColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.4)
        : AppTheme.lightPeach;
    final activeTrackColor = widget.isMine ? Colors.white : AppTheme.darkOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.06),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/pause button (or sending indicator)
          if (_isSending)
            Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(iconColor),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _togglePlayback,
              child: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: iconColor,
                size: 36,
              ),
            ),
          const SizedBox(width: 8),
          // Progress + duration
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(activeTrackColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isSending
                          ? 'Sending...'
                          : isPlaying || _position.inSeconds > 0
                              ? _formatDuration(_position)
                              : _formatDuration(_duration),
                      style: TextStyle(fontSize: 11, color: textColor),
                    ),
                    // Speed toggle
                    if (!_isSending)
                      GestureDetector(
                        onTap: _toggleSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_speed.toStringAsFixed(0)}×',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: iconColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
