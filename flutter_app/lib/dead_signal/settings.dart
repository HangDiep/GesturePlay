import 'package:shared_preferences/shared_preferences.dart';

class SignalSettings {
  SignalSettings({this.storageKey = 'signal'});
  final String storageKey;
  double sensitivity = 1, music = .22, effects = .65;
  double movementSensitivity = 1;
  bool muted = false;
  bool swapHands = false;
  bool reducedEffects = false;
  String townDifficulty = 'normal', controlMode = 'keyboard';
  int cameraIndex = 0;
  String backend = 'dshow';
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sensitivity = (p.getDouble('$storageKey.sensitivity') ?? 1).clamp(.5, 2);
    movementSensitivity = (p.getDouble('$storageKey.movementSensitivity') ?? 1)
        .clamp(.5, 2);
    music = (p.getDouble('$storageKey.music') ?? .22).clamp(0, 1);
    effects = (p.getDouble('$storageKey.effects') ?? .65).clamp(0, 1);
    muted = p.getBool('$storageKey.muted') ?? false;
    swapHands = p.getBool('$storageKey.swapHands') ?? false;
    reducedEffects = p.getBool('$storageKey.reducedEffects') ?? false;
    townDifficulty = p.getString('$storageKey.difficulty') == 'easy'
        ? 'easy'
        : 'normal';
    controlMode = p.getString('$storageKey.controlMode') ?? 'keyboard';
    if (!['keyboard', 'oneHand', 'twoHands'].contains(controlMode)) {
      controlMode = 'keyboard';
    }
    cameraIndex = (p.getInt('$storageKey.camera') ?? 0).clamp(0, 20);
    backend = p.getString('$storageKey.backend') ?? 'dshow';
    if (!['dshow', 'msmf', 'auto'].contains(backend)) backend = 'dshow';
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('$storageKey.sensitivity', sensitivity);
    await p.setDouble('$storageKey.movementSensitivity', movementSensitivity);
    await p.setDouble('$storageKey.music', music);
    await p.setDouble('$storageKey.effects', effects);
    await p.setBool('$storageKey.muted', muted);
    await p.setBool('$storageKey.swapHands', swapHands);
    await p.setBool('$storageKey.reducedEffects', reducedEffects);
    await p.setString('$storageKey.difficulty', townDifficulty);
    await p.setString('$storageKey.controlMode', controlMode);
    await p.setInt('$storageKey.camera', cameraIndex);
    await p.setString('$storageKey.backend', backend);
  }

  void reset() {
    sensitivity = 1;
    music = .22;
    effects = .65;
    muted = false;
    swapHands = false;
    movementSensitivity = 1;
    reducedEffects = false;
    townDifficulty = 'normal';
    controlMode = 'keyboard';
  }
}
