import 'dart:math' as math;
import 'package:flutter/painting.dart';
import '../exploration/model.dart';
import '../exploration/world.dart';

enum PracticeLesson {
  move,
  shoot,
  crouch,
  prone,
  stand,
  reload,
  weapon,
  door,
  hide,
  heal,
  roll,
}

class PracticeCoach {
  PracticeCoach(ExplorationModel model) {
    _prepare(model);
  }
  int index = 0;
  bool completed = false;
  double _delay = 0;
  int _hits = 0, _doorVersion = 0;
  GunKind _weapon = GunKind.rifle;
  bool _reloadSeen = false;
  PracticeLesson get lesson =>
      PracticeLesson.values[index.clamp(0, PracticeLesson.values.length - 1)];
  String get title => const [
    'Di chuyển',
    'Ngắm và bắn',
    'Ngồi xổm',
    'Nằm sấp',
    'Đứng dậy',
    'Nạp đạn',
    'Đổi súng',
    'Tương tác cửa',
    'Ẩn nấp',
    'Băng bó',
    'Lướt né',
  ][lesson.index];
  String get hint => const [
    'Mở và dịch tay đi, hoặc dùng WASD/cần trái. Đi đến vòng sáng.',
    'Dịch tay ngắm, chụm giữ để bắn trúng bia quái mô phỏng. Chuột/F hoặc cần phải cũng dùng được.',
    'Nắm ngắn tay đi rồi mở để ngồi; hoặc chọn Ngồi trong bảng. Phím X/nút Ngồi.',
    'Nắm ngắn tay đi lần nữa để nằm; hoặc chọn Nằm trong bảng. Phím Z/nút Nằm.',
    'Đổi tư thế về Đứng bằng tay hoặc nút Đứng.',
    'Nắm ngắn tay ngắm rồi mở; hoặc R/nút nạp. Chờ nạp xong.',
    'Nắm tay ngắm ≥0,8s rồi mở, hoặc V/ô súng. Cả ba súng đã có để thử.',
    'Đứng gần cửa, chụm ngắn tay đi rồi thả; hoặc E/nút Tương tác.',
    'Chụm ngắn tay đi rồi thả tại vòng xanh; hoặc G/nút Ẩn.',
    'Chụm tay đi ≥0,8s rồi thả; hoặc H. Giữ yên 2,8s để hồi máu.',
    'Hất nhanh tay đi đang mở lên; hoặc Space/nút né. Từ nằm phải đứng dậy trước.',
  ][lesson.index];
  String get caption => _delay > 0
      ? 'Đúng rồi! Chuẩn bị bài tiếp theo…'
      : 'Bài ${index + 1}/${PracticeLesson.values.length} · $title\n$hint';

  String captionFor({required bool singleHand}) {
    if (!singleHand || _delay > 0) return caption;
    final action = switch (lesson) {
      PracticeLesson.crouch => 'Ngồi',
      PracticeLesson.prone => 'Nằm',
      PracticeLesson.stand => 'Đứng',
      PracticeLesson.weapon => 'Đổi súng',
      PracticeLesson.door => 'Tương tác',
      PracticeLesson.hide => 'Ẩn nấp',
      PracticeLesson.heal => 'Băng bó',
      _ => null,
    };
    if (action == null) return caption;
    return 'Bài ${index + 1}/11 · $title\nMột tay: nắm 0,8s mở bảng, dịch tay đến $action rồi chụm/thả để chọn. Mở tay để chơi tiếp.';
  }

  void _prepare(ExplorationModel m) {
    m.enemies.clear();
    m.enemyBolts.clear();
    m.bossRifts.clear();
    m.bullets.clear();
    m.cancelHealing();
    m.leaveHiding();
    m.hideCooldown = 0;
    m.rollFor = m.rollCooldown = 0;
    m.practiceTarget = null;
    _hits = m.hits;
    _weapon = m.weapon;
    _reloadSeen = false;
    switch (lesson) {
      case PracticeLesson.move:
        m.practiceTarget = m.player - const Offset(0, 130);
      case PracticeLesson.shoot:
        m.player = FieldWorld.spawn;
        for (var i = 0; i < 16; i++) {
          final angle = -math.pi / 2 + i * math.pi / 8;
          final target =
              m.player + Offset(math.cos(angle), math.sin(angle)) * 180;
          if (m.world.walkable(target, 25) &&
              m.world.clearLine(m.player, target, 25)) {
            m.spawn(CreatureKind.runner, at: target).stun = 100000;
            m.practiceTarget = target;
            break;
          }
        }
        m.ammo = m.gun.magazine;
        m.reserve = m.gun.reserveCap;
      case PracticeLesson.crouch:
        m.stance = PlayerStance.standing;
        m.stanceFor = 0;
      case PracticeLesson.prone:
        m.stance = PlayerStance.crouching;
        m.stanceFor = 0;
      case PracticeLesson.stand:
        m.stance = PlayerStance.prone;
        m.stanceFor = 0;
      case PracticeLesson.reload:
        m.ammo = 1;
        m.reserve = m.gun.reserveCap;
        m.reloadFor = 0;
      case PracticeLesson.weapon:
        m.pickupPracticeGuns();
      case PracticeLesson.door:
        final door = m.world.doors.first;
        m.world.setDoorOpen(door, true);
        door.health = 120;
        m.player = door.outside;
        m.practiceTarget = door.rect.center;
        _doorVersion = m.world.navigationVersion;
      case PracticeLesson.hide:
        m.player = m.world.hidingSpots.first.center;
        m.practiceTarget = m.player;
      case PracticeLesson.heal:
        m.health = 40;
        m.medkits = 3;
      case PracticeLesson.roll:
        m.stance = PlayerStance.standing;
        m.stanceFor = 0;
    }
  }

  /// Returns true when the lesson changes or succeeds, so inputs can recenter.
  bool update(ExplorationModel m, double dt) {
    if (completed || !m.active) return false;
    if (_delay > 0) {
      _delay = math.max(0, _delay - dt);
      if (_delay == 0) {
        index++;
        if (index == PracticeLesson.values.length) {
          completed = true;
          m.practiceTarget = null;
          m.phase = FieldPhase.won;
        } else {
          _prepare(m);
        }
        return true;
      }
      return false;
    }
    if (m.reloadFor > 0) _reloadSeen = true;
    final correct = switch (lesson) {
      PracticeLesson.move =>
        m.practiceTarget != null &&
            (m.player - m.practiceTarget!).distance <= 45,
      PracticeLesson.shoot => m.hits > _hits,
      PracticeLesson.crouch =>
        m.stance == PlayerStance.crouching && m.stanceFor == 0,
      PracticeLesson.prone =>
        m.stance == PlayerStance.prone && m.stanceFor == 0,
      PracticeLesson.stand =>
        m.stance == PlayerStance.standing && m.stanceFor == 0,
      PracticeLesson.reload =>
        _reloadSeen && m.reloadFor == 0 && m.ammo == m.gun.magazine,
      PracticeLesson.weapon => m.weapon != _weapon,
      PracticeLesson.door => m.world.navigationVersion > _doorVersion,
      PracticeLesson.hide => m.hidden,
      PracticeLesson.heal => m.health >= 80 && !m.healing,
      PracticeLesson.roll => m.rollFor > 0 || m.rollCooldown > 0,
    };
    if (correct) {
      _delay = 1.1;
      m.notice('Đúng rồi! $title hoàn thành.');
      return true;
    }
    return false;
  }
}
