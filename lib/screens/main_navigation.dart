import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'in_app_camera_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _scanKey = GlobalKey<NavigatorState>();
  final _historyKey = GlobalKey<NavigatorState>();
  final _settingsKey = GlobalKey<NavigatorState>();

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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final currentNavigator =
            _navigatorForIndex(_currentIndex).currentState;

        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // SCAN TAB — now has its own Navigator again
            Offstage(
              offstage: _currentIndex != 0,
              child: Navigator(
                key: _scanKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => const InAppCameraScreen(),
                  );
                },
              ),
            ),

            Offstage(
              offstage: _currentIndex != 1,
              child: Navigator(
                key: _historyKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => const HistoryScreen(),
                  );
                },
              ),
            ),

            Offstage(
              offstage: _currentIndex != 2,
              child: Navigator(
                key: _settingsKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == _currentIndex) {
              final nav = _navigatorForIndex(index).currentState;
              nav?.popUntil((route) => route.isFirst);
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
}