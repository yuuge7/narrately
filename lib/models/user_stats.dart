class UserStats {
  final int currentStreak;
  final int longestStreak;
  final String lastListenedDate; // ISO 8601 string (e.g., '2023-10-01')
  final int secondsListenedToday;
  final int dailyGoalSeconds;
  final bool goalReachedToday;
  
  // Settings
  final double preferredSpeed;
  final double preferredPitch;
  final String? preferredVoiceName;
  final String? preferredVoiceLocale;
  final String themeMode; // "system", "light", "dark"
  final double preferredFontSize;

  const UserStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.lastListenedDate,
    this.secondsListenedToday = 0,
    this.dailyGoalSeconds = 900, // 15 mins
    this.goalReachedToday = false,
    this.preferredSpeed = 1.0,
    this.preferredPitch = 1.0,
    this.preferredVoiceName,
    this.preferredVoiceLocale,
    this.themeMode = 'system',
    this.preferredFontSize = 18.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // Single row
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_listened_date': lastListenedDate,
      'seconds_listened_today': secondsListenedToday,
      'daily_goal_seconds': dailyGoalSeconds,
      'goal_reached_today': goalReachedToday ? 1 : 0,
      'preferred_speed': preferredSpeed,
      'preferred_pitch': preferredPitch,
      'preferred_voice_name': preferredVoiceName,
      'preferred_voice_locale': preferredVoiceLocale,
      'theme_mode': themeMode,
      'preferred_font_size': preferredFontSize,
    };
  }

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      currentStreak: map['current_streak'] as int,
      longestStreak: map['longest_streak'] as int,
      lastListenedDate: map['last_listened_date'] as String,
      secondsListenedToday: map['seconds_listened_today'] as int,
      dailyGoalSeconds: map['daily_goal_seconds'] as int,
      goalReachedToday: (map['goal_reached_today'] as int) == 1,
      preferredSpeed: (map['preferred_speed'] as num?)?.toDouble() ?? 1.0,
      preferredPitch: (map['preferred_pitch'] as num?)?.toDouble() ?? 1.0,
      preferredVoiceName: map['preferred_voice_name'] as String?,
      preferredVoiceLocale: map['preferred_voice_locale'] as String?,
      themeMode: map['theme_mode'] as String? ?? 'system',
      preferredFontSize: (map['preferred_font_size'] as num?)?.toDouble() ?? 18.0,
    );
  }

  UserStats copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastListenedDate,
    int? secondsListenedToday,
    int? dailyGoalSeconds,
    bool? goalReachedToday,
    double? preferredSpeed,
    double? preferredPitch,
    String? preferredVoiceName,
    String? preferredVoiceLocale,
    String? themeMode,
    double? preferredFontSize,
  }) {
    return UserStats(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastListenedDate: lastListenedDate ?? this.lastListenedDate,
      secondsListenedToday: secondsListenedToday ?? this.secondsListenedToday,
      dailyGoalSeconds: dailyGoalSeconds ?? this.dailyGoalSeconds,
      goalReachedToday: goalReachedToday ?? this.goalReachedToday,
      preferredSpeed: preferredSpeed ?? this.preferredSpeed,
      preferredPitch: preferredPitch ?? this.preferredPitch,
      preferredVoiceName: preferredVoiceName ?? this.preferredVoiceName,
      preferredVoiceLocale: preferredVoiceLocale ?? this.preferredVoiceLocale,
      themeMode: themeMode ?? this.themeMode,
      preferredFontSize: preferredFontSize ?? this.preferredFontSize,
    );
  }
}
