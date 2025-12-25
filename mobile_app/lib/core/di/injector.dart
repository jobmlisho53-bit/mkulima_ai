import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

// Services
import '../../services/classifier_service.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Dio HTTP Client
  sl.registerSingleton<Dio>(
    Dio(
      BaseOptions(
        baseUrl: 'https://api.mkulima-ai.com/api/v1',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
  );
  
  // ML Service
  final mlService = classifierService;
  await mlService.initialize();
  sl.registerSingleton<ClassifierService>(mlService);
  
  print('✅ Dependencies initialized');
}

// Helper getters
ClassifierService get mlService => sl<ClassifierService>();
SharedPreferences get prefs => sl<SharedPreferences>();
Dio get dio => sl<Dio>();
