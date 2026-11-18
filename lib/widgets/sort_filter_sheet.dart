import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../controllers/notes_controller.dart';
import '../controllers/theme_controller.dart';

class SortFilterSheet extends StatelessWidget {
  const SortFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SortFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesController = Provider.of<NotesController>(context);
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;

    final bgSheet = themeController.surfaceCard;
    final textPrimary = themeController.textPrimary;
    final textSecondary = themeController.textSecondary;
    final borderSubtle = themeController.borderSubtle;
    final accent = themeController.accentColor;
    final onAccent = themeController.onAccentColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Encabezado con título y botón de restablecer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtrar y ordenar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Filtros clásicos y directos',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (notesController.isFilterActive)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notesController.resetSortAndFilter();
                      },
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: textSecondary,
                      ),
                      label: Text(
                        'Restablecer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: borderSubtle, height: 1),
              const SizedBox(height: 16),

              // SECCIÓN 1: TIPO
              Text(
                'TIPO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FilterType.values.map((type) {
                  final isSelected = notesController.filterType == type;
                  return ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      type.icon,
                      size: 15,
                      color: isSelected ? onAccent : textSecondary,
                    ),
                    label: Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? onAccent : textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: accent,
                    backgroundColor: themeController.surfaceElevated.withValues(
                      alpha: 0.6,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : borderSubtle,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      notesController.setFilterType(type);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              Divider(color: borderSubtle, height: 1),
              const SizedBox(height: 16),

              // SECCIÓN 2: ORDENAR POR
              Text(
                'ORDENAR POR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SortCriteria.values.map((criteria) {
                  final isSelected = notesController.sortBy == criteria;
                  return ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      criteria.icon,
                      size: 15,
                      color: isSelected ? onAccent : textSecondary,
                    ),
                    label: Text(
                      criteria.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? onAccent : textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: accent,
                    backgroundColor: themeController.surfaceElevated.withValues(
                      alpha: 0.6,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : borderSubtle,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      notesController.setSortBy(criteria);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              Divider(color: borderSubtle, height: 1),
              const SizedBox(height: 16),

              // SECCIÓN 3: DIRECCIÓN
              Text(
                'DIRECCIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SortDirection.values.map((direction) {
                  final isSelected = notesController.sortDirection == direction;
                  return ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      direction.icon,
                      size: 15,
                      color: isSelected ? onAccent : textSecondary,
                    ),
                    label: Text(
                      direction.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? onAccent : textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: accent,
                    backgroundColor: themeController.surfaceElevated.withValues(
                      alpha: 0.6,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : borderSubtle,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      notesController.setSortDirection(direction);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 26),

              // Botón de confirmación / cerrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.buttonRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
