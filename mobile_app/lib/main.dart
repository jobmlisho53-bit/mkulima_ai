/*
 * Mkulima AI - Main Application Entry Point
 * AI-Powered Plant Disease Detection Mobile App
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mkulima_ai/app.dart';
import 'package:mkulima_ai/core/di/injector.dart';
import 'package:mkulima_ai/core/theme/theme.dart';
import 'package:mkulima_ai/core/utils/logger.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize dependency injection
  await initializeDependencies();
  
  // Initialize logging
  Logger.initialize();
  
  // Initialize app theme
  final appTheme = AppTheme();
  
  // Run the app
  runApp(
    MkulimaAIApp(
      theme: appTheme,
    ),
  );
}

class MkulimaAIApp extends StatelessWidget {
  final AppTheme theme;

  const MkulimaAIApp({
    Key? key,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mkulima AI',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      localizationsDelegates: const [
        // Add localization delegates here
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('sw', 'KE'), // Swahili for Kenya
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}
