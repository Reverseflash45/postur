// Kamera + ML Kit hanya ada di Android; di web tersedia stub supaya
// aplikasi tetap bisa dibuka (mode demo) untuk pratinjau tampilan.
export 'kamera_stub.dart' if (dart.library.io) 'kamera_io.dart';
