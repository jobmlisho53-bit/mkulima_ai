import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mkulima_ai/core/di/injector.dart'; // ADD THIS IMPORT
import 'package:mkulima_ai/features/scan/domain/entities/scan_result.dart';
import 'package:mkulima_ai/features/scan/domain/repositories/scan_repository.dart';

class ScanState {
  final bool isLoading;
  final bool isModelLoaded;
  final ScanResult? result;
  final String? error;

  ScanState({
    this.isLoading = false,
    this.isModelLoaded = false,
    this.result,
    this.error,
  });

  ScanState copyWith({
    bool? isLoading,
    bool? isModelLoaded,
    ScanResult? result,
    String? error,
  }) {
    return ScanState(
      isLoading: isLoading ?? this.isLoading,
      isModelLoaded: isModelLoaded ?? this.isModelLoaded,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  late final ScanRepository _repository;
  
  ScanNotifier() : super(ScanState()) {
    // Get repository from dependency injection
    _repository = getIt<ScanRepository>();
  }

  bool get isModelLoaded => state.isModelLoaded;

  Future<void> initializeModel() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.initializeModel();
      state = state.copyWith(isModelLoaded: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load AI model: $e',
        isLoading: false,
      );
    }
  }

  Future<void> analyzeImage(String imagePath) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await _repository.analyzeImage(imagePath);
      state = state.copyWith(result: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Analysis failed: $e',
        isLoading: false,
      );
    }
  }

  Future<void> pickAndAnalyzeImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        await analyzeImage(pickedFile.path);
      }
    } catch (e) {
      state = state.copyWith(error: 'Gallery error: $e');
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void clearResult() {
    state = state.copyWith(result: null, error: null);
  }
}

// Provider
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier();
});
