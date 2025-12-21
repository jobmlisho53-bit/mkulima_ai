/*
 * Dependency Injection Configuration for Mkulima AI
 */

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import '../data/datasources/local/local_data_source.dart';
import '../data/datasources/remote/remote_data_source.dart';
import '../data/datasources/remote/api_service.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/disease_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/disease_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/register_usecase.dart';
import '../../domain/usecases/disease/detect_disease_usecase.dart';
import '../../domain/usecases/disease/get_history_usecase.dart';
import '../../domain/usecases/user/get_user_profile_usecase.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Dio for HTTP requests
  sl.registerSingleton<Dio>(
    Dio(
      BaseOptions(
        baseUrl: 'http://your-api-url.com/api',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    )..interceptors.add(
        LogInterceptor(
          request: true,
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
        ),
      ),
  );
  
  // Data sources
  sl.registerSingleton<LocalDataSource>(
    LocalDataSourceImpl(sharedPreferences: sl()),
  );
  
  sl.registerSingleton<RemoteDataSource>(
    RemoteDataSourceImpl(apiService: sl()),
  );
  
  sl.registerSingleton<ApiService>(
    ApiService(sl()),
  );
  
  // Repositories
  sl.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  
  sl.registerSingleton<DiseaseRepository>(
    DiseaseRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  
  sl.registerSingleton<UserRepository>(
    UserRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );
  
  // Use cases
  sl.registerSingleton<LoginUseCase>(
    LoginUseCase(sl()),
  );
  
  sl.registerSingleton<RegisterUseCase>(
    RegisterUseCase(sl()),
  );
  
  sl.registerSingleton<DetectDiseaseUseCase>(
    DetectDiseaseUseCase(sl()),
  );
  
  sl.registerSingleton<GetHistoryUseCase>(
    GetHistoryUseCase(sl()),
  );
  
  sl.registerSingleton<GetUserProfileUseCase>(
    GetUserProfileUseCase(sl()),
  );
  
  // Initialize other dependencies
  await _initializeMLModel();
  await _initializeVoiceService();
  await _initializeLocationService();
}

Future<void> _initializeMLModel() async {
  // Initialize TensorFlow Lite model
  // This will be implemented later
}

Future<void> _initializeVoiceService() async {
  // Initialize text-to-speech service
  // This will be implemented later
}

Future<void> _initializeLocationService() async {
  // Initialize location service
  // This will be implemented later
}
