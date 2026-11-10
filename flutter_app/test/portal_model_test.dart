import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestureplay/dead_signal/settings.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/survival/practice.dart';
import 'package:gestureplay/survival/rules.dart';

void main() {
  test(
    'settings are isolated by player and preserve legacy device settings',
    () async {
      SharedPreferences.setMockInitialValues({'signal.sensitivity': 1.4});
      final a = SignalSettings(storageKey: 'player.a.signal')
        ..townDifficulty = 'easy'
        ..sensitivity = 1.8
        ..movementSensitivity = .7
        ..controlMode = 'twoHands'
        ..swapHands = true
        ..reducedEffects = true;
      await a.save();
      final b = SignalSettings(storageKey: 'player.b.signal');
      await b.load();
      expect(b.sensitivity, 1);
      expect(b.townDifficulty, 'normal');
      final restored = SignalSettings(storageKey: 'player.a.signal');
      await restored.load();
      expect(restored.movementSensitivity, .7);
      expect(restored.sensitivity, 1.8);
      expect(restored.controlMode, 'twoHands');
      expect(restored.swapHands, true);
      expect(restored.reducedEffects, true);
      final legacy = SignalSettings();
      await legacy.load();
      expect(legacy.sensitivity, 1.4);
    },
  );

  test(
    'easy reduces actual health damage and monster movement, normal stays unchanged',
    () {
      ExplorationModel create(TownDifficulty difficulty) =>
          ExplorationModel(
              FieldMap.town,
              survival: true,
              difficulty: difficulty,
            )
            ..start()
            ..wave = 5;
      final normal = create(TownDifficulty.normal);
      final easy = create(TownDifficulty.easy);
      normal.hurt(20, isHazard: true);
      easy.hurt(20, isHazard: true);
      expect(normal.health, 80);
      expect(easy.health, 86);
      final from = normal.player - const Offset(0, 180);
      final n = normal.spawn(CreatureKind.runner, at: from);
      final e = easy.spawn(CreatureKind.runner, at: from);
      for (var i = 0; i < 10; i++) {
        normal.update(.025);
        easy.update(.025);
      }
      expect(
        (n.position - from).distance,
        greaterThan((e.position - from).distance),
      );
    },
  );

  test(
    'practice is independent, safe and does not end at the rescue deadline',
    () {
      final practice = ExplorationModel(
        FieldMap.town,
        survival: true,
        practice: true,
      )..start();
      final run = ExplorationModel(FieldMap.town, survival: true)..start();
      practice.hurt(1000, isHazard: true);
      for (var i = 0; i < 1900; i++) {
        practice.update(.1);
      }
      expect(practice.health, 100);
      expect(practice.active, true);
      expect(practice.enemies, isEmpty);
      expect(practice.score, 0);
      expect(run.elapsed, 0);
      expect(run.owns(GunKind.shotgun), false);
    },
  );

  test(
    'all eleven lessons require real gameplay actions and complete in order',
    () {
      final m = ExplorationModel(FieldMap.town, survival: true, practice: true)
        ..start();
      final coach = PracticeCoach(m);
      void tick(double seconds) {
        for (var t = 0.0; t < seconds - 1e-8; t += .025) {
          m.update(.025);
          coach.update(m, .025);
        }
      }

      void next(PracticeLesson expected) {
        tick(1.3);
        expect(coach.lesson, expected);
        expect(m.score, 0);
      }

      tick(1);
      expect(coach.index, 0);
      m.movement = const Offset(0, -1);
      tick(.5);
      m.movement = Offset.zero;
      next(PracticeLesson.shoot);
      expect(m.enemies, hasLength(1));
      m.shoot(m.enemies.single.position);
      tick(.3);
      next(PracticeLesson.crouch);
      expect(m.setStance(PlayerStance.crouching), true);
      tick(.3);
      next(PracticeLesson.prone);
      expect(m.setStance(PlayerStance.prone), true);
      tick(.6);
      next(PracticeLesson.stand);
      expect(m.setStance(PlayerStance.standing), true);
      tick(.6);
      next(PracticeLesson.reload);
      tick(.3);
      expect(coach.lesson, PracticeLesson.reload);
      m.reload();
      tick(2);
      next(PracticeLesson.weapon);
      m.cycleWeapon();
      tick(.1);
      next(PracticeLesson.door);
      expect(m.interact(), true);
      tick(.1);
      next(PracticeLesson.hide);
      expect(m.toggleHide(), true);
      tick(.1);
      next(PracticeLesson.heal);
      expect(m.useMedkit(), true);
      tick(3);
      next(PracticeLesson.roll);
      expect(m.roll(), true);
      tick(.1);
      tick(1.3);
      expect(coach.completed, true);
      expect(m.phase, FieldPhase.won);
      expect(m.score, 0);
    },
  );
}
