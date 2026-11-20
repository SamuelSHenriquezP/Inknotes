import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/notes_controller.dart';
import '../controllers/security_controller.dart';
import '../controllers/theme_controller.dart';
import '../formatters/writer_text_formatter.dart';
import '../screens/pin_lock_screen.dart';
import '../theme/app_theme.dart';

class SecuritySheet extends StatelessWidget {
  final bool embedded;

  const SecuritySheet({super.key, this.embedded = false});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SecuritySheet(),
    );
  }

  Future<void> _handlePinToggle(
    BuildContext context,
    SecurityController security,
    bool enable,
  ) async {
    if (enable) {
      final newPin = await PinLockScreen.showSetupModal(context);
      if (newPin != null && newPin.length == 4) {
        await security.setPin(newPin);
        if (context.mounted) {
          _showSnack(context, 'Bloqueo con PIN activado');
        }
      }
    } else {
      final verified = await PinLockScreen.showVerifyModal(
        context,
        title: 'Confirma tu PIN para desactivar',
      );
      if (verified == true) {
        await security.disablePin();
        if (context.mounted) {
          _showSnack(context, 'Bloqueo con PIN desactivado');
        }
      }
    }
  }

  Future<void> _handleChangePin(
    BuildContext context,
    SecurityController security,
  ) async {
    final verified = await PinLockScreen.showVerifyModal(
      context,
      title: 'Verifica tu PIN actual',
    );
    if (verified != true || !context.mounted) return;

    final newPin = await PinLockScreen.showSetupModal(context);
    if (newPin != null && newPin.length == 4) {
      await security.setPin(newPin);
      if (context.mounted) {
        _showSnack(context, 'Código PIN actualizado');
      }
    }
  }

  Future<void> _exportManualBackup(
    BuildContext context,
    NotesController notes,
  ) async {
    try {
      final jsonStr = notes.buildBackupJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'inknotes_respaldo_$stamp.json';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          subject: 'Copia de seguridad inkNotes ($stamp)',
          text:
              'Respaldo manual de inkNotes (${notes.notes.length} notas, ${notes.folders.length} carpetas).',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'No se pudo exportar la copia: $e');
      }
    }
  }

  Future<void> _importManualBackup(
    BuildContext context,
    NotesController notes,
    ThemeController theme,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'inknotes', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          _showSnack(context, 'No se pudo leer el archivo seleccionado');
        }
        return;
      }

      final rawJson = utf8.decode(bytes);
      final parsed = notes.previewBackupJson(rawJson);
      if (parsed == null) {
        if (context.mounted) {
          _showSnack(context, 'El archivo no es una copia válida de inkNotes');
        }
        return;
      }

      if (!context.mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          title: Text(
            'Importar copia de seguridad',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          content: Text(
            'Se encontraron ${parsed.notesCount} nota(s) y ${parsed.foldersCount} carpeta(s).\n\n'
            '¿Deseas combinarlas con tus notas actuales o reemplazar todo el contenido?',
            style: TextStyle(color: theme.textSecondary, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: theme.textSecondary)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary,
                side: BorderSide(color: theme.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                ),
              ),
              child: const Text('Combinar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('replace'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.onAccentColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                ),
              ),
              child: const Text('Reemplazar todo', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (mode == null) return;
      final imported = await notes.importBackupJson(
        rawJson,
        merge: mode == 'merge',
      );
      if (context.mounted) {
        if (imported.success) {
          _showSnack(
            context,
            'Copia restaurada: ${imported.notesImported} notas y ${imported.foldersImported} carpetas.',
          );
        } else {
          _showSnack(context, imported.error ?? 'Error al importar copia');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Error al abrir el archivo: $e');
      }
    }
  }

  Future<void> _restoreAutoBackup(
    BuildContext context,
    NotesController notes,
    ThemeController theme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Restaurar respaldo automático?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'Se restaurarán ${notes.autoBackupNotesCount} nota(s) guardadas en la última copia automática local.',
          style: TextStyle(color: theme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: theme.onAccentColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text('Restaurar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await notes.restoreAutoBackup();
      if (context.mounted) {
        _showSnack(
          context,
          ok
              ? 'Última copia automática restaurada'
              : 'No se encontró ninguna copia automática disponible',
        );
      }
    }
  }

  Future<void> _confirmClearAllData(
    BuildContext context,
    NotesController notes,
    SecurityController security,
    ThemeController theme,
  ) async {
    if (security.pinEnabled) {
      final verified = await PinLockScreen.showVerifyModal(
        context,
        title: 'Confirma tu PIN para borrar datos',
      );
      if (verified != true || !context.mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          '¿Borrar todos los datos?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'Esta acción eliminará permanentemente todas tus notas y carpetas de este dispositivo.',
          style: TextStyle(color: theme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text('Borrar todo', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notes.clearAllData();
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSnack(context, 'Todos los datos locales fueron eliminados');
      }
    }
  }

  void _showPrivacyPolicyModal(BuildContext context, ThemeController theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          'Política de Privacidad y Seguridad',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: theme.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _policyBullet(
                theme,
                'Almacenamiento 100% local',
                'Todas tus notas, carpetas, bocetos y configuraciones se guardan exclusivamente en la memoria interna de tu dispositivo.',
              ),
              const SizedBox(height: 12),
              _policyBullet(
                theme,
                'Cero rastreo y sin servidores',
                'inkNotes no recopila datos personales, no incluye analíticas de terceros ni sube información a servidores externos.',
              ),
              const SizedBox(height: 12),
              _policyBullet(
                theme,
                'Código PIN cifrado',
                'Tu código PIN nunca se almacena en texto plano: se protege mediante hash criptográfico SHA-256 local.',
              ),
              const SizedBox(height: 12),
              _policyBullet(
                theme,
                'Control total de respaldos',
                'Tú decides cuándo exportar o importar tus copias en formato JSON y dónde guardarlas bajo tu propia custodia.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: theme.onAccentColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            ),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _policyBullet(ThemeController theme, String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          desc,
          style: TextStyle(
            fontSize: 12.5,
            color: theme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeController>(context);
    final security = Provider.of<SecurityController>(context);
    final notes = Provider.of<NotesController>(context);
    final isDark = theme.isDarkMode;

    final lastBackupLabel = notes.lastAutoBackupAt != null
        ? WriterTextFormatter.formatSpanishRelativeDate(notes.lastAutoBackupAt!)
        : 'Sin respaldo automático aún';

    final innerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: theme.accentColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seguridad y Respaldo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Privacidad local, PIN de acceso y copias de seguridad',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.borderSubtle, height: 1),
          const SizedBox(height: 16),
        ],

        // SECCIÓN 1: SEGURIDAD DE ACCESO
              _sectionHeader(theme, 'SEGURIDAD Y PRIVACIDAD'),
              const SizedBox(height: 8),
              _buildCardGroup(
                theme,
                children: [
                  _buildSwitchRow(
                    theme: theme,
                    icon: Icons.pin_outlined,
                    title: 'Bloqueo con código PIN',
                    subtitle: security.pinEnabled
                        ? 'Protección de 4 dígitos activa (SHA-256)'
                        : 'Solicitar PIN al abrir inkNotes',
                    value: security.pinEnabled,
                    onChanged: (val) => _handlePinToggle(context, security, val),
                  ),
                  if (security.pinEnabled) ...[
                    Divider(color: theme.borderSubtle, height: 1),
                    _buildActionRow(
                      theme: theme,
                      icon: Icons.password_rounded,
                      title: 'Cambiar código PIN',
                      subtitle: 'Actualizar clave de 4 dígitos',
                      onTap: () => _handleChangePin(context, security),
                    ),
                    Divider(color: theme.borderSubtle, height: 1),
                    _buildSwitchRow(
                      theme: theme,
                      icon: Icons.lock_clock_outlined,
                      title: 'Bloquear al salir de la app',
                      subtitle: 'Pedir PIN al volver desde segundo plano',
                      value: security.lockOnBackground,
                      onChanged: security.setLockOnBackground,
                    ),
                    Divider(color: theme.borderSubtle, height: 1),
                    _buildActionRow(
                      theme: theme,
                      icon: Icons.lock_outline_rounded,
                      title: 'Bloquear ahora',
                      subtitle: 'Cerrar sesión visual inmediatamente',
                      onTap: () {
                        Navigator.of(context).pop();
                        security.lockNow();
                      },
                    ),
                  ],
                  Divider(color: theme.borderSubtle, height: 1),
                  _buildSwitchRow(
                    theme: theme,
                    icon: Icons.screenshot_monitor_outlined,
                    title: 'Bloquear capturas y vista previa',
                    subtitle: 'Impide capturas de pantalla y miniatura en multitarea',
                    value: security.preventScreenshots,
                    onChanged: (val) async {
                      await security.setPreventScreenshots(val);
                      if (context.mounted) {
                        _showSnack(
                          context,
                          val
                              ? 'Protección contra capturas activada'
                              : 'Protección contra capturas desactivada',
                        );
                      }
                    },
                  ),
                  Divider(color: theme.borderSubtle, height: 1),
                  _buildSwitchRow(
                    theme: theme,
                    icon: Icons.visibility_off_outlined,
                    title: 'Modo discreto en la lista',
                    subtitle: 'Oculta el contenido de las tarjetas hasta abrir la nota',
                    value: security.hidePreviews,
                    onChanged: security.setHidePreviews,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // SECCIÓN 2: COPIAS DE SEGURIDAD
              _sectionHeader(theme, 'COPIA DE SEGURIDAD'),
              const SizedBox(height: 8),
              _buildCardGroup(
                theme,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportManualBackup(context, notes),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentColor,
                              foregroundColor: theme.onAccentColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                              ),
                            ),
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text(
                              'Exportar',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _importManualBackup(context, notes, theme),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textPrimary,
                              side: BorderSide(color: theme.borderSubtle, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text(
                              'Importar',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: theme.borderSubtle, height: 1),
                  _buildSwitchRow(
                    theme: theme,
                    icon: Icons.autorenew_rounded,
                    title: 'Copia automática local',
                    subtitle: notes.autoBackupEnabled
                        ? 'Activa · $lastBackupLabel (${notes.autoBackupNotesCount} notas)'
                        : 'Guarda un respaldo redundante tras cada cambio',
                    value: notes.autoBackupEnabled,
                    onChanged: (val) async {
                      await notes.setAutoBackupEnabled(val);
                      if (context.mounted) {
                        _showSnack(
                          context,
                          val
                              ? 'Copia automática activada y snapshot creado'
                              : 'Copia automática desactivada',
                        );
                      }
                    },
                  ),
                  if (notes.hasAutoBackup) ...[
                    Divider(color: theme.borderSubtle, height: 1),
                    _buildActionRow(
                      theme: theme,
                      icon: Icons.settings_backup_restore_rounded,
                      title: 'Restaurar última copia automática',
                      subtitle: '$lastBackupLabel · ${notes.autoBackupNotesCount} notas',
                      onTap: () => _restoreAutoBackup(context, notes, theme),
                    ),
                  ],
                  if (notes.autoBackupEnabled) ...[
                    Divider(color: theme.borderSubtle, height: 1),
                    _buildActionRow(
                      theme: theme,
                      icon: Icons.sync_rounded,
                      title: 'Actualizar respaldo automático ahora',
                      subtitle: 'Forzar guardado inmediato del snapshot local',
                      onTap: () async {
                        await notes.runAutoBackupNow();
                        if (context.mounted) {
                          _showSnack(context, 'Respaldo automático actualizado');
                        }
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              // SECCIÓN 3: TRANSPARENCIA Y CONTROL
              _sectionHeader(theme, 'DATOS Y POLÍTICAS'),
              const SizedBox(height: 8),
              _buildCardGroup(
                theme,
                children: [
                  _buildActionRow(
                    theme: theme,
                    icon: Icons.verified_user_outlined,
                    title: 'Política de privacidad y cifrado',
                    subtitle: '100% offline, sin cuentas ni nube externa',
                    onTap: () => _showPrivacyPolicyModal(context, theme),
                  ),
                  Divider(color: theme.borderSubtle, height: 1),
                  _buildActionRow(
                    theme: theme,
                    icon: Icons.delete_forever_outlined,
                    title: 'Borrar todas las notas y carpetas',
                    subtitle: 'Eliminar datos locales de forma permanente',
                    isDanger: true,
                    onTap: () => _confirmClearAllData(context, notes, security, theme),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          );

    if (embedded) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: innerContent,
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        boxShadow: AppTheme.getSoftShadow(isDark),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: innerContent,
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeController theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: theme.textSecondary,
      ),
    );
  }

  Widget _buildCardGroup(
    ThemeController theme, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle, width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildSwitchRow({
    required ThemeController theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.onAccentColor,
      activeTrackColor: theme.accentColor,
      secondary: Icon(icon, size: 20, color: theme.accentColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: theme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: theme.textSecondary,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      dense: true,
    );
  }

  Widget _buildActionRow({
    required ThemeController theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final fg = isDanger ? Colors.redAccent : theme.textPrimary;
    final iconColor = isDanger ? Colors.redAccent : theme.accentColor;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: theme.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: theme.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      dense: true,
    );
  }
}
