/// Rules for the single playable town. The previous map prototypes keep their
/// own rescue rules and are not part of the new home screen.
enum TownDifficulty { easy, normal }

extension TownDifficultyText on TownDifficulty {
  String get label => this == TownDifficulty.easy ? 'Dễ' : 'Thường';
  double get speedScale => this == TownDifficulty.easy ? .78 : 1;
  double get damageScale => this == TownDifficulty.easy ? .7 : 1;
}

abstract final class TownRules {
  static const duration = 180.0;
  static const maxAlive = 9;
  static const reserveCap = 180;
  static const criticalHealth = 30.0;
  static const hideDuration = 10.0;
  static const hideCooldown = 3.0;
  static const visionRange = 510.0;
  static const memorySeconds = 7.0;
  static const howlDistance = 380.0;
  static const howlCooldown = 9.0;
  static const stanceSpeeds = [190.0, 105.0, 55.0];
  static const stanceVisibility = [1.0, .7, .45];
  static const stanceNoise = [180.0, 75.0, 40.0];
  static const waveTimes = [3.0, 27.0, 60.0, 105.0, 150.0];
  static const waveKinds = [
    [0, 0, 2],
    [1, 0, 0, 2],
    [2, 0, 1, 0, 0],
    [3, 0, 0, 1, 2],
    [1, 2, 0, 0, 1, 0],
  ];
  static const windup = [.25, .65, .4, 1.4];
  static const magicWindup = [.95, 1.25]; // jammer, boss
  static const magicCooldown = [4.5, 6.5];
  static const magicDamage = [14.0, 20.0];
  static const magicSpeed = [285.0, 255.0];
  static const magicRange = [520.0, 620.0];
  static const maxEnemyBolts = 18;
  static const maxCastingEnemies = 2;
  static const title = 'Thị trấn bị phong tỏa';
}
