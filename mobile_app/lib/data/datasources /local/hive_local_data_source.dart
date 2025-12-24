import 'package:hive/hive.dart';
import 'package:mkulima_ai/domain/entities/scan_result.dart';

class HiveLocalDataSource {
  static const String _scanBox = 'scan_results';
  static const String _modelStatusKey = 'model_status';
  
  late Box<ScanResult> _scanBoxInstance;
  
  Future<void> initialize() async {
    // Register adapters
    Hive.registerAdapter(ScanResultAdapter());
    
    // Open boxes
    _scanBoxInstance = await Hive.openBox<ScanResult>(_scanBox);
  }
  
  Future<void> saveScanResult(ScanResult result) async {
    await _scanBoxInstance.put(result.id, result);
  }
  
  Future<List<ScanResult>> getScanHistory() async {
    return _scanBoxInstance.values.toList();
  }
  
  Future<ScanResult?> getScanResult(String id) async {
    return _scanBoxInstance.get(id);
  }
  
  Future<void> updateScanResultSyncStatus(String id, bool isSynced) async {
    final result = await getScanResult(id);
    if (result != null) {
      final updated = ScanResult(
        id: result.id,
        imagePath: result.imagePath,
        diseaseName: result.diseaseName,
        confidence: result.confidence,
        severity: result.severity,
        treatment: result.treatment,
        timestamp: result.timestamp,
        location: result.location,
        additionalNotes: result.additionalNotes,
        isSynced: isSynced,
      );
      await saveScanResult(updated);
    }
  }
  
  Future<void> deleteScanResult(String id) async {
    await _scanBoxInstance.delete(id);
  }
  
  Future<void> saveModelStatus(bool isLoaded) async {
    await _scanBoxInstance.put(_modelStatusKey, isLoaded);
  }
  
  Future<bool?> getModelStatus() async {
    return _scanBoxInstance.get(_modelStatusKey) as bool?;
  }
  
  Future<void> saveErrorLog(String method, String error) async {
    final log = {
      'method': method,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _scanBoxInstance.put('error_${DateTime.now().millisecondsSinceEpoch}', log);
  }
  
  Future<void> clearAllData() async {
    await _scanBoxInstance.clear();
  }
}

// Hive Adapter for ScanResult
class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;
  
  @override
  ScanResult read(BinaryReader reader) {
    return ScanResult.fromJson(Map<String, dynamic>.from(reader.read()));
  }
  
  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer.write(obj.toJson());
  }
} 
