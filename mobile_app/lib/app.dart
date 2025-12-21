/*
 * Mkulima AI - App Configuration
 */

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/providers/app_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/connectivity_provider.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/disease/presentation/pages/detect_page.dart';
import 'features/disease/presentation/pages/history_page.dart';
import 'features/disease/presentation/pages/treatment_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      // Onboarding
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      
      // Authentication
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      
      // Main App
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'detect',
            name: 'detect',
            builder: (context, state) => const DetectPage(),
          ),
          GoRoute(
            path: 'history',
            name: 'history',
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: 'treatment/:diseaseId',
            name: 'treatment',
            builder: (context, state) => TreatmentPage(
              diseaseId: state.pathParameters['diseaseId']!,
            ),
          ),
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      // Add authentication logic here
      final isLoggedIn = false; // Replace with actual auth check
      final isOnboardingComplete = true; // Replace with actual check
      
      if (!isOnboardingComplete && state.location != '/onboarding') {
        return '/onboarding';
      }
      
      if (!isLoggedIn && 
          !['/onboarding', '/login', '/register', '/forgot-password']
            .contains(state.location)) {
        return '/login';
      }
      
      if (isLoggedIn && 
          ['/onboarding', '/login', '/register', '/forgot-password']
            .contains(state.location)) {
        return '/';
      }
      
      return null;
    },
  );
}

class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: child,
    );
  }
}
