import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../models/note_attachment_model.dart';

class AudioPlayerWidget extends StatefulWidget {
  final NoteAttachmentModel attachment;
  final bool isDark;
  final VoidCallback? onDelete;

  const AudioPlayerWidget({
    super.key,
    required this.attachment,
    required this.isDark,
    this.onDelete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  int _currentSecond = 0;
  Timer? _timer;

  int get _totalSeconds => widget.attachment.durationSeconds ?? 30;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() {
        _isPlaying = true;
        if (_currentSecond >= _totalSeconds) _currentSecond = 0;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_currentSecond >= _totalSeconds) {
          timer.cancel();
          setState(() {
            _isPlaying = false;
            _currentSecond = 0;
          });
        } else {
          setState(() => _currentSecond++);
        }
      });
    }
  }

  void _seekToRatio(double ratio) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSecond = (ratio * _totalSeconds).round().clamp(0, _totalSeconds);
    });
  }

  String _format(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;
    final bgCard = theme.surfaceCard;
    final borderSubtle = theme.borderSubtle;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final accent = theme.accentColor;
    final onAccent = theme.onAccentColor;
    final progress = _totalSeconds > 0 ? (_currentSecond / _totalSeconds).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderSubtle, width: 1.2),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: onAccent,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.attachment.name ?? 'Nota de voz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${_format(_currentSecond)} / ${_format(_totalSeconds)}',
                      style: TextStyle(fontSize: 11, color: textSecondary, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        _seekToRatio(ratio);
                      },
                      onHorizontalDragUpdate: (details) {
                        final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        _seekToRatio(ratio);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 18,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(24, (index) {
                              final h = _isPlaying
                                  ? (5.0 + (((index + _currentSecond * 3) * 7) % 13))
                                  : (5.0 + ((index * 6) % 11));
                              final played = (index / 24.0) <= progress;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(horizontal: 0.8),
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: played
                                        ? accent
                                        : borderSubtle,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: textSecondary,
              onPressed: widget.onDelete,
              tooltip: 'Eliminar audio',
            ),
          ],
        ],
      ),
    );
  }
}
