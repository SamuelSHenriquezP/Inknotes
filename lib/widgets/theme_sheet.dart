import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../controllers/theme_controller.dart';

class ThemeSheet extends StatelessWidget {
  const ThemeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;

    final bgSheet = themeController.surfaceCard;
    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;
    final accent = themeController.accentColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: bgSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Notch
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título y Toggle Rápido
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diseño & Apariencia',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Personaliza temas, fuentes y lectura',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton.filledTonal(
                    onPressed: themeController.toggleTheme,
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                    tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // SECCIÓN: TEMAS
              Text(
                'PALETA DE COLOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppThemePreset.values.map((preset) {
                  final isSelected = themeController.preset == preset;
                  final previewColor = preset.previewColor(isDark);

                  return GestureDetector(
                    onTap: () => themeController.setPreset(preset),
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 64) / 2,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: preset.surfaceCard(isDark),
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        border: Border.all(
                          color: isSelected ? accent : borderSubtle,
                          width: isSelected ? 2.2 : 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: previewColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black12,
                                    width: 1,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded,
                                    size: 18, color: accent),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: preset.textPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: preset.textSecondary(isDark),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // SECCIÓN: TIPOGRAFÍAS
              Text(
                'TIPOGRAFÍA DE NOTAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              Column(
                children: NoteFontFamily.values.map((font) {
                  final isSelected = themeController.fontFamily == font;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      border: Border.all(
                        color: isSelected ? accent : borderSubtle,
                        width: isSelected ? 1.6 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      onTap: () => themeController.setFontFamily(font),
                      title: Text(
                        font.label,
                        style: font.textStyle(
                          fontSize: 16,
                          color: textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        font.category,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: accent, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // SECCIÓN: TAMAÑO DE TEXTO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TAMAÑO DE TEXTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${themeController.fontSize.toInt()} pt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildSizeOption(
                    context,
                    label: 'Pequeño',
                    size: 14.5,
                    currentSize: themeController.fontSize,
                    onTap: () => themeController.setFontSize(14.5),
                    textPrimary: textPrimary,
                    accent: accent,
                    borderSubtle: borderSubtle,
                  ),
                  const SizedBox(width: 8),
                  _buildSizeOption(
                    context,
                    label: 'Normal',
                    size: 16.5,
                    currentSize: themeController.fontSize,
                    onTap: () => themeController.setFontSize(16.5),
                    textPrimary: textPrimary,
                    accent: accent,
                    borderSubtle: borderSubtle,
                  ),
                  const SizedBox(width: 8),
                  _buildSizeOption(
                    context,
                    label: 'Grande',
                    size: 19.0,
                    currentSize: themeController.fontSize,
                    onTap: () => themeController.setFontSize(19.0),
                    textPrimary: textPrimary,
                    accent: accent,
                    borderSubtle: borderSubtle,
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeOption(
    BuildContext context, {
    required String label,
    required double size,
    required double currentSize,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color accent,
    required Color borderSubtle,
  }) {
    final isSel = (currentSize - size).abs() < 0.5;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            border: Border.all(
              color: isSel ? accent : borderSubtle,
              width: isSel ? 1.8 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              color: isSel ? accent : textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
