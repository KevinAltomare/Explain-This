import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Each tab gets its own Navigator key
  final _scanKey = GlobalKey<NavigatorState>();
  final _historyKey = GlobalKey<NavigatorState>();
  final _settingsKey = GlobalKey<NavigatorState>();

  // Helper to pick the right navigator
  GlobalKey<NavigatorState> _navigatorForIndex(int index) {
    switch (index) {
      case 0:
        return _scanKey;
      case 1:
        return _historyKey;
      case 2:
        return _settingsKey;
      default:
        return _scanKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // We manually control all back navigation
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final currentNavigator =
            _navigatorForIndex(_currentIndex).currentState!;

        if (currentNavigator.canPop()) {
          // Pop inside the current tab's stack
          currentNavigator.pop();
        } else {
          // No more routes → allow system back (exit app)
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildOffstageNavigator(0, _scanKey, const HomeScreen()),
            _buildOffstageNavigator(1, _historyKey, const HistoryScreen()),
            _buildOffstageNavigator(2, _settingsKey, const SettingsScreen()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == _currentIndex) {
              // User tapped the same tab again → reset that tab's navigation stack
              final currentNavigator = _navigatorForIndex(index).currentState;
              currentNavigator?.popUntil((route) => route.isFirst);
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt),
              label: "Scan",
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: "History",
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }

  // Builds each tab's independent navigation stack
  Widget _buildOffstageNavigator(
      int index, GlobalKey<NavigatorState> key, Widget screen) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: key,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => screen,
          );
        },
      ),
    );
  }
}