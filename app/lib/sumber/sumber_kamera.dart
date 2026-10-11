// Android: kamera + ML Kit. Web: webcam + MediaPipe Pose Landmarker.
// Platform lain memakai stub (hanya mode demo).
export 'kamera_stub.dart'
    if (dart.library.io) 'kamera_io.dart'
    if (dart.library.js_interop) 'kamera_web.dart';
