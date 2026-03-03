import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('history');
  await Hive.openBox('settings');

  Hive.box('settings').put('hasCompletedOnboarding', false);

  runApp(const ExplainThisApp());
}

class ExplainThisApp extends StatelessWidget {
  const ExplainThisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explain This',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue,
        brightness: Brightness.dark,
        ), useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const RootDecider(),
    );
  }
}

class RootDecider extends StatefulWidget {
  const RootDecider({super.key});

  @override
  State<RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<RootDecider> {
  bool _initialized = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  void _loadFlag() {
    final settings = Hive.box('settings');
    final hasCompleted =
        settings.get('hasCompletedOnboarding', defaultValue: false) as bool;

    setState(() {
      _showOnboarding = !hasCompleted;
      _initialized = true;
    });
  }

  void _finishOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(onFinished: _finishOnboarding);
    }

    return const MainNavigation();
  }
}