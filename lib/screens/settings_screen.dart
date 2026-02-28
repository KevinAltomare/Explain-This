import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box settingsBox;
  late Box historyBox;

  @override
  void initState() {
    super.initState();
    settingsBox = Hive.box('settings');
    historyBox = Hive.box('history');

    // Clean up old device-camera key
    settingsBox.delete('useDeviceCamera');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final saveHistory =
        settingsBox.get('saveHistory', defaultValue: true) as bool;

    var language = settingsBox.get('language', defaultValue: 'en');

    // Normalize legacy values
    if (language == "English") {
      language = "en";
      settingsBox.put('language', "en");
    } else if (language == "Spanish") {
      language = "es";
      settingsBox.put('language', "es");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // ⭐ HISTORY SECTION
          Text(
            "History",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          SwitchListTile(
            title: Text(
              "Save History",
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              "Automatically save explanations to your history.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            value: saveHistory,
            onChanged: (value) {
              settingsBox.put('saveHistory', value);
              setState(() {});
            },
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return theme.colorScheme.primary;
              }
              return theme.colorScheme.onSurfaceVariant;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return theme.colorScheme.primary.withValues(alpha: 0.4);
              }
              return theme.colorScheme.surfaceContainerHighest;
            }),
          ),

          const SizedBox(height: 12),

          TextButton.icon(
            icon: Icon(
              Icons.delete_forever,
              color: theme.colorScheme.error,
            ),
            label: Text(
              "Delete All History",
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                useRootNavigator: true,
                builder: (dialogContext) => AlertDialog(
                  title: const Text("Clear History"),
                  content: const Text(
                    "Are you sure you want to delete all saved explanations?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await historyBox.clear();

                if (!context.mounted) return;

                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("History cleared"),
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // ⭐ LANGUAGE SECTION
          Text(
            "Language",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: InputDecoration(
              labelText: "App Language",
              labelStyle: theme.textTheme.bodyMedium,
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: "en",
                child: Text("English"),
              ),
              DropdownMenuItem(
                value: "es",
                child: Text("Spanish"),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                settingsBox.put('language', value);
                setState(() {});
              }
            },
          ),

          const SizedBox(height: 32),

          // ⭐ ABOUT SECTION
          Text(
            "About",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              "Version",
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              "1.0.0",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),

          ListTile(
            leading: Icon(
              Icons.privacy_tip_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              "Privacy Policy",
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              "Read how your data is handled.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                useRootNavigator: true,
                builder: (context) => AlertDialog(
                  title: const Text("Privacy Policy"),
                  content: const Text(
                    "Explain This processes your documents locally on your device. "
                    "No data is uploaded or stored externally. "
                    "History is saved only if you enable it in Settings.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}