import 'package:flutter/material.dart';
import 'in_app_camera_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

// GLOBAL main navigator key (used by ImageReviewScreen)
final GlobalKey<NavigatorState> mainNavKey = GlobalKey<NavigatorState>();

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Keys for each tab's nested navigator
  final GlobalKey<NavigatorState> _scanKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _historyKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _settingsKey = GlobalKey<NavigatorState>();

  int _cameraInstanceId = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(
        key: mainNavKey,
        onGenerateRoute: (_) {
          return MaterialPageRoute(
            builder: (_) => Stack(
              children: [
                // SCAN TAB — visible only when selected
                if (_currentIndex == 0)
                  Navigator(
                    key: _scanKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => InAppCameraScreen(
                          key: ValueKey(_cameraInstanceId),
                        ),
                      );
                    },
                  ),

                // HISTORY TAB
                if (_currentIndex == 1)
                  Navigator(
                    key: _historyKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      );
                    },
                  ),

                // SETTINGS TAB
                if (_currentIndex == 2)
                  Navigator(
                    key: _settingsKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // 1. Clear any pushed screens above the tab root
          if (mainNavKey.currentState != null &&
              mainNavKey.currentState!.canPop()) {
            mainNavKey.currentState!.popUntil((route) => route.isFirst);
          }

          // 2. Tapping the same tab (Scan)
          if (index == _currentIndex) {
            if (index == 0) {
              // Force a fresh camera
              _cameraInstanceId++;
              setState(() {});
            }
            return;
          }

          // 3. Switch tabs
          setState(() {
            _currentIndex = index;
          });

          // 4. Switching TO Scan → rebuild camera
          if (index == 0) {
            _cameraInstanceId++;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}