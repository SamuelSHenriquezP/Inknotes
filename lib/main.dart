import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme/app_theme.dart';
import 'controllers/theme_controller.dart';
import 'controllers/notes_controller.dart';
import 'controllers/security_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pin_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const InkNotesApp());
}

class InkNotesApp extends StatefulWidget {
  const InkNotesApp({super.key});

  @override
  State<InkNotesApp> createState() => _InkNotesAppState();
}

class _InkNotesAppState extends State<InkNotesApp> with WidgetsBindingObserver {
  final SecurityController _securityController = SecurityController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _securityController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _securityController.lockIfProtected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
        ChangeNotifierProvider<NotesController>(
          create: (_) => NotesController(),
        ),
        ChangeNotifierProvider<SecurityController>.value(
          value: _securityController,
        ),
      ],
      child: Consumer2<ThemeController, SecurityController>(
        builder: (context, themeController, securityController, _) {
          return MaterialApp(
            title: 'inkNotes',
            debugShowCheckedModeBanner: false,
            themeMode: themeController.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            theme: AppTheme.createThemeData(
              preset: themeController.preset,
              isDark: false,
            ),
            darkTheme: AppTheme.createThemeData(
              preset: themeController.preset,
              isDark: true,
            ),
            home: Stack(
              children: [
                const DashboardScreen(),
                if (securityController.isLocked)
                  const Positioned.fill(
                    child: PinLockScreen(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
