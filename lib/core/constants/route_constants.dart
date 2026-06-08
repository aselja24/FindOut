class Routes {
  Routes._();
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';

  // Setup flow (after registration)
  static const String setupLanguage = '/setup/language';
  static const String setupGoal = '/setup/goal';
  static const String setupLevel = '/setup/level';
  static const String setupTime = '/setup/time';
  static const String levelTest = '/setup/test';

  // Main app
  static const String home = '/home';
  static const String flashcards = '/flashcards';
  static const String dictionary = '/dictionary';
  static const String grammar = '/grammar';
  static const String listening = '/listening';
  static const String reading = '/reading';
  static const String games = '/games';
  static const String stats = '/stats';
  static const String profile = '/profile';
}
