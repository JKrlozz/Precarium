import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/search_provider.dart';
import 'providers/download_provider.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/downloads_screen.dart';
import 'widgets/mini_player.dart';
import 'theme/app_theme.dart';
import 'services/audio_player_service.dart';

class PrecariumApp extends StatefulWidget {
  const PrecariumApp({super.key});

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
        theme: AppTheme.darkTheme,
        home: const MainShell(),
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
      context.read<PlayerProvider>().init();
      context.read<DownloadProvider>().init(
        onDownloadComplete: () => context.read<LibraryProvider>().loadLibrary(),
      );
    });
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
