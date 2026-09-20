import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/theme_provider.dart';
import '../providers/stats_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'APPEARANCE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ThemeTile(
                          title: 'System Default',
                          icon: Icons.brightness_auto_rounded,
                          isSelected: themeMode == ThemeMode.system,
                          onTap: () => ref.read(themeProvider.notifier).setThemeMode('system'),
                        ),
                        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        _ThemeTile(
                          title: 'Light',
                          icon: Icons.light_mode_rounded,
                          isSelected: themeMode == ThemeMode.light,
                          onTap: () => ref.read(themeProvider.notifier).setThemeMode('light'),
                        ),
                        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        _ThemeTile(
                          title: 'Dark',
                          icon: Icons.dark_mode_rounded,
                          isSelected: themeMode == ThemeMode.dark,
                          onTap: () => ref.read(themeProvider.notifier).setThemeMode('dark'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'READING',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Font Size', style: Theme.of(context).textTheme.titleMedium),
                              Consumer(
                                builder: (context, ref, child) {
                                  final fontSize = ref.watch(statsProvider).stats?.preferredFontSize ?? 18.0;
                                  return Text('${fontSize.toInt()} pt', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold));
                                }
                              ),
                            ],
                          ),
                          const _FontSizeSlider(),
                          Text(
                            'Applies to the text shown while listening.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'DAILY GOAL',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: _DailyGoalPicker(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'ABOUT',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: const ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('Narrately'),
                      subtitle: _VersionText(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.primary : null),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
      onTap: onTap,
    );
  }
}

class _FontSizeSlider extends ConsumerStatefulWidget {
  const _FontSizeSlider();

  @override
  ConsumerState<_FontSizeSlider> createState() => _FontSizeSliderState();
}

class _FontSizeSliderState extends ConsumerState<_FontSizeSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(statsProvider).stats?.preferredFontSize ?? 18.0;
    final value = (_dragValue ?? saved).clamp(12.0, 32.0);

    return Slider(
      value: value,
      min: 12.0,
      max: 32.0,
      divisions: 10,
      label: '${value.toInt()} pt',
      onChanged: (v) => setState(() => _dragValue = v),
      onChangeEnd: (v) {
        // Persist once the drag settles; writing on every frame hammered sqflite.
        ref.read(statsProvider.notifier).setFontSize(v);
        setState(() => _dragValue = null);
      },
    );
  }
}

class _DailyGoalPicker extends ConsumerWidget {
  const _DailyGoalPicker();

  static const List<int> _options = [5, 10, 15, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalSeconds = ref.watch(statsProvider).stats?.dailyGoalSeconds ?? 900;
    final goalMinutes = goalSeconds ~/ 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Listen each day', style: Theme.of(context).textTheme.titleMedium),
            Text(
              '$goalMinutes min',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _options.map((minutes) {
            return ChoiceChip(
              label: Text('$minutes min'),
              selected: goalMinutes == minutes,
              onSelected: (_) =>
                  ref.read(statsProvider.notifier).setDailyGoal(minutes * 60),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _VersionText extends StatefulWidget {
  const _VersionText();

  @override
  State<_VersionText> createState() => _VersionTextState();
}

class _VersionTextState extends State<_VersionText> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'Version ${info.version} (${info.buildNumber})');
    } catch (e) {
      if (!mounted) return;
      setState(() => _version = 'Version unavailable');
    }
  }

  @override
  Widget build(BuildContext context) => Text(_version);
}
