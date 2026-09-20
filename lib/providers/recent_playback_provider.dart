import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';

final recentPlaybackProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getMostRecentPlayback();
});
