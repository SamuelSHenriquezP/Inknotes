import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../models/note_attachment_model.dart';

class VoiceMemoSheet extends StatefulWidget {
  final bool isDark;

  const VoiceMemoSheet({super.key, required this.isDark});

  static Future<NoteAttachmentModel?> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet<NoteAttachmentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceMemoSheet(isDark: isDark),
    );
  }

  @override
  State<VoiceMemoSheet> createState() => _VoiceMemoSheetState();
}

class _VoiceMemoSheetState extends State<VoiceMemoSheet> {
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isPlayingPreview = false;
  int _secondsRecorded = 0;
  int _playbackPosition = 0;

  Timer? _recordTimer;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    _playbackTimer?.cancel();
    setState(() {
      _isRecording = true;
      _hasRecorded = false;
      _isPlayingPreview = false;
      _secondsRecorded = 0;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsRecorded++);
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
      if (_secondsRecorded == 0) _secondsRecorded = 1;
      _playbackPosition = 0;
    });
  }

  void _togglePreview() {
    if (_isPlayingPreview) {
      _playbackTimer?.cancel();
      setState(() => _isPlayingPreview = false);
    } else {
      setState(() {
        _isPlayingPreview = true;
        if (_playbackPosition >= _secondsRecorded) _playbackPosition = 0;
      });

      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_playbackPosition >= _secondsRecorded) {
          t.cancel();
          setState(() {
            _isPlayingPreview = false;
            _playbackPosition = 0;
          });
        } else {
          setState(() => _playbackPosition++);
        }
      });
    }
  }

  void _saveMemo() {
    if (_secondsRecorded == 0) {
      Navigator.of(context).pop();
      return;
    }

    final formatted = _format(_secondsRecorded);
    final attachment = NoteAttachmentModel(
      id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
      type: AttachmentType.audio,
      data: 'audio_payload_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Nota de voz ($formatted)',
      durationSeconds: _secondsRecorded,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop(attachment);
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
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final accent = theme.accentColor;
    final onAccent = theme.onAccentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.sheetRadius)),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              _isRecording
                  ? 'Grabando nota de voz...'
                  : _hasRecorded
                      ? 'Nota de voz lista'
                      : 'Grabar audio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isRecording ? 'Habla con claridad para registrar tu idea' : 'Escucha la vista previa antes de adjuntarla',
              style: TextStyle(fontSize: 12.5, color: textSecondary),
            ),

            const SizedBox(height: 28),

            Text(
              _isPlayingPreview
                  ? '${_format(_playbackPosition)} / ${_format(_secondsRecorded)}'
                  : _format(_secondsRecorded),
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: _isRecording ? Colors.redAccent : textPrimary,
              ),
            ),

            const SizedBox(height: 20),

            // Waveform animation
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(24, (index) {
                  final h = _isRecording
                      ? (10.0 + (index % 5) * 6.0 + ((index + _secondsRecorded) % 4) * 5.0)
                      : (_hasRecorded ? (10.0 + (index % 6) * 5.0) : 8.0);
                  final active = _isPlayingPreview &&
                      (index / 24.0) <= (_playbackPosition / (_secondsRecorded > 0 ? _secondsRecorded : 1));

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 3.5,
                    height: h.clamp(6.0, 40.0),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.redAccent.withValues(alpha: 0.85)
                          : active
                              ? accent
                              : (widget.isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 32),

            if (_isRecording) ...[
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.06, 1.06),
                    duration: 600.ms,
                  ),
              const SizedBox(height: 12),
              Text('Pulsar para finalizar', style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600)),
            ] else if (_hasRecorded) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.refresh_rounded, size: 24),
                    onPressed: _startRecording,
                    tooltip: 'Grabar de nuevo',
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _togglePreview,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: Icon(
                        _isPlayingPreview ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: onAccent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 24),
                    onPressed: _saveMemo,
                    tooltip: 'Guardar nota de voz',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Descartar', style: TextStyle(color: textSecondary)),
              ),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
