import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../models/note_attachment_model.dart';

class DrawingSheet extends StatefulWidget {
  final bool isDark;

  const DrawingSheet({super.key, required this.isDark});

  static Future<NoteAttachmentModel?> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet<NoteAttachmentModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DrawingSheet(isDark: isDark),
    );
  }

  @override
  State<DrawingSheet> createState() => _DrawingSheetState();
}

class DrawnStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const DrawnStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class _DrawingSheetState extends State<DrawingSheet> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final List<DrawnStroke> _strokes = [];
  DrawnStroke? _activeStroke;

  late Color _color;
  double _strokeWidth = 3.5;
  bool _isEraser = false;

  List<Color> get _palette => [
    widget.isDark ? Colors.white : const Color(0xFF111111),
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Green
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF8B5CF6), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _color = widget.isDark ? Colors.white : const Color(0xFF111111);
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
    }
  }

  void _clear() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.clear());
    }
  }

  Future<void> _export() async {
    if (_strokes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final base64String = base64Encode(byteData.buffer.asUint8List());
      final attachment = NoteAttachmentModel(
        id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
        type: AttachmentType.drawing,
        data: base64String,
        name: 'Dibujo a mano',
        createdAt: DateTime.now(),
      );

      if (mounted) Navigator.of(context).pop(attachment);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;
    final bgColor = theme.surfaceCard;
    final canvasBg = theme.bgPrimary;
    final textPrimary = theme.textPrimary;
    final borderSubtle = theme.borderSubtle;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.sheetRadius)),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: Column(
        children: [
          // Drag Notch
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: textPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  'Lienzo de Dibujo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Deshacer',
                  icon: const Icon(Icons.undo_rounded, size: 21),
                  color: _strokes.isEmpty ? Colors.grey : textPrimary,
                  onPressed: _strokes.isEmpty ? null : _undo,
                ),
                IconButton(
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.delete_outline_rounded, size: 21),
                  color: _strokes.isEmpty ? Colors.grey : textPrimary,
                  onPressed: _strokes.isEmpty ? null : _clear,
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _export,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.onAccentColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                  ),
                  child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Drawing Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: Container(
                  color: canvasBg,
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _activeStroke = DrawnStroke(
                            points: [details.localPosition],
                            color: _isEraser ? canvasBg : _color,
                            strokeWidth: _isEraser ? _strokeWidth * 3.5 : _strokeWidth,
                          );
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          if (_activeStroke != null) {
                            _activeStroke = DrawnStroke(
                              points: List.from(_activeStroke!.points)..add(details.localPosition),
                              color: _activeStroke!.color,
                              strokeWidth: _activeStroke!.strokeWidth,
                            );
                          }
                        });
                      },
                      onPanEnd: (_) {
                        setState(() {
                          if (_activeStroke != null) {
                            _strokes.add(_activeStroke!);
                            _activeStroke = null;
                          }
                        });
                      },
                      child: CustomPaint(
                        painter: _StrokePainter(
                          strokes: _strokes,
                          currentStroke: _activeStroke,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tooling Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surfaceElevated,
              border: Border(top: BorderSide(color: borderSubtle)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Pluma',
                    icon: Icon(
                      Icons.edit_rounded,
                      color: !_isEraser ? theme.accentColor : Colors.grey,
                    ),
                    onPressed: () => setState(() => _isEraser = false),
                  ),
                  IconButton(
                    tooltip: 'Borrador',
                    icon: Icon(
                      Icons.auto_fix_normal_rounded,
                      color: _isEraser ? theme.accentColor : Colors.grey,
                    ),
                    onPressed: () => setState(() => _isEraser = true),
                  ),

                  Container(
                    height: 22,
                    width: 1,
                    color: borderSubtle,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Stroke sizes
                  ...[2.0, 4.0, 7.0].map((w) {
                    final sel = _strokeWidth == w;
                    return GestureDetector(
                      onTap: () => setState(() => _strokeWidth = w),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? textPrimary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: w + 2,
                            height: w + 2,
                            decoration: BoxDecoration(
                              color: textPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const Spacer(),

                  // Colors
                  if (!_isEraser)
                    Wrap(
                      spacing: 6,
                      children: _palette.map((c) {
                        final sel = _color.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: sel
                                    ? (widget.isDark ? Colors.white : Colors.black)
                                    : Colors.black12,
                                width: sel ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<DrawnStroke> strokes;
  final DrawnStroke? currentStroke;

  _StrokePainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }
  }

  void _paintStroke(Canvas canvas, DrawnStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.strokeWidth
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

    if (stroke.points.length == 2) {
      path.lineTo(stroke.points[1].dx, stroke.points[1].dy);
    } else {
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
