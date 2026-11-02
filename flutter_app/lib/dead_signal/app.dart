import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/hand_bridge.dart';
import 'audio.dart';
import 'controller.dart';
import 'gesture_pointer.dart';
import 'hand_preview.dart';
import 'model.dart';
import 'scene.dart';
import 'settings.dart';

part 'compact.dart';
part 'wave_briefing.dart';

class DeadSignalApp extends StatefulWidget {
  const DeadSignalApp({
    super.key,
    this.bridge,
    this.settings,
    this.audioEnabled = true,
  });
  final HandBridge? bridge;
  final SignalSettings? settings;
  final bool audioEnabled;
  @override
  State<DeadSignalApp> createState() => _DeadSignalAppState();
}

class _DeadSignalAppState extends State<DeadSignalApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final HandBridge hand;
  late final SignalSettings settings;
  late final SignalController c;
  late final SignalAudio audio;
  late final Ticker ticker;
  Duration _last = Duration.zero;
  final _surfaceKey = GlobalKey(), _sceneKey = GlobalKey();
  final _navigator = GlobalKey<NavigatorState>();
  bool _handDown = false, _musicOn = false;
  Offset? _lastHandPosition;
  int _soundSerial = 0;
  SignalModel? _soundedModel;
  Offset _aim = const Offset(.5, .55);
  Size _canvasSize = const Size(1360, 860);
  String? _powerDrag;
  String _settingsMessage = '';

  @override
  void initState() {
    super.initState();
    hand = widget.bridge ?? HandBridge();
    settings = widget.settings ?? SignalSettings();
    c = SignalController(hand, settings);
    c.onPointer = _pointer;
    audio = SignalAudio(settings, enabled: widget.audioEnabled);
    ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1000000;
      _last = elapsed;
      c.tick(dt);
      final m = c.model;
      if (!identical(m, _soundedModel)) {
        _soundedModel = m;
        _soundSerial = 0;
      }
      if (m != null && m.soundSerial != _soundSerial) {
        _soundSerial = m.soundSerial;
        audio.play(m.sound);
      }
      final playing = m?.active == true && c.page == SignalPage.game;
      if (playing != _musicOn) {
        _musicOn = playing;
        unawaited(audio.sync(playing: playing));
      }
    })..start();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_key);
    if (widget.settings == null) unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      await settings.load();
    } on Object {
      _settingsMessage = 'Cài đặt đang dùng tạm cho phiên này.';
    }
    if (!mounted) return;
    hand.cameraIndex = settings.cameraIndex;
    hand.backend = settings.backend;
    c.refresh();
  }

  void _pointer(HandPointerEvent event) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final viewId = View.of(_surfaceKey.currentContext!).viewId;
      final position = box.localToGlobal(
        Offset(
          event.position.dx * box.size.width,
          event.position.dy * box.size.height,
        ),
      );
      final scene = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
      if (scene != null && scene.hasSize) {
        final local = scene.globalToLocal(position);
        if ((Offset.zero & scene.size).contains(local)) {
          _aim = Offset(
            local.dx / scene.size.width,
            local.dy / scene.size.height,
          );
        }
      }
      const pointer = 77;
      switch (event.action) {
        case PointerAction.down:
          if (_handDown) return;
          _handDown = true;
          _lastHandPosition = position;
          GestureBinding.instance.handlePointerEvent(
            PointerDownEvent(
              viewId: viewId,
              pointer: pointer,
              position: position,
              kind: PointerDeviceKind.touch,
            ),
          );
        case PointerAction.move:
          if (_handDown) {
            GestureBinding.instance.handlePointerEvent(
              PointerMoveEvent(
                viewId: viewId,
                pointer: pointer,
                position: position,
                delta: position - (_lastHandPosition ?? position),
                buttons: kPrimaryButton,
                kind: PointerDeviceKind.touch,
              ),
            );
            _lastHandPosition = position;
          }
        case PointerAction.up:
          if (_handDown) {
            GestureBinding.instance.handlePointerEvent(
              PointerUpEvent(
                viewId: viewId,
                pointer: pointer,
                position: position,
                kind: PointerDeviceKind.touch,
              ),
            );
          }
          _handDown = false;
          _lastHandPosition = null;
        case PointerAction.cancel:
          if (_handDown) {
            GestureBinding.instance.handlePointerEvent(
              PointerCancelEvent(
                viewId: viewId,
                pointer: pointer,
                position: position,
                kind: PointerDeviceKind.touch,
              ),
            );
          }
          _handDown = false;
          _lastHandPosition = null;
        case PointerAction.fist:
          break;
      }
    });
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent || _navigator.currentState?.canPop() == true) {
      return false;
    }
    final key = event.logicalKey, m = c.model;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (c.inRound) {
        if (m!.active || c.countdown > 0) {
          c.pause('Bạn đã tạm dừng.');
        } else {
          c.resume();
        }
        return true;
      }
    }
    if (c.page == SignalPage.calibration) {
      if (key == LogicalKeyboardKey.f1) {
        hand.calibrateOpen();
        return true;
      }
      if (key == LogicalKeyboardKey.f2) {
        hand.calibrateClosed();
        return true;
      }
    }
    if (m?.active != true || c.page != SignalPage.game) return false;
    final cams = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
    ];
    if (cams.contains(key)) {
      c.action((m) => m.selectCamera(cams.indexOf(key)));
      return true;
    }
    if (key == LogicalKeyboardKey.keyA) {
      c.action((m) => m.toggleDoor(0));
      return true;
    }
    if (key == LogicalKeyboardKey.keyD) {
      c.action((m) => m.toggleDoor(1));
      return true;
    }
    if (key == LogicalKeyboardKey.keyG) {
      c.action((m) => m.toggleGun());
      return true;
    }
    if (key == LogicalKeyboardKey.space) {
      c.action((m) => m.shoot(_aim));
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      c.setFocus(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_key);
    c.dispose();
    hand.dispose();
    audio.dispose();
    super.dispose();
  }

  Text text(
    String s, {
    double size = 14,
    Color color = signalText,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
  }) => Text(
    s,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
      height: 1.4,
    ),
  );
  Widget panel(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(20),
    Color? color,
  }) => Material(
    color: color ?? signalPanel,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: signalLine),
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
  Widget tag(String s, {Color color = signalGreen}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      border: Border.all(color: color.withValues(alpha: .3)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: text(s, size: 10, color: color, weight: FontWeight.w600, spacing: 1),
  );
  Widget button(
    String label,
    VoidCallback? action, {
    IconData? icon,
    bool primary = false,
    bool small = false,
    Key? key,
  }) => SizedBox(
    height: small ? 34 : 46,
    child: FilledButton.icon(
      key: key,
      onPressed: action,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: small ? 15 : 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: primary ? signalGreen : const Color(0xff1d2b35),
        foregroundColor: primary ? signalBg : signalText,
        disabledBackgroundColor: signalLine,
        disabledForegroundColor: signalMuted,
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 20),
        textStyle: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
  );
  Widget sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: text(
      label,
      size: 10,
      color: signalMuted,
      weight: FontWeight.w600,
      spacing: 1.8,
    ),
  );
  void _go(SignalPage page) {
    if (c.inRound && !c.model!.finished) {
      unawaited(_leave(page));
    } else {
      c.navigate(page);
    }
  }

  Future<void> _leave(SignalPage next) async {
    c.pause('Bạn đang rời ca trực.');
    final ok = await showDialog<bool>(
      context: _navigator.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Rời ca trực?'),
        content: const Text(
          'Lượt này sẽ kết thúc và không được tính là chiến thắng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời ca trực'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      c.abandon();
      c.navigate(next);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    title: 'DEAD SIGNAL · GesturePlay',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: signalBg,
      colorScheme: const ColorScheme.dark(
        primary: signalGreen,
        secondary: signalAmber,
        surface: signalPanel,
        onSurface: signalText,
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3),
      dialogTheme: const DialogThemeData(backgroundColor: signalPanel),
    ),
    home: Scaffold(
      body: LayoutBuilder(
        builder: (context, limits) {
          final compact = limits.maxWidth < 1000 || limits.maxHeight < 620;
          _canvasSize = compact
              ? Size(limits.maxWidth, limits.maxHeight)
              : const Size(1360, 860);
          return Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: const ValueKey('dead-signal-canvas'),
                child: SizedBox(
                  key: _surfaceKey,
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: Material(
                    color: signalBg,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([c, hand]),
                      builder: (context, _) => Stack(
                        children: [
                          if (compact)
                            _compactRoot()
                          else
                            Row(
                              children: [
                                _rail(),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      28,
                                      22,
                                      28,
                                      18,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _header(),
                                        const SizedBox(height: 22),
                                        Expanded(child: _page()),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (c.needsHand && hand.valid)
                            Positioned(
                              left:
                                  c.pointer.position.dx * _canvasSize.width -
                                  14,
                              top:
                                  c.pointer.position.dy * _canvasSize.height -
                                  14,
                              child: IgnorePointer(
                                child: Container(
                                  key: const ValueKey('hand-cursor'),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        (hand.pinched
                                                ? signalAmber
                                                : signalGreen)
                                            .withValues(alpha: .3),
                                    border: Border.all(
                                      color: hand.pinched
                                          ? signalAmber
                                          : signalGreen,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.near_me_outlined,
                                      size: 18,
                                      color: Colors.white,
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
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _rail() => Container(
    width: 76,
    decoration: const BoxDecoration(
      color: Color(0xff0d161d),
      border: Border(right: BorderSide(color: signalLine)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 27),
        const Icon(Icons.radar, color: signalGreen, size: 31),
        const SizedBox(height: 42),
        _nav(Icons.grid_view_rounded, 'Trang chủ', SignalPage.home),
        _nav(Icons.play_arrow_rounded, 'Nhiệm vụ', SignalPage.setup),
        _nav(Icons.pan_tool_outlined, 'Thực hành', SignalPage.tutorial),
        const Spacer(),
        _nav(Icons.tune_rounded, 'Cài đặt', SignalPage.settings),
        const SizedBox(height: 24),
        text('GP', size: 11, color: signalMuted, spacing: 2),
        const SizedBox(height: 23),
      ],
    ),
  );
  Widget _nav(IconData icon, String label, SignalPage page) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Tooltip(
      message: label,
      child: IconButton(
        onPressed: () => _go(page),
        icon: Icon(icon, size: 23),
        style: IconButton.styleFrom(
          fixedSize: const Size(46, 46),
          foregroundColor: c.page == page ? signalGreen : signalMuted,
          backgroundColor: c.page == page
              ? signalGreen.withValues(alpha: .1)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
  );
  Widget _header() => SizedBox(
    height: 48,
    child: Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            text(
              'GESTUREPLAY / DEAD SIGNAL',
              size: 11,
              color: signalMuted,
              spacing: 2,
              weight: FontWeight.w600,
            ),
            const SizedBox(height: 3),
            text(
              'TRẠM ĐIỀU KHIỂN 07',
              size: 15,
              weight: FontWeight.w600,
              spacing: 1,
            ),
          ],
        ),
        const Spacer(),
        tag(
          c.handControl ? 'ĐIỀU KHIỂN BÀN TAY' : 'ĐIỀU KHIỂN CHUỘT',
          color: c.handControl ? signalGreen : signalMuted,
        ),
        const SizedBox(width: 18),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: signalGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: c.needsHand ? hand.statusMessage : 'Phiên chơi tự do',
          child: text(
            c.needsHand ? _trackingLabel : 'PHIÊN CHƠI TỰ DO',
            size: 10,
            color: c.needsHand && !hand.valid ? signalAmber : signalMuted,
            spacing: 1,
          ),
        ),
        const SizedBox(width: 15),
        IconButton(
          tooltip: settings.muted ? 'Bật âm thanh' : 'Tắt âm thanh',
          onPressed: () {
            settings.muted = !settings.muted;
            unawaited(_saveSettings());
            c.refresh();
          },
          icon: Icon(
            settings.muted
                ? Icons.volume_off_outlined
                : Icons.volume_up_outlined,
            size: 19,
            color: signalMuted,
          ),
        ),
      ],
    ),
  );
  String get _trackingLabel {
    if (!hand.connected) return 'CHƯA KẾT NỐI TAY';
    if (hand.latest?.text('tracker_phase') == 'starting') {
      return 'ĐANG NẠP NHẬN DIỆN';
    }
    if (!hand.valid) return 'CHƯA NHẬN ĐƯỢC TAY';
    if (hand.latest?.flag('fist') == true) return 'ĐÃ NHẬN NẮM TAY';
    return hand.pinched ? 'ĐANG CHỤM NGÓN' : 'TAY SẴN SÀNG';
  }

  Widget _page() => switch (c.page) {
    SignalPage.home => _home(),
    SignalPage.setup => _setup(),
    SignalPage.calibration => _calibration(),
    SignalPage.tutorial => _tutorial(),
    SignalPage.settings => _settings(),
    SignalPage.game => _game(),
    SignalPage.result => _result(),
  };
  Widget _home() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 25, 35, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tag('TÍN HIỆU KHẨN CẤP', color: signalAmber),
                    const SizedBox(height: 24),
                    text(
                      'DEAD\nSIGNAL',
                      size: 76,
                      weight: FontWeight.w800,
                      spacing: -2,
                    ),
                    const SizedBox(height: 14),
                    text(
                      'Mọi cánh cửa đều có giới hạn.\nMỗi quyết định đều tiêu hao năng lượng.',
                      size: 19,
                      color: signalMuted,
                    ),
                    const SizedBox(height: 22),
                    text(
                      'Bạn đang mắc kẹt trong phòng an ninh. Quan sát hành lang, kiểm soát điện và ngăn sinh vật xâm nhập cho đến khi đội cứu hộ tới.',
                      size: 14,
                      color: signalMuted,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        button(
                          'Bắt đầu ca trực',
                          () => c.navigate(SignalPage.setup),
                          primary: true,
                          icon: Icons.arrow_forward_rounded,
                        ),
                        const SizedBox(width: 12),
                        button(
                          'Hướng dẫn',
                          () => c.navigate(SignalPage.tutorial),
                          icon: Icons.pan_tool_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    text(
                      'Một bàn tay. Ba camera. Không được mất cảnh giác.',
                      size: 11,
                      color: signalMuted,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: SecurityScene(preview: true)),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: signalLine),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 22,
                      left: 22,
                      child: tag('CAM 01 / HÀNH LANG TRUNG TÂM'),
                    ),
                    Positioned(
                      top: 22,
                      right: 22,
                      child: Row(
                        children: [
                          const Icon(Icons.circle, color: signalRed, size: 7),
                          const SizedBox(width: 6),
                          text('REC', size: 11, color: signalRed, spacing: 2),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 28,
                      left: 25,
                      right: 25,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          text(
                            'CỨU HỘ DỰ KIẾN',
                            size: 10,
                            color: signalMuted,
                            spacing: 2,
                          ),
                          text(
                            '03:00',
                            size: 55,
                            weight: FontWeight.w300,
                            spacing: 5,
                          ),
                          const SizedBox(height: 8),
                          text(
                            'Giữ phòng điều khiển an toàn đến hết giờ.',
                            size: 12,
                            color: signalGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: _metric(
              '03',
              'CAMERA GIÁM SÁT',
              'Quan sát và suy luận',
              Icons.videocam_outlined,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _metric(
              '02',
              'CỬA PHÒNG THỦ',
              'Quản lý điện và độ bền',
              Icons.door_front_door_outlined,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _metric(
              '180s',
              'THỜI GIAN SINH TỒN',
              'Chờ tín hiệu cứu hộ',
              Icons.timer_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 17),
      text(
        'Đề tài trò chơi 2D tương tác bằng cử chỉ bàn tay',
        size: 10,
        color: signalMuted,
      ),
    ],
  );
  Widget _metric(String value, String label, String detail, IconData icon) =>
      panel(
        Row(
          children: [
            Icon(icon, size: 25, color: signalMuted),
            const SizedBox(width: 17),
            text(value, size: 30, weight: FontWeight.w300, color: signalGreen),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(label, size: 10, spacing: 1, weight: FontWeight.w600),
                const SizedBox(height: 4),
                text(detail, size: 11, color: signalMuted),
              ],
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
      );
  Widget _title(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text(title, size: 30, weight: FontWeight.w600),
        const SizedBox(height: 5),
        text(subtitle, size: 13, color: signalMuted),
      ],
    ),
  );

  Widget _setup() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Chuẩn bị ca trực',
        'Bảo vệ phòng điều khiển. Cứu hộ đến sau 180 giây.',
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel('01 / ĐỘ KHÓ'),
                    _choice(
                      'Dễ',
                      '130 điện · 7 đợt · 12 quái · tốc độ chậm hơn',
                      c.difficulty == SignalDifficulty.easy,
                      () {
                        c.difficulty = SignalDifficulty.easy;
                        c.refresh();
                      },
                    ),
                    const SizedBox(height: 10),
                    _choice(
                      'Thường',
                      '100 điện · 7 đợt · 15 quái · tấn công phối hợp',
                      c.difficulty == SignalDifficulty.normal,
                      () {
                        c.difficulty = SignalDifficulty.normal;
                        c.refresh();
                      },
                    ),
                    const SizedBox(height: 24),
                    sectionLabel('02 / PHƯƠNG THỨC ĐIỀU KHIỂN'),
                    Row(
                      children: [
                        Expanded(
                          child: _choice(
                            'Chuột / chạm',
                            'Bắt đầu ngay',
                            !c.handControl,
                            () => c.setHand(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _choice(
                            'Bàn tay',
                            'Cần webcam laptop',
                            c.handControl,
                            () => c.setHand(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: text(
                        'Đầy đủ loại quái',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                      subtitle: text(
                        'Có quái gây nhiễu và boss. Tắt để luyện với hai loại cơ bản.',
                        size: 12,
                        color: signalMuted,
                      ),
                      value: c.advanced,
                      onChanged: (v) {
                        c.advanced = v;
                        c.refresh();
                      },
                    ),
                    const Spacer(),
                    button(
                      'Xem các đợt',
                      _showWavePlan,
                      small: true,
                      icon: Icons.format_list_numbered,
                    ),
                    const SizedBox(height: 10),
                    button(
                      c.handControl ? 'Kiểm tra bàn tay' : 'Vào ca trực',
                      () {
                        if (c.handControl) {
                          c.navigate(SignalPage.calibration);
                        } else {
                          c.prepare();
                        }
                      },
                      primary: true,
                      icon: Icons.arrow_forward,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel('HỒ SƠ NHIỆM VỤ'),
                    text(
                      'Đừng khóa cửa\nquá lâu.',
                      size: 28,
                      weight: FontWeight.w500,
                    ),
                    const SizedBox(height: 20),
                    _instruction(
                      Icons.videocam_outlined,
                      'Quan sát',
                      'Chuyển camera để tìm quái. Cảm biến chỉ báo khu vực có chuyển động.',
                    ),
                    _instruction(
                      Icons.bolt_outlined,
                      'Tiết kiệm điện',
                      'Camera, cửa khóa và mỗi phát bắn đều tiêu hao điện.',
                    ),
                    _instruction(
                      Icons.shield_outlined,
                      'Phòng thủ',
                      'Bắn để gây sát thương, đẩy lùi. Dùng thiết bị khi cần thêm thời gian.',
                    ),
                    const Spacer(),
                    tag('THẮNG: SỐNG SÓT ĐẾN 00:00'),
                    const SizedBox(height: 12),
                    text(
                      'Thua khi quái vượt qua cửa và xâm nhập phòng trực. Hết điện không kết thúc ván ngay, nhưng thiết bị sẽ ngừng hoạt động.',
                      size: 12,
                      color: signalMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _choice(
    String title,
    String subtitle,
    bool selected,
    VoidCallback action,
  ) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? signalGreen.withValues(alpha: .06) : signalBg,
        border: Border.all(color: selected ? signalGreen : signalLine),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? signalGreen : signalMuted,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text(title, size: 14, weight: FontWeight.w600),
                const SizedBox(height: 4),
                text(subtitle, size: 11, color: signalMuted),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _instruction(IconData icon, String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: signalGreen, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text(title, size: 14, weight: FontWeight.w600),
              const SizedBox(height: 4),
              text(detail, size: 12, color: signalMuted),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _calibration() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Kết nối bàn tay',
        'Đưa một bàn tay vào webcam. Hiệu chỉnh hai tư thế để hạn chế thao tác nhầm.',
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: panel(
                Column(
                  children: [
                    Expanded(child: _webcam()),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          hand.valid
                              ? Icons.check_circle_outline
                              : Icons.sensors_off,
                          color: hand.valid ? signalGreen : signalAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: text(
                            hand.statusMessage,
                            size: 13,
                            color: signalMuted,
                          ),
                        ),
                        button(
                          'Thử lại',
                          () => unawaited(hand.retry()),
                          small: true,
                          icon: Icons.refresh,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel('HIỆU CHỈNH ĐIỀU KHIỂN'),
                    _instruction(
                      Icons.open_with,
                      'Di chuyển ngón trỏ',
                      'Con trỏ sáng di chuyển theo tay. Hướng lòng bàn tay rõ về camera.',
                    ),
                    button(
                      '1. Ghi tay mở (F1)',
                      hand.valid ? hand.calibrateOpen : null,
                      icon: Icons.pan_tool_outlined,
                    ),
                    const SizedBox(height: 12),
                    button(
                      '2. Ghi tay chụm (F2)',
                      hand.valid ? hand.calibrateClosed : null,
                      icon: Icons.touch_app_outlined,
                    ),
                    const SizedBox(height: 16),
                    text(
                      hand.latest?.text('calibration_message') ??
                          'Mở ngón cái và trỏ, giữ ổn định rồi ghi tay mở.',
                      size: 13,
                      color: signalAmber,
                    ),
                    const SizedBox(height: 16),
                    _sensitivity(),
                    const Spacer(),
                    text(
                      'Mất tay sẽ tạm dừng. Mở hai ngón trước khi bắt đầu hoặc tiếp tục.',
                      size: 12,
                      color: signalMuted,
                    ),
                    const SizedBox(height: 16),
                    button(
                      'Bắt đầu ca trực',
                      hand.ready
                          ? () {
                              if (c.inputReady) c.prepare();
                            }
                          : null,
                      primary: true,
                      icon: Icons.play_arrow,
                    ),
                    const SizedBox(height: 10),
                    button('Chuyển sang chuột', () {
                      c.setHand(false);
                      c.prepare();
                    }, small: true),
                    const SizedBox(height: 10),
                    button(
                      'Dùng ngưỡng mặc định',
                      hand.resetCalibration,
                      small: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _webcam() => ClipRRect(
    borderRadius: BorderRadius.circular(7),
    child: ColoredBox(
      color: signalBg,
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable: hand.preview,
        builder: (context, bytes, _) => bytes == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_outlined,
                      size: 45,
                      color: signalMuted,
                    ),
                    const SizedBox(height: 16),
                    text(
                      hand.connecting
                          ? 'Đang mở kết nối…'
                          : 'Chưa có hình ảnh webcam',
                      color: signalMuted,
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: HandPreviewPainter(
                        hand.latest?.points ?? const [],
                        hand.pinched,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: tag(
                      hand.valid
                          ? (hand.pinched
                                ? 'ĐÃ NHẬN CHỤM NGÓN'
                                : 'ĐÃ NHẬN BÀN TAY')
                          : hand.latest?.text('tracker_phase') == 'starting'
                          ? 'ĐANG NẠP NHẬN DIỆN'
                          : 'ĐANG TÌM BÀN TAY',
                      color: hand.valid ? signalGreen : signalAmber,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _tutorial() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Hướng dẫn và thực hành',
        'Thao tác tại đây không tính điểm và không tiêu hao tài nguyên màn chơi.',
      ),
      Row(
        children: [
          button(
            c.handControl ? 'Đang dùng bàn tay' : 'Dùng bàn tay',
            () => c.setHand(!c.handControl),
            small: true,
            icon: Icons.pan_tool_outlined,
          ),
          const SizedBox(width: 12),
          text(
            c.handControl
                ? (hand.ready
                      ? 'Bàn tay sẵn sàng'
                      : 'Đưa tay vào webcam để thực hành')
                : 'Có thể thực hành bằng chuột hoặc chạm.',
            size: 12,
            color: signalMuted,
          ),
        ],
      ),
      const SizedBox(height: 18),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel('THAO TÁC CƠ BẢN'),
                    _instruction(
                      Icons.near_me_outlined,
                      'Trỏ để di chuyển',
                      'Đầu ngón trỏ điều khiển con trỏ sáng.',
                    ),
                    _instruction(
                      Icons.touch_app_outlined,
                      'Chụm rồi thả để chọn',
                      'Giữ chụm không tạo thêm lệnh. Bắn cũng dùng thao tác này trong chế độ súng.',
                    ),
                    _instruction(
                      Icons.drag_indicator,
                      'Giữ để kéo nguồn điện',
                      'Chụm trên nguồn, kéo đến thiết bị rồi thả. Thao tác kéo không được tính thành một lần chọn.',
                    ),
                    _instruction(
                      Icons.back_hand_outlined,
                      'Nắm tay để khóa khẩn cấp',
                      'Chọn cửa trước. Nắm tay chỉ tạo một lệnh cho đến khi bạn mở tay lại.',
                    ),
                    const Spacer(),
                    text(
                      'Trong ván: 1 / 2 / 3 đổi camera · A / D đóng mở cửa · G bật súng · Space bắn · Esc tạm dừng.',
                      size: 12,
                      color: signalMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sectionLabel('KHU VỰC THỰC HÀNH'),
                    button(
                      c.trainingSelected
                          ? 'Đã chọn mục tiêu ✓'
                          : '1. Chọn mục tiêu',
                      () {
                        c.trainingSelected = true;
                        c.refresh();
                      },
                      primary: !c.trainingSelected,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Draggable<String>(
                          data: 'practice',
                          feedback: _powerToken(),
                          childWhenDragging: Opacity(
                            opacity: .3,
                            child: _powerToken(),
                          ),
                          child: _powerToken(),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: DragTarget<String>(
                            onWillAcceptWithDetails: (d) =>
                                d.data == 'practice',
                            onAcceptWithDetails: (_) {
                              c.trainingDragged = true;
                              c.refresh();
                            },
                            builder: (context, items, _) => Container(
                              height: 75,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: items.isEmpty
                                    ? signalBg
                                    : signalGreen.withValues(alpha: .12),
                                border: Border.all(
                                  color: c.trainingDragged
                                      ? signalGreen
                                      : signalLine,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: text(
                                c.trainingDragged
                                    ? 'Đã cấp điện ✓'
                                    : '2. Thả nguồn điện vào đây',
                                size: 12,
                                color: signalGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    button(
                      c.trainingLocked
                          ? 'Cửa mẫu đã khóa ✓'
                          : '3. Chọn cửa mẫu',
                      () {
                        c.trainingLocked = true;
                        c.refresh();
                      },
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 8),
                    text(
                      'Khi dùng tay: chọn cửa mẫu, mở tay rồi nắm tay.',
                      size: 11,
                      color: signalMuted,
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          c.practiceShots++;
                          c.refresh();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: signalBg,
                            border: Border.all(color: signalLine),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.my_location,
                                  color: signalAmber,
                                  size: 38,
                                ),
                                const SizedBox(height: 10),
                                text('4. Chọn tâm ngắm để bắn thử', size: 12),
                                text(
                                  '${c.practiceShots} phát thử',
                                  size: 11,
                                  color: signalMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    button(
                      'Sẵn sàng nhận nhiệm vụ',
                      () => c.navigate(SignalPage.setup),
                      primary: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _powerToken() => Material(
    color: Colors.transparent,
    child: Container(
      width: 82,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xff293021),
        border: Border.all(color: signalAmber),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt, color: signalAmber, size: 24),
          text('NGUỒN', size: 9, color: signalAmber, spacing: 1),
        ],
      ),
    ),
  );
  Widget _sensitivity() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      text(
        'Độ nhạy con trỏ  ${settings.sensitivity.toStringAsFixed(1)}×',
        size: 12,
        color: signalMuted,
      ),
      Slider(
        value: settings.sensitivity,
        min: .5,
        max: 2,
        onChanged: (v) {
          settings.sensitivity = v;
          c.refresh();
        },
        onChangeEnd: (_) => unawaited(_saveSettings()),
      ),
    ],
  );
  Future<void> _saveSettings() async {
    try {
      await settings.save();
      _settingsMessage = 'Đã lưu cài đặt.';
    } on Object {
      _settingsMessage = 'Chưa lưu được cài đặt. Bạn có thể thử lại.';
    }
    await audio.sync(playing: _musicOn);
    if (mounted) c.refresh();
  }

  Widget _settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _title(
        'Cài đặt',
        'Điều chỉnh âm thanh, con trỏ và webcam trước khi vào ca trực.',
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel('ÂM THANH'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: text('Tắt toàn bộ âm thanh', size: 14),
                      value: settings.muted,
                      onChanged: (v) {
                        settings.muted = v;
                        unawaited(_saveSettings());
                        c.refresh();
                      },
                    ),
                    text('Nhạc nền', size: 12, color: signalMuted),
                    Slider(
                      value: settings.music,
                      onChanged: (v) {
                        settings.music = v;
                        c.refresh();
                      },
                      onChangeEnd: (_) => unawaited(_saveSettings()),
                    ),
                    text('Hiệu ứng', size: 12, color: signalMuted),
                    Slider(
                      value: settings.effects,
                      onChanged: (v) {
                        settings.effects = v;
                        c.refresh();
                      },
                      onChangeEnd: (_) {
                        audio.play('click');
                        unawaited(_saveSettings());
                      },
                    ),
                    const SizedBox(height: 24),
                    sectionLabel('ĐIỀU KHIỂN'),
                    _sensitivity(),
                    const Spacer(),
                    button('Khôi phục mặc định', () {
                      settings.reset();
                      c.refresh();
                      unawaited(_saveSettings());
                    }, icon: Icons.restart_alt),
                    const SizedBox(height: 12),
                    text(_settingsMessage, size: 12, color: signalMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionLabel('WEBCAM TRÊN LAPTOP'),
                    text(
                      'Camera nhận diện bàn tay',
                      size: 21,
                      weight: FontWeight.w500,
                    ),
                    const SizedBox(height: 12),
                    text(
                      'Ba camera trong trò chơi là mô phỏng. Chỉ webcam này được dùng để nhận diện tay.',
                      size: 13,
                      color: signalMuted,
                    ),
                    const SizedBox(height: 26),
                    DropdownButtonFormField<int>(
                      initialValue: settings.cameraIndex,
                      decoration: const InputDecoration(
                        labelText: 'Chỉ số webcam',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        4,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('Camera $i'),
                        ),
                      ),
                      onChanged: (v) {
                        settings.cameraIndex = v ?? 0;
                        c.refresh();
                      },
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: settings.backend,
                      decoration: const InputDecoration(
                        labelText: 'Cách mở webcam',
                        border: OutlineInputBorder(),
                      ),
                      items: ['dshow', 'msmf', 'auto']
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        settings.backend = v ?? 'dshow';
                        c.refresh();
                      },
                    ),
                    const SizedBox(height: 20),
                    button('Áp dụng webcam', () async {
                      hand.cameraIndex = settings.cameraIndex;
                      hand.backend = settings.backend;
                      await _saveSettings();
                    }, icon: Icons.check),
                    const Spacer(),
                    text(
                      'Sau khi thay webcam, vào mục kiểm tra bàn tay và hiệu chỉnh lại tư thế mở / chụm.',
                      size: 12,
                      color: signalMuted,
                    ),
                    const SizedBox(height: 20),
                    button('Kiểm tra bàn tay', () {
                      c.setHand(true);
                      c.navigate(SignalPage.calibration);
                    }, primary: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _game() {
    final m = c.model!;
    final minutes = m.remaining.ceil() ~/ 60, seconds = m.remaining.ceil() % 60;
    return Stack(
      children: [
        Column(
          children: [
            panel(
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: signalGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text(
                        'CA TRỰC ĐANG DIỄN RA',
                        size: 10,
                        color: signalMuted,
                        spacing: 1,
                      ),
                      text(
                        m.difficulty == SignalDifficulty.easy
                            ? 'Mức dễ / Khu nghiên cứu 07'
                            : 'Mức thường / Khu nghiên cứu 07',
                        size: 13,
                      ),
                    ],
                  ),
                  const Spacer(),
                  text('CỨU HỘ', size: 10, color: signalMuted, spacing: 1.5),
                  const SizedBox(width: 14),
                  text(
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    size: 29,
                    weight: FontWeight.w300,
                    color: m.remaining < 30 ? signalAmber : signalText,
                    spacing: 2,
                  ),
                  const Spacer(),
                  const Icon(Icons.bolt, color: signalAmber, size: 22),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value: m.battery,
                      minHeight: 5,
                      backgroundColor: signalLine,
                      color: m.battery < .2 ? signalRed : signalGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  text(
                    '${(m.battery * 100).ceil()}%',
                    size: 18,
                    color: m.battery < .2 ? signalRed : signalGreen,
                  ),
                  const SizedBox(width: 22),
                  button(
                    'Tạm dừng',
                    () => c.pause('Bạn đã tạm dừng.'),
                    small: true,
                    icon: Icons.pause,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 177, child: _cameraControls(m)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _viewport(m)),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 191,
                          child: Row(
                            children: [
                              SizedBox(width: 215, child: _map(m)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: panel(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      sectionLabel('NHẬT KÝ CẢNH BÁO'),
                                      for (final event in m.events.take(4))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: text(
                                            event,
                                            size: 11,
                                            color: signalMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(width: 274, child: _defenses(m)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  m.battery < .2
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  size: 15,
                  color: signalAmber,
                ),
                const SizedBox(width: 8),
                Expanded(child: text(m.message, size: 11, color: signalAmber)),
                text(
                  '${m.waveStatus}  /  ${m.kills} TIÊU DIỆT',
                  size: 10,
                  color: signalMuted,
                  spacing: 1,
                ),
              ],
            ),
          ],
        ),
        if (m.phase == RoundPhase.paused && c.countdown == 0) _pause(m),
        if (c.countdown > 0) _countdown(),
      ],
    );
  }

  Widget _cameraControls(SignalModel m) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionLabel('GIÁM SÁT'),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DragTarget<String>(
              onWillAcceptWithDetails: (d) => d.data == 'power',
              onAcceptWithDetails: (_) =>
                  c.action((m) => m.power('camera$i', true)),
              builder: (context, items, _) => InkWell(
                onTap: () => c.action((m) => m.selectCamera(i)),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: m.camera == i
                        ? signalGreen.withValues(alpha: .07)
                        : signalBg,
                    border: Border.all(
                      color: items.isNotEmpty
                          ? signalAmber
                          : m.camera == i
                          ? signalGreen
                          : signalLine,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          text(
                            'CAM 0${i + 1}',
                            size: 11,
                            weight: FontWeight.w600,
                            color: m.camera == i ? signalGreen : signalText,
                          ),
                          const Spacer(),
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: m.sensor(i) ? signalRed : signalMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      text(
                        ['Trung tâm', 'Hành lang trái', 'Hành lang phải'][i],
                        size: 11,
                        color: signalMuted,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 13,
                            color: m.cameraPower[i] ? signalAmber : signalMuted,
                          ),
                          const SizedBox(width: 5),
                          text(
                            m.cameraPower[i] ? 'Có điện' : 'Ngắt điện',
                            size: 10,
                            color: signalMuted,
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 26,
                            height: 22,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'Bật/tắt điện CAM 0${i + 1}',
                              onPressed: () => c.action(
                                (m) => m.power('camera$i', !m.cameraPower[i]),
                              ),
                              icon: Icon(
                                Icons.power_settings_new,
                                size: 15,
                                color: m.cameraPower[i]
                                    ? signalGreen
                                    : signalMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        text(
          'Chấm đỏ: có chuyển động. Không hiển thị vị trí chính xác của quái.',
          size: 10,
          color: signalMuted,
        ),
        const Spacer(),
        Draggable<String>(
          data: 'power',
          onDragStarted: () {
            _powerDrag = 'power';
            c.refresh();
          },
          onDragEnd: (_) {
            _powerDrag = null;
            c.refresh();
          },
          feedback: _powerToken(),
          childWhenDragging: Opacity(opacity: .3, child: _powerToken()),
          child: Center(child: _powerToken()),
        ),
        const SizedBox(height: 10),
        text(
          _powerDrag != null
              ? 'Thả vào thiết bị cần cấp điện.'
              : 'Kéo nguồn đến camera, cửa hoặc súng để cấp điện.',
          size: 10,
          color: signalMuted,
        ),
        const SizedBox(height: 15),
        text('TIÊU HAO', size: 9, color: signalMuted, spacing: 1),
        text(
          '${m.drain.toStringAsFixed(2)} điện / giây',
          size: 12,
          color: signalAmber,
        ),
      ],
    ),
    padding: const EdgeInsets.all(13),
  );
  Widget _viewport(SignalModel m) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: signalLine)),
      child: Column(
        children: [
          Container(
            height: 43,
            color: signalPanel,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  Icons.videocam_outlined,
                  color: m.cameraOnline ? signalGreen : signalRed,
                  size: 17,
                ),
                const SizedBox(width: 9),
                text(
                  'CAM 0${m.camera + 1} / ${['TRUNG TÂM', 'HÀNH LANG TRÁI', 'HÀNH LANG PHẢI'][m.camera]}',
                  size: 10,
                  weight: FontWeight.w600,
                  spacing: 1,
                ),
                const Spacer(),
                text(
                  m.silent
                      ? 'IM LẶNG'
                      : m.jammed
                      ? 'NHIỄU'
                      : m.cameraOnline
                      ? 'TRỰC TIẾP'
                      : 'MẤT ĐIỆN',
                  size: 9,
                  color: m.jammed ? signalRed : signalGreen,
                ),
              ],
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: m.gunMode
                  ? SystemMouseCursors.precise
                  : SystemMouseCursors.basic,
              onHover: (e) {
                final box =
                    _sceneKey.currentContext?.findRenderObject() as RenderBox?;
                if (box != null) {
                  _aim = Offset(
                    e.localPosition.dx / box.size.width,
                    e.localPosition.dy / box.size.height,
                  );
                }
              },
              child: GestureDetector(
                key: _sceneKey,
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final box =
                      _sceneKey.currentContext!.findRenderObject() as RenderBox;
                  _aim = Offset(
                    d.localPosition.dx / box.size.width,
                    d.localPosition.dy / box.size.height,
                  );
                  c.action((m) => m.shoot(_aim));
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: SecurityScene(model: m, aim: _aim),
                    ),
                    if (m.observedBoss case final boss?)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: Container(
                            width: 175,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: signalBg.withValues(alpha: .85),
                              border: Border.all(
                                color: boss.charging
                                    ? signalRed
                                    : boss.exposed
                                    ? signalAmber
                                    : signalLine,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                text(
                                  'VẬT CHỦ · ${boss.health.ceil()}/${boss.maxHealth.toInt()}',
                                  size: 10,
                                  weight: FontWeight.w700,
                                ),
                                text(
                                  boss.status,
                                  size: 9,
                                  color: boss.charging
                                      ? signalRed
                                      : boss.exposed
                                      ? signalAmber
                                      : signalMuted,
                                ),
                                if (boss.charging || boss.exposed) ...[
                                  const SizedBox(height: 5),
                                  LinearProgressIndicator(
                                    value: boss.charging
                                        ? 1 -
                                              boss.windupFor /
                                                  SignalRules.bossWindup
                                        : boss.weakFor /
                                              SignalRules.bossExposure,
                                    minHeight: 3,
                                    color: boss.charging
                                        ? signalRed
                                        : signalAmber,
                                    backgroundColor: signalLine,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!m.cameraOnline || m.jammed)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              m.jammed
                                  ? Icons.blur_on
                                  : Icons.videocam_off_outlined,
                              size: 35,
                              color: signalMuted,
                            ),
                            const SizedBox(height: 12),
                            text(
                              m.silent
                                  ? 'CHẾ ĐỘ IM LẶNG'
                                  : m.jammed
                                  ? 'TÍN HIỆU BỊ GÂY NHIỄU'
                                  : 'CAMERA KHÔNG CÓ ĐIỆN',
                              size: 12,
                              color: signalMuted,
                              spacing: 1,
                            ),
                            const SizedBox(height: 8),
                            text(
                              m.jammed
                                  ? 'Dùng cảm biến, đèn chớp hoặc loa để xử lý.'
                                  : 'Cấp điện hoặc trở lại chế độ thường.',
                              size: 10,
                              color: signalMuted,
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 13,
                      bottom: 13,
                      child: tag(
                        m.gunMode
                            ? 'TÂM NGẮM / CHỤM RỒI THẢ ĐỂ BẮN'
                            : 'QUAN SÁT / CHỌN THIẾT BỊ',
                        color: m.gunMode ? signalAmber : signalMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 45,
            color: signalPanel,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                text(
                  m.gunCooldown > 0
                      ? 'Hồi súng ${m.gunCooldown.toStringAsFixed(1)}s'
                      : 'Súng sẵn sàng · ${SignalRules.shotCost.toInt()} điện / phát',
                  size: 10,
                  color: signalMuted,
                ),
                const Spacer(),
                button(
                  m.gunMode ? 'Thoát ngắm' : 'Ngắm bắn',
                  () => c.action((m) => m.toggleGun()),
                  small: true,
                  primary: m.gunMode,
                  icon: Icons.my_location,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _map(SignalModel m) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text('SƠ ĐỒ / CHỌN KHU VỰC', size: 9, color: signalMuted, spacing: 1),
        const SizedBox(height: 3),
        Expanded(
          child: GestureDetector(
            onTapUp: (d) {
              final size = const Size(187, 140);
              var closest = 0;
              var distance = double.infinity;
              for (var i = 0; i < 3; i++) {
                final p = FacilityMap.zones[i];
                final next =
                    (d.localPosition -
                            Offset(p.dx * size.width, p.dy * size.height))
                        .distance;
                if (next < distance) {
                  distance = next;
                  closest = i;
                }
              }
              c.action((m) {
                m.selectedZone = closest;
              });
            },
            child: CustomPaint(
              painter: FacilityMap(m),
              size: const Size(double.infinity, double.infinity),
            ),
          ),
        ),
        text(
          'Vùng ${m.selectedZone + 1} được chọn',
          size: 9,
          color: signalGreen,
        ),
      ],
    ),
    padding: const EdgeInsets.all(13),
  );
  Widget _defenses(SignalModel m) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionLabel('CỬA PHÒNG THỦ'),
        _door(m, 0),
        const SizedBox(height: 9),
        _door(m, 1),
        const SizedBox(height: 15),
        Row(
          children: [
            text(
              'THIẾT BỊ CHIẾN THUẬT',
              size: 9,
              color: signalMuted,
              spacing: 1,
            ),
            const Spacer(),
            text('VÙNG ${m.selectedZone + 1}', size: 9, color: signalGreen),
          ],
        ),
        const SizedBox(height: 9),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: [for (final d in Defense.values) _defense(m, d)],
          ),
        ),
        const SizedBox(height: 6),
        DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data == 'power',
          onAcceptWithDetails: (_) => c.action((m) => m.power('gun', true)),
          builder: (context, items, _) => Row(
            children: [
              const Icon(Icons.gps_fixed, size: 16, color: signalMuted),
              const SizedBox(width: 7),
              text('Nguồn súng', size: 11, color: signalMuted),
              const Spacer(),
              Switch(
                value: m.gunPowered,
                onChanged: (v) => c.action((m) => m.power('gun', v)),
              ),
            ],
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(13),
  );
  Widget _door(SignalModel m, int i) {
    final d = m.doors[i];
    return DragTarget<String>(
      onWillAcceptWithDetails: (v) => v.data == 'power',
      onAcceptWithDetails: (_) => c.action((m) => m.power('door$i', true)),
      builder: (context, items, _) => InkWell(
        onTap: () => c.action((m) => m.selectDoor(i)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: m.selectedDoor == i
                ? signalGreen.withValues(alpha: .04)
                : signalBg,
            border: Border.all(
              color: items.isNotEmpty
                  ? signalAmber
                  : m.selectedDoor == i
                  ? signalGreen.withValues(alpha: .4)
                  : signalLine,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    d.broken
                        ? Icons.broken_image_outlined
                        : d.locked
                        ? Icons.lock_outline
                        : Icons.lock_open,
                    size: 16,
                    color: d.broken
                        ? signalRed
                        : d.locked
                        ? signalGreen
                        : signalAmber,
                  ),
                  const SizedBox(width: 7),
                  text(
                    i == 0 ? 'CỬA TRÁI' : 'CỬA PHẢI',
                    size: 10,
                    weight: FontWeight.w600,
                  ),
                  const Spacer(),
                  text(
                    d.broken
                        ? 'ĐÃ VỠ'
                        : d.locked
                        ? 'ĐÃ KHÓA'
                        : !d.powered
                        ? 'NGẮT ĐIỆN'
                        : 'ĐANG MỞ',
                    size: 8,
                    color: d.broken ? signalRed : signalMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (d.health / d.maxHealth).clamp(0, 1),
                minHeight: 3,
                color: d.health < 40 ? signalRed : signalGreen,
                backgroundColor: signalLine,
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  text(
                    '${d.health.ceil()}/${d.maxHealth.ceil()}',
                    size: 9,
                    color: signalMuted,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 27,
                    height: 24,
                    child: IconButton(
                      tooltip: 'Nguồn cửa ${i == 0 ? 'trái' : 'phải'}',
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          c.action((m) => m.power('door$i', !d.powered)),
                      icon: Icon(
                        Icons.power_settings_new,
                        size: 14,
                        color: d.powered ? signalGreen : signalMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  button(
                    d.locked ? 'Mở cửa' : 'Khóa cửa',
                    d.broken ? null : () => c.action((m) => m.toggleDoor(i)),
                    small: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defense(SignalModel m, Defense d) {
    final label = switch (d) {
      Defense.decoy => 'Loa dụ',
      Defense.flash => 'Đèn chớp',
      Defense.trap => 'Bẫy điện',
      Defense.barrier => 'Chặn đường',
      Defense.silence => 'Im lặng',
      Defense.reinforce => 'Gia cố cửa',
    };
    final icon = switch (d) {
      Defense.decoy => Icons.speaker_outlined,
      Defense.flash => Icons.flash_on,
      Defense.trap => Icons.electric_bolt,
      Defense.barrier => Icons.fence,
      Defense.silence => Icons.volume_off_outlined,
      Defense.reinforce => Icons.construction,
    };
    final cd = m.cooldowns[d]!;
    final status = cd > 0
        ? 'Hồi ${cd.ceil()}s'
        : d == Defense.reinforce
        ? 'Còn ${m.reinforcements}'
        : d == Defense.silence
        ? (m.silent ? 'ĐANG BẬT' : 'Bật / tắt')
        : '${m.cost(d).toInt()} điện';
    return Tooltip(
      message: switch (d) {
        Defense.decoy =>
          'Dụ quái về vùng chọn trong 8 giây; không ngắt quái đang đánh cửa.',
        Defense.flash =>
          'Choáng quái trong vùng chọn; boss chịu tác dụng ngắn hơn.',
        Defense.trap =>
          'Choáng quái ở đoạn giữa hành lang. Dùng hụt vẫn mất điện.',
        Defense.barrier =>
          'Chặn hành lang đã chọn trong 7 giây, buộc quái đổi đường.',
        Defense.silence =>
          'Giảm tốc độ truy tìm. Camera, súng và loa tạm ngừng.',
        Defense.reinforce =>
          'Tăng độ bền cửa đang chọn. Không sửa được cửa đã vỡ.',
      },
      child: InkWell(
        onTap: () => c.action((m) => m.activate(d)),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          decoration: BoxDecoration(
            color: d == Defense.silence && m.silent
                ? signalGreen.withValues(alpha: .12)
                : signalBg,
            border: Border.all(color: signalLine),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: cd > 0 ? signalMuted : signalAmber,
                  ),
                  const SizedBox(width: 5),
                  text(label, size: 10),
                ],
              ),
              const SizedBox(height: 6),
              text(status, size: 9, color: cd > 0 ? signalMuted : signalGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pause(SignalModel m) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: .82),
      child: Center(
        child: SizedBox(
          width: 470,
          child: panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tag('CA TRỰC ĐÃ TẠM DỪNG', color: signalAmber),
                const SizedBox(height: 20),
                text('Giữ vững tín hiệu.', size: 30, weight: FontWeight.w500),
                const SizedBox(height: 12),
                text(c.pauseReason, size: 13, color: signalMuted),
                const SizedBox(height: 12),
                text(
                  'Thời gian, điện và sinh vật đều đang dừng.',
                  size: 12,
                  color: signalMuted,
                ),
                if (c.handControl) ...[
                  const SizedBox(height: 15),
                  text(
                    hand.ready
                        ? 'Đã nhận tay. Mở hai ngón rồi chọn Tiếp tục.'
                        : hand.error ?? 'Đưa tay rõ vào webcam rồi thử lại.',
                    size: 12,
                    color: signalAmber,
                  ),
                  const SizedBox(height: 10),
                  button(
                    'Kết nối lại nhận diện',
                    () => unawaited(hand.retry()),
                    small: true,
                  ),
                ],
                const SizedBox(height: 23),
                button(
                  'Tiếp tục',
                  !c.focused || (c.handControl && !hand.ready)
                      ? null
                      : c.resume,
                  primary: true,
                  icon: Icons.play_arrow,
                ),
                const SizedBox(height: 12),
                button(
                  c.handControl ? 'Chuyển sang chuột' : 'Chuyển sang bàn tay',
                  () => c.setHand(!c.handControl),
                  icon: c.handControl
                      ? Icons.mouse_outlined
                      : Icons.pan_tool_outlined,
                ),
                const SizedBox(height: 12),
                button(
                  'Rời ca trực',
                  () => unawaited(_leave(SignalPage.home)),
                  icon: Icons.logout,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _countdown() => Positioned.fill(
    child: IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .65),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              text(
                'CHUẨN BỊ NHẬN CA',
                size: 12,
                color: signalGreen,
                spacing: 3,
              ),
              const SizedBox(height: 14),
              text('${c.countdown.ceil()}', size: 100, weight: FontWeight.w200),
              text(
                'Camera, cửa và nguồn điện đã sẵn sàng.',
                size: 13,
                color: signalMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _result() {
    final m = c.model!, r = m.result();
    final won = r.outcome == RoundPhase.won;
    return Center(
      child: SizedBox(
        width: 760,
        child: panel(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tag(
                won ? 'CỨU HỘ THÀNH CÔNG' : 'TÍN HIỆU ĐÃ MẤT',
                color: won ? signalGreen : signalRed,
              ),
              const SizedBox(height: 23),
              text(
                won ? 'Bạn đã sống sót.' : 'Phòng trực bị xâm nhập.',
                size: 38,
                weight: FontWeight.w500,
              ),
              const SizedBox(height: 12),
              text(
                won
                    ? 'Đội cứu hộ đã tiếp cận. Ca trực kết thúc.'
                    : 'Quan sát cảm biến và tiết kiệm điện để thử lại.',
                size: 14,
                color: signalMuted,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: _resultMetric('ĐIỂM', r.score.toString())),
                  Expanded(
                    child: _resultMetric('SỐNG SÓT', '${r.elapsed.floor()}s'),
                  ),
                  Expanded(child: _resultMetric('TIÊU DIỆT', '${r.kills}')),
                  Expanded(
                    child: _resultMetric(
                      'ĐIỆN CÒN',
                      '${(m.battery * 100).ceil()}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              text(
                '${m.difficulty == SignalDifficulty.easy ? 'Mức dễ' : 'Mức thường'} · ${c.handControl ? 'Bàn tay' : 'Chuột / chạm'} · ${r.hits}/${r.shots} phát trúng',
                size: 12,
                color: signalMuted,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  button(
                    'Chơi lại',
                    c.prepare,
                    primary: true,
                    icon: Icons.replay,
                  ),
                  const SizedBox(width: 12),
                  button(
                    'Đổi thiết lập',
                    () => c.navigate(SignalPage.setup),
                    icon: Icons.tune,
                  ),
                  const Spacer(),
                  button(
                    'Trang chủ',
                    () => c.navigate(SignalPage.home),
                    small: true,
                  ),
                ],
              ),
            ],
          ),
          padding: const EdgeInsets.all(35),
        ),
      ),
    );
  }

  Widget _resultMetric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      text(label, size: 10, color: signalMuted, spacing: 1),
      const SizedBox(height: 8),
      text(value, size: 30, color: signalGreen, weight: FontWeight.w300),
    ],
  );
}
