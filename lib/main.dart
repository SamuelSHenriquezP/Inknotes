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
import 'screens/note_editor_screen.dart';
import 'services/home_widget_bridge.dart';

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
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _pendingWidgetAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidgetBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'openNote') {
        setState(() => _pendingWidgetAction = call.arguments as String?);
      }
    });
    _readWidgetAction();
  }

  Future<void> _readWidgetAction() async {
    try {
      final action = await HomeWidgetBridge.channel.invokeMethod<String>(
        'initialAction',
      );
      if (mounted && action != null) {
        setState(() => _pendingWidgetAction = action);
      }
    } on MissingPluginException {
      // Native widget support is currently Android only.
    }
  }

  void _openPendingNote(NotesController notes) {
    final action = _pendingWidgetAction;
    if (action == null ||
        notes.isLoading ||
        !_securityController.isInitialized ||
        _securityController.isLocked) {
      return;
    }
    _pendingWidgetAction = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final existing = notes.notes
          .where((note) => note.id == action)
          .firstOrNull;
      final note = existing ?? notes.createNote();
      _navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => NoteEditorScreen(noteId: note.id),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeWidgetBridge.channel.setMethodCallHandler(null);
    _securityController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _securityController.lockIfProtected();
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext != null) {
        navigatorContext.read<NotesController>().flushPendingChanges();
      }
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
      child: Consumer3<ThemeController, SecurityController, NotesController>(
        builder: (context, themeController, securityController, notes, _) {
          _openPendingNote(notes);
          return MaterialApp(
            navigatorKey: _navigatorKey,
            builder: (context, child) => Stack(
              children: [
                if (child != null)
                  ExcludeFocus(
                    excluding:
                        securityController.isLocked ||
                        !securityController.isInitialized,
                    child: ExcludeSemantics(
                      excluding:
                          securityController.isLocked ||
                          !securityController.isInitialized,
                      child: child,
                    ),
                  ),
                if (!securityController.isInitialized)
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFF5F3ED)),
                  ),
                if (securityController.isLocked)
                  const Positioned.fill(child: PinLockScreen()),
              ],
            ),
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
            home: const DashboardScreen(),
          );
        },
      ),
    );
  }
}
