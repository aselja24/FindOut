class AppConstants {
  AppConstants._();
  static const String appName = 'FindOut';
  static const String appSlogan = 'Учи язык и узнавай страну';
  static const String supabaseUrl = 'https://qptiiuolrsxofcvzarqb.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_9ZEwaPFPFxGWtEN9JgdP1w_lyTdMEO5';

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'de', 'name': 'Немецкий', 'flag': '🇩🇪'},
    {'code': 'en', 'name': 'Английский', 'flag': '🇬🇧'},
    {'code': 'ko', 'name': 'Корейский', 'flag': '🇰🇷'},
  ];

  static const List<String> learningGoals = [
    'Путешествия', 'Учёба', 'Работа',
    'Общение', 'Саморазвитие', 'Культура',
  ];

  static const List<Map<String, String>> levels = [
    {'code': 'A1', 'name': 'Начинающий'},
    {'code': 'A2', 'name': 'Базовый'},
    {'code': 'B1', 'name': 'Средний'},
    {'code': 'C1', 'name': 'Продвинутый'},
  ];

  static const List<String> dailyTimes = [
    '5 мин/день', '15 мин/день', '30 мин/день', '60 мин/день',
  ];

  // Storage buckets
  static const String bucketAvatars = 'avatars';
  static const String bucketAppContent = 'app-content';
  static const String bucketUserCards = 'user-cards';
}
