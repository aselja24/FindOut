import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/auth/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/setup/setup_language_screen.dart';
import '../../presentation/screens/auth/setup/setup_goal_screen.dart';
import '../../presentation/screens/auth/setup/setup_level_screen.dart';
import '../../presentation/screens/auth/setup/setup_time_screen.dart';
import '../../presentation/screens/auth/setup/level_test_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../constants/route_constants.dart';

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final publicRoutes = [
        Routes.splash, Routes.onboarding, Routes.login, Routes.register,
        Routes.setupLanguage, Routes.setupGoal, Routes.setupLevel,
        Routes.setupTime, Routes.levelTest,
      ];
      if (!isAuth && !publicRoutes.contains(state.matchedLocation)) {
        return Routes.onboarding;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash,
          builder: (c, s) => const SplashScreen()),
      GoRoute(path: Routes.onboarding,
          builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: Routes.login,
          builder: (c, s) => const LoginScreen()),
      GoRoute(path: Routes.register,
          builder: (c, s) => const RegisterScreen()),
      GoRoute(path: Routes.setupLanguage,
          builder: (c, s) => const SetupLanguageScreen()),
      GoRoute(path: Routes.setupGoal,
          builder: (c, s) => const SetupGoalScreen()),
      GoRoute(path: Routes.setupLevel,
          builder: (c, s) => const SetupLevelScreen()),
      GoRoute(path: Routes.setupTime,
          builder: (c, s) => const SetupTimeScreen()),
      GoRoute(path: Routes.levelTest,
          builder: (c, s) => const LevelTestScreen()),
      GoRoute(path: Routes.home,
          builder: (c, s) => const HomeScreen()),
    ],
    errorBuilder: (c, s) => Scaffold(
      body: Center(child: Text('Страница не найдена: ${s.uri}')),
    ),
  );
}
