// Scan button widget
import 'package:flutter/material.dart';
import 'package:mkulima_ai/core/theme/theme.dart';

class ScanButton extends StatelessWidget {
  final bool isLoading;
  final bool isModelReady;
  final VoidCallback onTap;

  const ScanButton({
    super.key,
    required this.isLoading,
    required this.isModelReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    
    return GestureDetector(
      onTap: isLoading || !isModelReady ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isModelReady ? Colors.green : Colors.grey,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isModelReady ? Colors.green : Colors.grey).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring animation
            if (isModelReady && !isLoading)
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 3,
                  ),
                ),
              ),
            
            // Inner circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.green,
                      ),
                    )
                  : Icon(
                      Icons.camera_alt,
                      color: isModelReady ? Colors.green : Colors.grey,
                      size: 32,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
