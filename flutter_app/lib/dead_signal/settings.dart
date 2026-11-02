import 'package:shared_preferences/shared_preferences.dart';

class SignalSettings {
  double sensitivity = 1, music = .22, effects = .65;
  bool muted = false;
  int cameraIndex = 0;
  String backend = 'dshow';
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sensitivity = (p.getDouble('signal.sensitivity') ?? 1).clamp(.5, 2);
    music = (p.getDouble('signal.music') ?? .22).clamp(0, 1);
    effects = (p.getDouble('signal.effects') ?? .65).clamp(0, 1);
    muted = p.getBool('signal.muted') ?? false;
    cameraIndex = (p.getInt('signal.camera') ?? 0).clamp(0, 3);
    backend = p.getString('signal.backend') ?? 'dshow';
    if (!['dshow', 'msmf', 'auto'].contains(backend)) backend = 'dshow';
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('signal.sensitivity', sensitivity);
    await p.setDouble('signal.music', music);
    await p.setDouble('signal.effects', effects);
    await p.setBool('signal.muted', muted);
    await p.setInt('signal.camera', cameraIndex);
    await p.setString('signal.backend', backend);
  }

  void reset() {
    sensitivity = 1;
    music = .22;
    effects = .65;
    muted = false;
  }
}
