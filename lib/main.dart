import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app_state.dart';
import 'screens/copy_screen.dart';
import 'screens/history_screen.dart';
import 'screens/today_screen.dart';
import 'service/tracker_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lets the background service send updates to the UI.
  FlutterForegroundTask.initCommunicationPort();
  TrackerService.init();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AutoPunch',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
      darkTheme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTaskData(Object data) => notifyDataChanged();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permissions or Wi-Fi may have changed while the app was in the background.
    if (state == AppLifecycleState.resumed) notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [TodayScreen(), HistoryScreen(), CopyScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wifi), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'History'),
          NavigationDestination(icon: Icon(Icons.copy_all), label: 'Copy'),
        ],
      ),
    );
  }
}
