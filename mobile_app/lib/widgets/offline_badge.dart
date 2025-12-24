// lib/widgets/offline_badge.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBadge extends StatefulWidget {
  const OfflineBadge({super.key});
  
  @override
  State<OfflineBadge> createState() => _OfflineBadgeState();
}

class _OfflineBadgeState extends State<OfflineBadge> {
  bool _isOnline = true;
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }
  
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
