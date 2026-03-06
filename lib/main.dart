import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';
import 'package:explain_this/services/billing_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  await Hive.openBox('history');
  await Hive.openBox('settings');

  await BillingService.instance.init();

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
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  void _loadFlag() async {
    final settings = Hive.box('settings');
    final hasCompleted =
        settings.get('hasCompletedOnboarding', defaultValue: false) as bool;

    final premium = await BillingService.instance.isPremium();    

    setState(() {
      _showOnboarding = !hasCompleted;
      _isPremium = premium; // true to test premium features
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

    return MainNavigation(isPremium: _isPremium);
  }
}