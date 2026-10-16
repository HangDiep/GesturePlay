import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/runner_controller.dart';
import '../game/runner_game.dart';
import '../game/runner_model.dart';
import '../services/hand_bridge.dart';
import '../services/local_scores.dart';
import '../services/project_paths.dart';

const navy = Color(0xff142633),
    teal = Color(0xff139182),
    mint = Color(0xff7fe6c0);
const paper = Color(0xfffafdf9),
    muted = Color(0xff687e89),
    gold = Color(0xffffc94c);

class GesturePlayApp extends StatefulWidget {
  const GesturePlayApp({super.key, this.bridge, this.scores});
  final HandBridge? bridge;
  final LocalScores? scores;
  @override
  State<GesturePlayApp> createState() => _GesturePlayAppState();
}

class _GesturePlayAppState extends State<GesturePlayApp>
    with WidgetsBindingObserver {
  late final HandBridge hand;
  late final LocalScores scores;
  late final RunnerController controller;
  late final GestureRunnerGame game;
  late final Widget gameWidget;
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    hand = widget.bridge ?? HandBridge();
    scores = widget.scores ?? LocalScores(ProjectPaths.results);
    controller = RunnerController(hand, scores);
    game = GestureRunnerGame(controller);
    if (const bool.fromEnvironment('DEFAULT_KEYBOARD')) {
      controller.control = ControlMode.keyboard;
    }
    gameWidget = GameWidget<GestureRunnerGame>(game: game, autofocus: false);
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_key);
    unawaited(
      scores.load().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.focused = true;
    } else {
      controller.lostFocus();
    }
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_navigatorKey.currentState?.canPop() == true) return false;
    final key = event.logicalKey, scene = controller.scene;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.arrowUp) {
      controller.jump();
      return scene == GameScene.playing;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (scene == GameScene.menu) {
        controller.prepare();
      } else if (scene == GameScene.preparing) {
        controller.begin();
      } else if (scene == GameScene.paused) {
        controller.resume();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (scene == GameScene.playing) {
        controller.pause();
      } else if (scene == GameScene.menu) {
        unawaited(SystemNavigator.pop());
      } else {
        controller.menu();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      if (scene == GameScene.paused) {
        controller.resume();
      } else {
        controller.pause();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyR &&
        [
          GameScene.playing,
          GameScene.paused,
          GameScene.result,
        ].contains(scene)) {
      controller.prepare();
      return true;
    }
    if (key == LogicalKeyboardKey.keyV) {
      controller.togglePreview();
      return true;
    }
    if (key == LogicalKeyboardKey.f3) {
      controller.toggleMetrics();
      return true;
    }
    if (scene == GameScene.preparing &&
        controller.control == ControlMode.hand) {
      if (key == LogicalKeyboardKey.f1) {
        hand.calibrateOpen();
        return true;
      }
      if (key == LogicalKeyboardKey.f2) {
        hand.calibrateClosed();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    game.dispose();
    hand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GesturePlay · Sky Runner',
    navigatorKey: _navigatorKey,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      colorScheme: ColorScheme.fromSeed(seedColor: teal),
    ),
    home: Scaffold(
      backgroundColor: navy,
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: RepaintBoundary(
            key: const ValueKey('gestureplay-canvas'),
            child: SizedBox(
              width: 1120,
              height: 700,
              child: Material(
                color: Colors.transparent,
                child: AnimatedBuilder(
                  animation: Listenable.merge([controller, hand]),
                  builder: (context, _) => Stack(
                    children: [
                      Positioned.fill(child: gameWidget),
                      ..._overlay(),
                      _text(
                        30,
                        671,
                        _hint(),
                        size: 13,
                        color: paper,
                        width: 1060,
                      ),
                      if (controller.showMetrics) _metrics(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _text(
    double x,
    double y,
    String text, {
    double size = 18,
    Color color = navy,
    double? width,
    bool bold = false,
  }) => Positioned(
    left: x,
    top: y,
    width: width,
    child: Text(
      text,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        height: 1.35,
      ),
    ),
  );
  Widget _panel(
    double x,
    double y,
    double w,
    double h, {
    Color color = paper,
  }) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
  Widget _button(
    double x,
    double y,
    double w,
    double h,
    String text,
    VoidCallback? action, {
    bool primary = false,
    bool selected = false,
  }) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: FilledButton(
      onPressed: action,
      style: FilledButton.styleFrom(
        backgroundColor: primary || selected ? teal : const Color(0xffe6efe9),
        foregroundColor: primary || selected ? paper : navy,
        disabledBackgroundColor: const Color(0xffd7dfdd),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontFamily: 'Segoe UI'),
      ),
      child: Text(text, maxLines: 1),
    ),
  );
  Widget _shade() =>
      Positioned.fill(child: ColoredBox(color: navy.withValues(alpha: .60)));
  List<Widget> _overlay() => switch (controller.scene) {
    GameScene.menu => _menu(),
    GameScene.preparing => _prepare(),
    GameScene.playing => [
      ..._hud(),
      if (controller.previewEnabled && controller.control == ControlMode.hand)
        _camera(856, 130, 224, 168),
    ],
    GameScene.countdown => [
      ..._hud(),
      _shade(),
      _text(
        490,
        220,
        '${math.max(1, controller.countdown.ceil())}',
        size: 96,
        bold: true,
        color: paper,
      ),
      _text(365, 380, 'Chuẩn bị nhảy khi gai đến gần', size: 24, color: paper),
    ],
    GameScene.paused => [..._hud(), ..._pause()],
    GameScene.result => [..._hud(), ..._result()],
  };

  List<Widget> _menu() => [
    _text(48, 30, 'GesturePlay', size: 28, bold: true),
    _text(
      681,
      45,
      'FLUTTER + FLAME  /  ĐIỀU KHIỂN BẰNG TAY',
      size: 14,
      color: teal,
    ),
    _panel(48, 120, 564, 522, color: navy),
    _text(80, 151, '01 / SKY RUNNER', size: 16, color: mint),
    _text(
      78,
      186,
      'Chạy. Nhảy.\nVượt giới hạn.',
      size: 48,
      bold: true,
      color: paper,
      width: 500,
    ),
    _text(
      80,
      330,
      'Robot tự chạy, bạn chọn đúng thời điểm nhảy.\nTránh gai và gom xu trong hành trình 120 giây.',
      size: 16,
      color: const Color(0xffbbd0d1),
      width: 475,
    ),
    _text(80, 405, 'CHỌN ĐỘ KHÓ', size: 13, color: mint),
    for (var i = 0; i < Difficulty.values.length; i++)
      _button(
        80 + i * 160.0,
        435,
        146,
        42,
        Difficulty.values[i].label,
        () => controller.selectDifficulty(Difficulty.values[i]),
        selected: controller.difficulty == Difficulty.values[i],
      ),
    _button(
      80,
      501,
      468,
      48,
      'Chơi bằng bàn tay',
      () => controller.prepare(ControlMode.hand),
      primary: true,
    ),
    _button(
      80,
      560,
      296,
      44,
      'Luyện bằng bàn phím',
      () => controller.prepare(ControlMode.keyboard),
    ),
    _button(390, 560, 158, 44, 'Thoát', () => unawaited(SystemNavigator.pop())),
    if (scores.error != null)
      _text(80, 615, scores.error!, size: 12, color: gold, width: 470),
    _panel(661, 128, 408, 178),
    _text(687, 151, 'Một cử chỉ, một cú nhảy', size: 24),
    _text(
      688,
      199,
      'Chụm ngón cái và ngón trỏ để nhảy.\nThả ra trước lần nhảy tiếp theo.',
      size: 16,
      color: muted,
      width: 350,
    ),
    _text(
      688,
      267,
      'Kỷ lục bằng tay: ${scores.best(controller.difficulty, ControlMode.hand)}',
      size: 14,
      color: teal,
    ),
    _panel(661, 595, 408, 47),
    _text(688, 606, '+10 vượt gai     +20 thu xu'),
  ];

  List<Widget> _prepare() {
    final keyboard = controller.control == ControlMode.keyboard,
        packet = hand.latest;
    final failed =
        hand.error != null ||
        packet?.text('camera_phase') == 'error' ||
        packet?.text('tracker_phase') == 'error';
    return [
      _shade(),
      _panel(104, 120, 912, 510),
      _text(140, 149, 'Sẵn sàng xuất phát', size: 32, bold: true),
      _text(
        142,
        199,
        'Mức ${controller.difficulty.label.toLowerCase()} · Một ván 120 giây',
        size: 16,
        color: muted,
      ),
      _text(
        142,
        259,
        keyboard
            ? 'SPACE hoặc ↑ để nhảy.\n\nChỉ nhảy khi robot chạm đất.\n\nP / Esc để tạm dừng; R để chơi lại.'
            : '1. Đưa một bàn tay vào vùng sáng rõ.\n\n2. Mở hai ngón, rồi chụm thử trước khi chơi.\n\n3. Chụm chưa nhận? Ghi hai tư thế bên phải.',
        size: 16,
        width: 470,
      ),
      if (keyboard) ...[
        _panel(652, 250, 320, 200, color: const Color(0xffe5f1e9)),
        _text(719, 310, 'SPACE', size: 40, bold: true, color: teal),
        _text(748, 385, 'Nhấn để nhảy'),
      ] else ...[
        _button(
          652,
          182,
          320,
          40,
          'Camera ${hand.cameraIndex} · ${hand.backend.toUpperCase()}  /  Đổi',
          _cameraSettings,
        ),
        _camera(652, 239, 320, 240),
        _text(
          652,
          490,
          hand.connecting
              ? 'Đang kết nối nhận diện…'
              : hand.pinched
              ? 'Đã nhận chụm · thả ra để bắt đầu'
              : hand.ready
              ? 'Tay ổn định, có thể bắt đầu'
              : packet?.text('reason', 'Đang chờ bàn tay') ??
                    'Đang chờ bàn tay',
          size: 14,
          color: teal,
          width: 320,
        ),
        _button(
          652,
          547,
          154,
          48,
          '1. Ghi tay mở',
          hand.ready ? hand.calibrateOpen : null,
        ),
        _button(
          818,
          547,
          154,
          48,
          '2. Ghi tay chụm',
          hand.ready &&
                  [
                    'opened',
                    'ready',
                  ].contains(packet?.text('calibration_stage'))
              ? hand.calibrateClosed
              : null,
        ),
        _text(
          652,
          606,
          'Hiệu chỉnh trong lần mở phần nhận diện này.',
          size: 12,
          color: muted,
        ),
        if (!failed) ...[
          _panel(142, 410, 470, 121, color: const Color(0xffe8f2ea)),
          _text(158, 421, 'THỬ CỬ CHỈ', size: 13, color: teal),
          _button(
            504,
            416,
            94,
            29,
            'Mặc định',
            hand.connected ? hand.resetCalibration : null,
          ),
          _text(
            158,
            447,
            hand.pinched
                ? 'Đã nhận chụm · thả hai ngón'
                : hand.released
                ? 'Đã mở · chụm thử hai ngón'
                : 'Đưa tay vào rồi mở hai ngón',
            size: 20,
            color: teal,
            width: 430,
          ),
          _text(
            158,
            482,
            packet?.text(
                  'calibration_message',
                  'Chụm chưa nhận? Ghi hai tư thế bên phải.',
                ) ??
                'Đang chuẩn bị nhận diện…',
            size: 14,
            color: muted,
            width: 430,
          ),
        ] else ...[
          _text(
            142,
            418,
            hand.error ??
                'Chưa mở được webcam/nhận diện. Kiểm tra quyền camera, đóng ứng dụng khác đang dùng webcam rồi thử lại.',
            size: 14,
            color: const Color(0xffa15636),
            width: 470,
          ),
          _button(
            142,
            490,
            220,
            36,
            'Thử lại nhận diện',
            () => unawaited(hand.retry()),
          ),
          _button(
            378,
            490,
            234,
            36,
            'Dùng bàn phím',
            () => controller.prepare(ControlMode.keyboard),
          ),
        ],
      ],
      _button(
        142,
        547,
        302,
        48,
        controller.canBegin ? 'Bắt đầu' : 'Đang chờ tay sẵn sàng…',
        controller.canBegin ? controller.begin : null,
        primary: true,
      ),
      _button(460, 547, 152, 48, 'Về menu', controller.menu),
    ];
  }

  Widget _camera(double x, double y, double w, double h) => Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: navy,
        child: ValueListenableBuilder<Uint8List?>(
          valueListenable: hand.preview,
          builder: (context, bytes, _) => Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, gaplessPlayback: true, fit: BoxFit.fill)
              else
                const Center(
                  child: Text(
                    'Đang chờ camera',
                    style: TextStyle(color: paper),
                  ),
                ),
              if (hand.valid)
                CustomPaint(
                  painter: FingerPainter(hand.latest!.points, hand.pinched),
                ),
              if (hand.valid)
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: ColoredBox(
                    color: navy,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(
                        hand.pinched
                            ? 'ĐÃ CHỤM · THẢ HAI NGÓN'
                            : 'ĐÃ MỞ · CHỤM ĐỂ NHẢY',
                        style: TextStyle(
                          fontSize: 12,
                          color: hand.pinched ? gold : mint,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _hud() {
    final model = controller.game!;
    final seconds = math.max(0, (120 - model.elapsed).ceil());
    final status = controller.control == ControlMode.keyboard
        ? 'SPACE để nhảy'
        : hand.pinched
        ? 'Đã nhận chụm · thả để nhảy tiếp'
        : hand.released
        ? 'Đã mở · chụm để nhảy'
        : 'Hãy mở hai ngón trước';
    return [
      _panel(28, 24, 1064, 78, color: navy),
      _text(50, 37, 'SKY RUNNER', size: 24, color: paper),
      _text(
        51,
        73,
        '${controller.difficulty.label} · ${controller.control == ControlMode.hand ? 'Bàn tay' : 'Bàn phím'}',
        size: 13,
        color: mint,
      ),
      _text(
        326,
        34,
        '${model.score}'.padLeft(4, '0'),
        size: 32,
        bold: true,
        color: paper,
      ),
      _text(328, 76, 'ĐIỂM', size: 12, color: mint),
      _text(468, 41, '${model.coinsCollected} xu', size: 24, color: gold),
      _text(
        640,
        36,
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
        size: 32,
        bold: true,
        color: paper,
      ),
      _text(790, 75, status, size: 12, color: mint, width: 285),
      if (controller.scene == GameScene.playing)
        _button(916, 36, 154, 40, 'Tạm dừng', controller.pause),
    ];
  }

  List<Widget> _pause() => [
    _shade(),
    _panel(300, 171, 520, 356),
    _text(470, 205, 'Tạm dừng', size: 32, bold: true),
    _text(340, 260, controller.pauseReason, size: 16, color: muted, width: 440),
    if (controller.control == ControlMode.hand)
      _text(
        340,
        312,
        controller.canResume
            ? 'Tay ổn định, có thể tiếp tục'
            : 'Đưa tay lại camera, mở hai ngón và giữ ổn định…',
        size: 16,
        color: teal,
        width: 440,
      ),
    _button(
      340,
      363,
      440,
      48,
      'Tiếp tục',
      controller.canResume ? controller.resume : null,
      primary: true,
    ),
    _button(340, 429, 211, 46, 'Chơi lại', () => controller.prepare()),
    _button(569, 429, 211, 46, 'Về menu', controller.menu),
  ];

  List<Widget> _result() {
    final result = controller.result!;
    return [
      _shade(),
      _panel(262, 121, 596, 500),
      _text(
        314,
        151,
        result.outcome == 'time_up'
            ? 'Hoàn thành hành trình!'
            : 'Thử lại một lần nữa!',
        size: 32,
        bold: true,
        width: 500,
      ),
      _text(493, 220, 'ĐIỂM CỦA BẠN', size: 14, color: teal),
      _text(455, 250, '${result.score}', size: 64, bold: true, width: 250),
      _panel(302, 345, 516, 80, color: const Color(0xffe8f2ea)),
      _text(352, 352, '${result.coins}', size: 24),
      _text(328, 393, 'Xu thu được', size: 14, color: muted),
      _text(526, 352, '${result.obstacles}', size: 24),
      _text(500, 393, 'Gai vượt qua', size: 14, color: muted),
      _text(
        688,
        352,
        '${(result.durationMs / 1000).toStringAsFixed(1)}s',
        size: 24,
      ),
      _text(671, 393, 'Thời gian chơi', size: 14, color: muted),
      _text(
        391,
        443,
        controller.saving
            ? 'Đang lưu trên máy…'
            : controller.saved
            ? 'Đã lưu kết quả trên máy'
            : 'Chưa lưu được kết quả trên máy',
        size: 16,
        color: teal,
        width: 400,
      ),
      _text(
        349,
        477,
        'Thành tích local · chưa xếp hạng trực tuyến',
        size: 13,
        color: muted,
      ),
      _button(
        302,
        521,
        246,
        48,
        'Chơi lại',
        () => controller.prepare(),
        primary: true,
      ),
      _button(566, 521, 252, 48, 'Về menu', controller.menu),
      if (!controller.saved && !controller.saving)
        _button(
          460,
          579,
          200,
          32,
          'Thử lưu lại',
          () => unawaited(controller.save()),
        ),
    ];
  }

  Widget _metrics() {
    final packet = hand.latest;
    return Stack(
      children: [
        _panel(26, 622, 1068, 35, color: navy),
        _text(
          42,
          629,
          'FPS game ${controller.fps.toStringAsFixed(1)}    Camera ${(packet?.number('camera_fps') ?? 0).toStringAsFixed(1)}    AI ${(packet?.number('result_fps') ?? 0).toStringAsFixed(1)}    Độ cũ ${hand.ageMs < 10000 ? '${hand.ageMs.toStringAsFixed(0)} ms' : '—'}',
          size: 14,
          color: mint,
        ),
        if (controller.control == ControlMode.hand)
          _text(
            787,
            629,
            'Độ mở ${packet?.number('ratio')?.toStringAsFixed(2) ?? '—'} · chụm ≤ ${packet?.number('press_threshold')?.toStringAsFixed(2) ?? '—'}',
            size: 14,
            color: mint,
          ),
      ],
    );
  }

  String _hint() => switch (controller.scene) {
    GameScene.menu =>
      'Enter  Chuẩn bị ${controller.control == ControlMode.hand ? 'bằng tay' : 'bàn phím'}     Esc  Thoát',
    GameScene.preparing =>
      controller.control == ControlMode.hand
          ? 'F1  Ghi tay mở     F2  Ghi tay chụm     Enter  Bắt đầu     Esc  Về menu'
          : 'Enter  Bắt đầu     Esc  Về menu',
    GameScene.paused => 'P / Enter  Tiếp tục     R  Chơi lại     Esc  Về menu',
    GameScene.result => 'R  Chơi lại     Esc  Về menu',
    GameScene.countdown => 'Giữ tay sẵn sàng     Esc  Về menu',
    GameScene.playing =>
      'P / Esc  Tạm dừng     R  Chơi lại     V  Camera     F3  Thông số',
  };

  Future<void> _cameraSettings() async {
    var index = hand.cameraIndex, backend = hand.backend;
    final apply = await showDialog<bool>(
      context: _navigatorKey.currentState!.overlay!.context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Chọn webcam'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: index,
                  decoration: const InputDecoration(labelText: 'Camera'),
                  items: List.generate(
                    4,
                    (i) => DropdownMenuItem(value: i, child: Text('Camera $i')),
                  ),
                  onChanged: (v) => setState(() => index = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: backend,
                  decoration: const InputDecoration(
                    labelText: 'Cách mở webcam',
                  ),
                  items: ['dshow', 'msmf', 'auto']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => backend = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
    if (apply == true) {
      await hand.configure(index, backend);
    }
  }
}

class FingerPainter extends CustomPainter {
  FingerPainter(this.points, this.pinched);
  final List<Offset> points;
  final bool pinched;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 2) return;
    final coordinates = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final paint = Paint()
      ..color = pinched ? gold : mint
      ..strokeWidth = 3;
    canvas.drawLine(coordinates[0], coordinates[1], paint);
    for (final p in coordinates) {
      canvas.drawCircle(p, 6, Paint()..color = navy);
      canvas.drawCircle(p, 4, paint);
    }
  }

  @override
  bool shouldRepaint(FingerPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.pinched != pinched;
}
