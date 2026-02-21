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
  }

  @override
  Widget build(BuildContext context) {
    final saveHistory =
        settingsBox.get('saveHistory', defaultValue: true) as bool;

    final language =
        settingsBox.get('language', defaultValue: 'English') as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // ⭐ HISTORY SECTION
          const Text(
            "History",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          SwitchListTile(
            title: const Text(
              "Save History",
              style: TextStyle(fontSize: 18),
            ),
            subtitle: const Text(
              "Automatically save explanations to your history.",
            ),
            value: saveHistory,
            onChanged: (value) {
              settingsBox.put('saveHistory', value);
              setState(() {});
            },
          ),

          const SizedBox(height: 12),

          TextButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              "Delete All History",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                useRootNavigator: true,
                builder: (dialogContext) => AlertDialog(
                  title: const Text("Clear History"),
                  content: const Text(
                      "Are you sure you want to delete all saved explanations?"),
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

                if (mounted) setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("History cleared")),
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // ⭐ LANGUAGE SECTION
          const Text(
            "Language",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: const InputDecoration(
              labelText: "App Language",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: "English",
                child: Text("English"),
              ),
              DropdownMenuItem(
                value: "Spanish",
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
          const Text(
            "About",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          ListTile(
            title: const Text("Version"),
            subtitle: const Text("1.0.0"),
            leading: const Icon(Icons.info_outline),
          ),

          ListTile(
            title: const Text("Privacy Policy"),
            subtitle: const Text("Read how your data is handled."),
            leading: const Icon(Icons.privacy_tip_outlined),
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