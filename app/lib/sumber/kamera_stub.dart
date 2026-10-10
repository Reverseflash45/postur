import '../inti/pose.dart';
import 'sumber_pose.dart';

const bool kameraTersedia = false;

class SumberKamera extends SumberPose {
  SumberKamera({required bool depan});

  @override
  String get nama => 'tidak-tersedia';

  @override
  Stream<FramePose> get aliran => const Stream.empty();

  @override
  Future<void> mulai() async =>
      throw UnsupportedError('Kamera hanya tersedia di aplikasi Android');

  @override
  Future<void> berhenti() async {}

  @override
  Future<void> dispose() async {}
}
