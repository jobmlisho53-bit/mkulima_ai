/*
 * Dependency Injection Configuration for Mkulima AI
 * Complete with ML Service Integration
 */

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';

// Data Sources
import '../../data/datasources/local/local_data_source.dart';
import '../../data/datasources/local/hive_local_data_source.dart';
import '../../data/datasources/remote/remote_data_source.dart';
import '../../data/datasources/remote/api_service.dart';

// Repositories
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/scan_repository_impl.dart';
import '../../data/repositories/disease_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';

// Domain Repositories
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/scan_repository.dart';
import '../../domain/repositories/disease_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/history_repository.dart';

// Use Cases
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/register_usecase.dart';
import '../../domain/usecases/scan/analyze_image_usecase.dart';
import '../../domain/usecases/scan/initialize_model_usecase.dart';
import '../../domain/usecases/disease/get_disease_info_usecase.dart';
import '../../domain/usecases/disease/get_recommendations_usecase.dart';
import '../../domain/usecases/history/get_scan_history_usecase.dart';
import '../../domain/usecases/history/save_scan_result_usecase.dart';
import '../../domain/usecases/user/get_user_profile_usecase.dart';
import '../../domain/usecases/user/update_user_settings_usecase.dart';

// Services
import '../../services/classifier_service.dart';
import '../../services/tts_service.dart';
import '../../services/location_service.dart';
import '../../services/connectivity_service.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies() async {
  await _initializeExternalDependencies();
  await _initializeDataSources();
  await _initializeRepositories();
  await _initializeUseCases();
  await _initializeServices();
}

// Step 1: Initialize External Dependencies
Future<void> _initializeExternalDependencies() async {
  // Shared Preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  
  // Dio HTTP Client
  sl.registerSingleton<Dio>(
    Dio(
      BaseOptions(
        baseUrl: 'https://api.mkulima-ai.com/v1',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mkulima-AI/1.0.0',
        },
      ),
    )..interceptors.addAll([
        LogInterceptor(
          request: true,
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
        ),
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // Add auth token if available
            final token = sl<SharedPreferences>().getString('auth_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          },
          onError: (error, handler) async {
            // Handle 401 errors by refreshing token
            if (error.response?.statusCode == 401) {
              // TODO: Implement token refresh logic
            }
            return handler.next(error);
          },
        ),
      ]),
  );
  
  // Initialize Camera
  try {
    final cameras = await availableCameras();
    sl.registerSingleton<List<CameraDescription>>(cameras);
    print('📸 Cameras initialized: ${cameras.length} found');
  } catch (e) {
    print('⚠️ Camera initialization failed: $e');
    sl.registerSingleton<List<CameraDescription>>([]);
  }
}

// Step 2: Initialize Data Sources
Future<void> _initializeDataSources() async {
  // API Service
  sl.registerSingleton<ApiService>(
    ApiService(sl<Dio>()),
  );
  
  // Remote Data Source
  sl.registerSingleton<RemoteDataSource>(
    RemoteDataSourceImpl(
      apiService: sl<ApiService>(),
      dio: sl<Dio>(),
    ),
  );
  
  // Local Data Source (SharedPreferences based)
  sl.registerSingleton<LocalDataSource>(
    LocalDataSourceImpl(
      sharedPreferences: sl<SharedPreferences>(),
    ),
  );
  
  // Hive Local Data Source (For complex objects like scan history)
  final hiveDataSource = HiveLocalDataSource();
  await hiveDataSource.initialize();
  sl.registerSingleton<HiveLocalDataSource>(hiveDataSource);
}

// Step 3: Initialize Repositories
Future<void> _initializeRepositories() async {
  // Auth Repository
  sl.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      remoteDataSource: sl<RemoteDataSource>(),
      localDataSource: sl<LocalDataSource>(),
    ),
  );
  
  // Scan Repository (CRITICAL - Connects UI to ML Service)
  sl.registerSingleton<ScanRepository>(
    ScanRepositoryImpl(
      remoteDataSource: sl<RemoteDataSource>(),
      localDataSource: sl<HiveLocalDataSource>(),
    ),
  );
  
  // Disease Repository
  sl.registerSingleton<DiseaseRepository>(
    DiseaseRepositoryImpl(
      remoteDataSource: sl<RemoteDataSource>(),
      localDataSource: sl<LocalDataSource>(),
    ),
  );
  
  // User Repository
  sl.registerSingleton<UserRepository>(
    UserRepositoryImpl(
      remoteDataSource: sl<RemoteDataSource>(),
      localDataSource: sl<LocalDataSource>(),
    ),
  );
  
  // History Repository
  sl.registerSingleton<HistoryRepository>(
    HistoryRepositoryImpl(
      localDataSource: sl<HiveLocalDataSource>(),
    ),
  );
}

// Step 4: Initialize Use Cases
Future<void> _initializeUseCases() async {
  // Auth Use Cases
  sl.registerSingleton<LoginUseCase>(
    LoginUseCase(sl<AuthRepository>()),
  );
  
  sl.registerSingleton<RegisterUseCase>(
    RegisterUseCase(sl<AuthRepository>()),
  );
  
  // Scan Use Cases (CRITICAL - For ML Operations)
  sl.registerSingleton<InitializeModelUseCase>(
    InitializeModelUseCase(sl<ScanRepository>()),
  );
  
  sl.registerSingleton<AnalyzeImageUseCase>(
    AnalyzeImageUseCase(sl<ScanRepository>()),
  );
  
  // Disease Use Cases
  sl.registerSingleton<GetDiseaseInfoUseCase>(
    GetDiseaseInfoUseCase(sl<DiseaseRepository>()),
  );
  
  sl.registerSingleton<GetRecommendationsUseCase>(
    GetRecommendationsUseCase(sl<DiseaseRepository>()),
  );
  
  // History Use Cases
  sl.registerSingleton<GetScanHistoryUseCase>(
    GetScanHistoryUseCase(sl<HistoryRepository>()),
  );
  
  sl.registerSingleton<SaveScanResultUseCase>(
    SaveScanResultUseCase(sl<HistoryRepository>()),
  );
  
  // User Use Cases
  sl.registerSingleton<GetUserProfileUseCase>(
    GetUserProfileUseCase(sl<UserRepository>()),
  );
  
  sl.registerSingleton<UpdateUserSettingsUseCase>(
    UpdateUserSettingsUseCase(sl<UserRepository>()),
  );
}

// Step 5: Initialize Services
Future<void> _initializeServices() async {
  // ML Service (TensorFlow Lite)
  final classifierService = ClassifierService();
  await classifierService.initialize(); // Load model and labels
  sl.registerSingleton<ClassifierService>(classifierService);
  
  // Text-to-Speech Service (Swahili)
  final ttsService = TtsService();
  await ttsService.initialize();
  sl.registerSingleton<TtsService>(ttsService);
  
  // Location Service
  final locationService = LocationService();
  await locationService.initialize();
  sl.registerSingleton<LocationService>(locationService);
  
  // Connectivity Service
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  sl.registerSingleton<ConnectivityService>(connectivityService);
  
  print('✅ All services initialized successfully');
}

// Helper function to get the ML service
ClassifierService get mlService => sl<ClassifierService>();

// Helper function to get the scan repository
ScanRepository get scanRepository => sl<ScanRepository>();

// Helper function to get the camera
List<CameraDescription> get cameras => sl<List<CameraDescription>>();

// Helper function to check if ML model is ready
bool get isMLModelReady {
  try {
    return sl<ClassifierService>().isModelLoaded;
  } catch (e) {
    return false;
  }
}

// Clean up all dependencies
Future<void> cleanupDependencies() async {
  await sl.reset();
}
