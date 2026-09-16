import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          ),
          ListTile(
            title: const Text('System Default'),
            trailing: themeMode == ThemeMode.system ? const Icon(Icons.check, color: Colors.deepPurple) : null,
            onTap: () {
              ref.read(themeProvider.notifier).setThemeMode('system');
            },
          ),
          ListTile(
            title: const Text('Light'),
            trailing: themeMode == ThemeMode.light ? const Icon(Icons.check, color: Colors.deepPurple) : null,
            onTap: () {
              ref.read(themeProvider.notifier).setThemeMode('light');
            },
          ),
          ListTile(
            title: const Text('Dark'),
            trailing: themeMode == ThemeMode.dark ? const Icon(Icons.check, color: Colors.deepPurple) : null,
            onTap: () {
              ref.read(themeProvider.notifier).setThemeMode('dark');
            },
          ),
          
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('About', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Narrately'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}
