import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../controllers/theme_controller.dart';
import '../widgets/security_sheet.dart';
import '../widgets/theme_sheet.dart';

class OptionsScreen extends StatefulWidget {
  final int initialTab;

  const OptionsScreen({super.key, this.initialTab = 0});

  static Future<void> open(BuildContext context, {int initialTab = 0}) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => OptionsScreen(initialTab: initialTab),
        transitionsBuilder: (_, animation, _, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.10, 0.0),
                end: Offset.zero,
              ).animate(curve),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1.0).animate(curve),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeController>(context);
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.bgPrimary,
      appBar: AppBar(
        backgroundColor: theme.bgPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Opciones',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                theme.toggleTheme();
              },
              tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  key: ValueKey(isDark),
                  color: theme.textPrimary,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Selector animado de pestañas: Apariencia | Seguridad y respaldo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.borderSubtle, width: 1.0),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 230),
                      curve: Curves.easeOutCubic,
                      alignment: _selectedTab == 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.surfaceCard,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: theme.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildSegmentItem(
                          theme: theme,
                          index: 0,
                          icon: Icons.palette_outlined,
                          label: 'Apariencia',
                        ),
                        _buildSegmentItem(
                          theme: theme,
                          index: 1,
                          icon: Icons.shield_outlined,
                          label: 'Seguridad',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 240.ms).slideY(begin: -0.05, end: 0),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0.0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _selectedTab == 0
                    ? const ThemeSheet(
                        key: ValueKey('options_appearance'),
                        embedded: true,
                      )
                    : const SecuritySheet(
                        key: ValueKey('options_security'),
                        embedded: true,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentItem({
    required ThemeController theme,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    final fg = isSelected ? theme.textPrimary : theme.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedTab != index) {
            HapticFeedback.selectionClick();
            setState(() => _selectedTab = index);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
