import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/search_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/downloads_screen.dart';
import 'widgets/mini_player.dart';
import 'theme/app_theme.dart';
import 'services/audio_player_service.dart';
import 'services/media_notification_service.dart';

class PrecariumApp extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const PrecariumApp({super.key, required this.settingsProvider});

  @override
  State<PrecariumApp> createState() => _PrecariumAppState();
}

class _PrecariumAppState extends State<PrecariumApp> {
  final AudioPlayerService _audioService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _audioService.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.settingsProvider,
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          AppTheme.primaryColor = settings.primaryColor;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LibraryProvider()),
              ChangeNotifierProvider(create: (_) => PlayerProvider(_audioService)),
              ChangeNotifierProvider(create: (_) => SearchProvider()),
              ChangeNotifierProvider(create: (_) => DownloadProvider()),
            ],
            child: MaterialApp(
              title: 'Precarium',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.themeMode,
              home: const MainShell(),
            ),
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final MediaNotificationService _mediaNotification = MediaNotificationService();

  final List<Widget> _screens = const [
    LibraryScreen(),
    SearchScreen(),
    DownloadsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      player.init();
      _mediaNotification.init(player);
      context.read<DownloadProvider>().init(
        onDownloadComplete: () => context.read<LibraryProvider>().loadLibrary(),
      );
    });
  }

  @override
  void dispose() {
    _mediaNotification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: _screens[_currentIndex]),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Biblioteca'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Descargas'),
        ],
      ),
    );
  }
}
