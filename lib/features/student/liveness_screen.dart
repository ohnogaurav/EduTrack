import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  List<CameraDescription> _cameras = [];
  bool _isLoading = true;
  int _retryCount = 0;
  Key _detectionKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    _cameras = await availableCameras();
    setState(() {
      _isLoading = false;
    });
  }

  void _handleFailure() {
    if (_retryCount < 2) {
      _showRetryDialog();
    } else {
      _showBypassDialog();
    }
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Detection Failed"),
        content: const Text("Having trouble detecting your actions. Try again in better lighting or adjust your face."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              print("DEBUG: Liveness returning FALSE");
              Navigator.pop(context, false); // Return failure to dashboard
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _retryCount++;
                _detectionKey = UniqueKey(); // Restart detector
              });
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _showBypassDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Still having issues?"),
        content: const Text("Detection failed multiple times. You can try again or proceed if you are in a difficult environment."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _detectionKey = UniqueKey();
              });
            },
            child: const Text("Try Again"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              print("DEBUG: Liveness returning FALSE (Bypass not allowed in Module 8)");
              Navigator.pop(context, false);
            },
            child: const Text("Proceed Anyway"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Liveness Verification')),
      body: LivenessDetectionScreen(
        key: _detectionKey,
        cameras: _cameras,
        config: LivenessConfig(
          numberOfRandomChallenges: 2,
          alwaysIncludeBlink: true,
        ),
        onLivenessCompleted: (String sessionId, bool isSuccessful, Map<String, dynamic>? metadata) {
          print("DEBUG: Liveness Completed - isSuccessful: $isSuccessful");
          if (isSuccessful) {
            print("DEBUG: Liveness returning TRUE");
            Navigator.pop(context, true);
          } else {
            _handleFailure();
          }
        },
      ),
    );
  }
}
