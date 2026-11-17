import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/security_controller.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';

enum PinModalMode { create, verify, change }

class PinLockScreen extends StatefulWidget {
  final PinModalMode? modalMode;
  final String? customTitle;

  const PinLockScreen({
    super.key,
    this.modalMode,
    this.customTitle,
  });

  static Future<String?> showSetupModal(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PinLockScreen(modalMode: PinModalMode.create),
    );
  }

  static Future<bool?> showVerifyModal(
    BuildContext context, {
    String? title,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinLockScreen(
        modalMode: PinModalMode.verify,
        customTitle: title,
      ),
    );
  }

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entered = '';
  String? _firstPin;
  String? _errorText;
  bool _confirmStep = false;

  void _onDigit(String digit) {
    if (_entered.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _errorText = null;
      _entered += digit;
    });
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 110), _handleComplete);
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorText = null;
      _entered = _entered.substring(0, _entered.length - 1);
    });
  }

  Future<void> _handleComplete() async {
    if (!mounted) return;
    final security = context.read<SecurityController>();

    if (widget.modalMode == PinModalMode.create) {
      if (!_confirmStep) {
        setState(() {
          _firstPin = _entered;
          _entered = '';
          _confirmStep = true;
        });
        return;
      }
      if (_entered == _firstPin) {
        Navigator.of(context).pop(_entered);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _firstPin = null;
          _confirmStep = false;
          _errorText = 'Los códigos no coinciden. Inténtalo de nuevo.';
        });
      }
      return;
    }

    if (widget.modalMode == PinModalMode.verify) {
      if (security.verifyPin(_entered)) {
        Navigator.of(context).pop(true);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _errorText = 'PIN incorrecto';
        });
      }
      return;
    }

    // Gate mode (full screen lock)
    final ok = security.unlockWithPin(_entered);
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _entered = '';
        _errorText = 'PIN incorrecto. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeController>(context);
    final bgPrimary = theme.bgPrimary;
    final surfaceCard = theme.surfaceCard;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;
    final borderSubtle = theme.borderSubtle;
    final accent = theme.accentColor;

    final isModal = widget.modalMode != null;
    final title = widget.customTitle ??
        (widget.modalMode == PinModalMode.create
            ? (_confirmStep ? 'Confirma tu PIN' : 'Crea tu código PIN')
            : widget.modalMode == PinModalMode.verify
                ? 'Introduce tu PIN'
                : 'inkNotes bloqueado');
    final subtitle = widget.modalMode == PinModalMode.create
        ? (_confirmStep
            ? 'Ingresa los mismos 4 dígitos para confirmar'
            : 'Protege tus notas privadas con un PIN de 4 dígitos')
        : 'Ingresa tu PIN de 4 dígitos para continuar';

    final body = Column(
      mainAxisSize: isModal ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isModal)
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Icon(
            widget.modalMode == PinModalMode.create
                ? Icons.lock_outline_rounded
                : Icons.shield_outlined,
            color: accent,
            size: 24,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _entered.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? accent : Colors.transparent,
                border: Border.all(
                  color: _errorText != null
                      ? Colors.redAccent
                      : (filled ? accent : borderSubtle),
                  width: 1.8,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: _errorText != null
              ? Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ]) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row
                      .map((d) => _PinKeyButton(
                            label: d,
                            bgColor: isModal ? theme.surfaceElevated : surfaceCard,
                            borderColor: borderSubtle,
                            textColor: textPrimary,
                            onTap: () => _onDigit(d),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 68,
                    height: 58,
                    child: isModal
                        ? TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: Text(
                              'Cerrar',
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _PinKeyButton(
                    label: '0',
                    bgColor: isModal ? theme.surfaceElevated : surfaceCard,
                    borderColor: borderSubtle,
                    textColor: textPrimary,
                    onTap: () => _onDigit('0'),
                  ),
                  SizedBox(
                    width: 68,
                    height: 58,
                    child: IconButton(
                      onPressed: _entered.isEmpty ? null : _onBackspace,
                      icon: Icon(
                        Icons.backspace_outlined,
                        color: _entered.isEmpty
                            ? textSecondary.withValues(alpha: 0.35)
                            : textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (isModal) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: surfaceCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.sheetRadius),
          ),
        ),
        child: SafeArea(top: false, child: body),
      );
    }

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  const _PinKeyButton({
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 68,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
