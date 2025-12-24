// Repository interface for scan feature
import 'package:mkulima_ai/features/scan/domain/entities/scan_result.dart';

abstract class ScanRepository {
  Future<void> initializeModel();
  Future<ScanResult> analyzeImage(String imagePath);
}

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  // This will be implemented by you (ML developer)
  throw UnimplementedError('ScanRepository must be implemented');
});
