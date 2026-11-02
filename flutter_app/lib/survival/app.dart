import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ViewFocusEvent, ViewFocusState;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../dead_signal/audio.dart';
import '../dead_signal/hand_preview.dart';
import '../dead_signal/settings.dart';
import '../exploration/model.dart';
import '../exploration/world.dart';
import '../services/hand_bridge.dart';
import 'art.dart';
import 'hand_input.dart';
import 'painter.dart';
import 'rules.dart';

const _ink = Color(0xff0b171d),
    _cream = Color(0xffeee7d6),
    _muted = Color(0xffa3b1af),
    _gold = Color(0xffdeb779),
    _teal = Color(0xff72c7bc);

class SurvivalApp extends StatefulWidget {
  const SurvivalApp({
    super.key,
    this.bridge,
    this.settings,
    this.art,
    this.audioEnabled = true,
  });
  final HandBridge? bridge;
  final SignalSettings? settings;
  final TownArt? art;
  final bool audioEnabled;
  @override
  State<SurvivalApp> createState() => _SurvivalAppState();
}

class _SurvivalAppState extends State<SurvivalApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  final _scene = GlobalKey();
  final _keys = <LogicalKeyboardKey>{};
  final _handInput = TownHandInput();
  late final HandBridge hand;
  late final SignalSettings settings;
  late final SignalAudio audio;
  late final Ticker _ticker;
  late final ExplorationModel _preview;
  TownArt? _art;
  ExplorationModel? _model;
  Duration _last = Duration.zero;
  bool _handMode = false,
      _mouseFire = false,
      _touchFire = false,
      _music = false,
      _reducedEffects = false,
      _mapOpen = false,
      _mapWasPlaying = false;
  Offset _touchMove = Offset.zero;
  Offset? _mouseAt;
  String _error = '', _hint = '';
  int _soundSerial = 0, _howlSerial = 0, _seed = 42;
  double _clock = 0;

  @override
  void initState() {
    super.initState();
    hand = widget.bridge ?? HandBridge();
    settings = widget.settings ?? SignalSettings();
    audio = SignalAudio(settings, enabled: widget.audioEnabled);
    _preview = ExplorationModel(FieldMap.town, survival: true)
      ..player = const Offset(1100, 1260)
      ..aim = const Offset(1300, 1150)
      ..facing = -.3;
    _preview.spawn(CreatureKind.runner, at: const Offset(1250, 1110));
    _preview.spawn(CreatureKind.jammer, at: const Offset(1090, 960));
    _preview.spawn(CreatureKind.boss, at: const Offset(1190, 820));
    _art = widget.art;
    if (_art == null) unawaited(_loadArt());
    if (widget.settings == null) unawaited(_loadSettings());
    hand.addListener(_handChanged);
    HardwareKeyboard.instance.addHandler(_key);
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick)..start();
  }

  Future<void> _loadArt() async {
    setState(() => _error = '');
    try {
      final art = await TownArt.load();
      if (!mounted) {
        art.dispose();
        return;
      }
      setState(() => _art = art);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Không tải được hình ảnh thị trấn. Hãy thử tải lại.',
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      await settings.load();
    } on Object {
      /* Use session defaults. */
    }
    if (!mounted) return;
    hand.cameraIndex = settings.cameraIndex;
    hand.backend = settings.backend;
    setState(() {});
  }

  Future<void> _saveSettings() async {
    try {
      await settings.save();
    } on Object {
      /* Keep settings for this session. */
    }
  }

  void _handChanged() {
    if (mounted && _handMode) setState(() {});
  }

  void _tick(Duration time) {
    final dt = ((time - _last).inMicroseconds / 1000000).clamp(0.0, .1);
    _last = time;
    _clock += dt;
    final m = _model;
    if (m != null) {
      final wasActive = m.active;
      if (_handMode &&
          (m.active || _handInput.wheelOpen || _handInput.waitingRelease)) {
        _handInput.apply(m, hand, dt);
      } else if (m.active && !_handMode) {
        bool down(LogicalKeyboardKey key) => _keys.contains(key);
        m.movement =
            Offset(
              (down(LogicalKeyboardKey.keyD) ||
                          down(LogicalKeyboardKey.arrowRight)
                      ? 1.0
                      : 0) -
                  (down(LogicalKeyboardKey.keyA) ||
                          down(LogicalKeyboardKey.arrowLeft)
                      ? 1.0
                      : 0),
              (down(LogicalKeyboardKey.keyS) ||
                          down(LogicalKeyboardKey.arrowDown)
                      ? 1.0
                      : 0) -
                  (down(LogicalKeyboardKey.keyW) ||
                          down(LogicalKeyboardKey.arrowUp)
                      ? 1.0
                      : 0),
            ) +
            _touchMove;
        m.movement = TownView.movement(m.movement);
        m.sprinting =
            down(LogicalKeyboardKey.shiftLeft) ||
            down(LogicalKeyboardKey.shiftRight);
        m.firing = _mouseFire || _touchFire || down(LogicalKeyboardKey.keyF);
        _updateMouseAim(m);
      }
      m.update(dt);
      if (wasActive && !m.active) _clearInput();
      if (m.soundSerial != _soundSerial) {
        _soundSerial = m.soundSerial;
        audio.play(m.sound);
      }
      if (m.howlSerial != _howlSerial) {
        _howlSerial = m.howlSerial;
        if (m.active) audio.howl(m.howlGain);
      }
    } else {
      for (final e in _preview.enemies) {
        e.animation += dt;
      }
    }
    final playing = m?.active == true;
    if (_music != playing) {
      _music = playing;
      unawaited(audio.sync(playing: playing));
    }
    unawaited(audio.tension(playing: playing, critical: m?.lowHealth == true));
    if (mounted) setState(() {});
  }

  void _updateMouseAim(ExplorationModel m) {
    final box = _scene.currentContext?.findRenderObject() as RenderBox?;
    if (_mouseAt != null && box != null && box.hasSize) {
      m.aim = TownView(
        m.player,
        box.size,
        world: m.world,
      ).unprojectShot(_mouseAt!, TownView.muzzleHeight(m.stance.index));
    }
  }

  bool _key(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      _keys.remove(key);
      return false;
    }
    if (_navigator.currentState?.canPop() == true) return false;
    if (event is! KeyDownEvent) return false;
    if (_handMode && key == LogicalKeyboardKey.f1) {
      hand.calibrateOpen();
      return true;
    }
    if (_handMode && key == LogicalKeyboardKey.f2) {
      hand.calibrateClosed();
      return true;
    }
    if (_handMode && key == LogicalKeyboardKey.keyC) {
      _handInput.reset();
      return true;
    }
    final m = _model;
    if (m == null) return false;
    if (key == LogicalKeyboardKey.keyM ||
        _mapOpen &&
            (key == LogicalKeyboardKey.escape ||
                key == LogicalKeyboardKey.keyP)) {
      if (_mapOpen) {
        _closeMap();
      } else {
        _openMap();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (_handInput.wheelOpen) {
        _handInput.select(null);
      } else if (m.active) {
        _pause();
      } else if (m.phase == FieldPhase.paused) {
        _resume();
      }
      return true;
    }
    if (!m.active) return false;
    _keys.add(key);
    if (key == LogicalKeyboardKey.keyR) m.reload();
    if (key == LogicalKeyboardKey.keyQ) m.flash();
    if (key == LogicalKeyboardKey.keyE) m.trap();
    if (key == LogicalKeyboardKey.space) m.roll();
    if (key == LogicalKeyboardKey.keyG) _toggleHide();
    if (key == LogicalKeyboardKey.keyX) {
      m.setStance(
        m.stance == PlayerStance.crouching
            ? PlayerStance.standing
            : PlayerStance.crouching,
      );
    }
    if (key == LogicalKeyboardKey.keyZ) {
      m.setStance(
        m.stance == PlayerStance.prone
            ? PlayerStance.standing
            : PlayerStance.prone,
      );
    }
    return _keys.contains(key);
  }

  void _clearInput() {
    _keys.clear();
    _mouseFire = _touchFire = false;
    _touchMove = Offset.zero;
    _mouseAt = null;
    _model?.firing = false;
    _model?.movement = Offset.zero;
  }

  void _setHand(bool value) {
    _clearInput();
    _handInput.reset();
    setState(() {
      _handMode = value;
      _hint = '';
    });
    if (value) {
      unawaited(hand.start());
      hand.setPreview(true);
    } else {
      hand.stop();
    }
  }

  void _start({bool retry = false}) {
    if (_handMode && (!hand.ready || !hand.released)) {
      setState(() => _hint = 'Đưa bàn tay mở rõ vào webcam trước khi bắt đầu.');
      return;
    }
    if (!retry) _seed = DateTime.now().millisecondsSinceEpoch;
    _clearInput();
    _handInput.reset();
    hand.discardJumps();
    setState(() {
      _model = ExplorationModel(FieldMap.town, seed: _seed, survival: true)
        ..start();
      _soundSerial = 0;
      _howlSerial = 0;
      _mapOpen = false;
      _hint = '';
    });
  }

  void _pause() {
    _model?.pause();
    _clearInput();
    _handInput.reset();
    unawaited(audio.silenceTension());
    setState(() {});
  }

  void _resume() {
    if (_handMode && (!hand.ready || !hand.released)) {
      setState(() => _hint = 'Mở tay rõ trong webcam rồi bấm Tiếp tục.');
      return;
    }
    _clearInput();
    _handInput.reset();
    hand.discardJumps();
    _model?.resume();
    setState(() => _hint = '');
  }

  void _toggleHide() {
    _clearInput();
    _handInput.reset();
    setState(() => _model?.toggleHide());
  }

  void _openMap() {
    if (_model == null || _model!.finished) return;
    _mapWasPlaying = _model!.active;
    if (_mapWasPlaying) _pause();
    setState(() => _mapOpen = true);
  }

  void _closeMap() {
    setState(() => _mapOpen = false);
    if (_mapWasPlaying) _resume();
  }

  Future<void> _home() async {
    if (_model?.phase == FieldPhase.paused) {
      final leave = await showDialog<bool>(
        context: _navigator.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('Rời lượt sinh tồn?'),
          content: const Text('Tiến trình lượt này sẽ kết thúc.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    _clearInput();
    _handInput.reset();
    setState(() {
      _model = null;
      _hint = '';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _model?.active == true) _pause();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.unfocused && _model?.active == true) {
      _pause();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_key);
    hand.removeListener(_handChanged);
    hand.stop();
    if (widget.bridge == null) hand.dispose();
    if (widget.art == null) _art?.dispose();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    title: 'GesturePlay — DEAD SIGNAL',
    theme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: _ink,
      colorScheme: const ColorScheme.dark(
        primary: _gold,
        surface: Color(0xff14242a),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _ink,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xff14242a)),
      useMaterial3: true,
    ),
    home: Scaffold(
      body: SafeArea(
        child: RepaintBoundary(
          key: const ValueKey('town-canvas'),
          child: _art == null
              ? _loading()
              : _model == null
              ? _menu()
              : _game(),
        ),
      ),
    ),
  );

  Widget _loading() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DEAD SIGNAL',
          style: TextStyle(color: _cream, fontSize: 32, letterSpacing: 6),
        ),
        const SizedBox(height: 24),
        if (_error.isEmpty) ...[
          const CircularProgressIndicator(color: _gold),
          const SizedBox(height: 18),
          const Text('Đang mở lối vào thị trấn…'),
        ] else ...[
          Text(_error),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loadArt,
            child: const Text('Tải lại hình ảnh'),
          ),
        ],
      ],
    ),
  );

  // UI sections below share the same world renderer used by the actual game.
  Widget _menu() => _menuContent();
  Widget _game() => _gameContent();

  Widget _menuContent() => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 900;
      return Stack(
        key: const ValueKey('town-menu'),
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: TownPainter(
                _preview,
                _art!,
                showcase: true,
                clock: _clock,
                reducedEffects: _reducedEffects,
                reticle: false,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xf5081319),
                    const Color(0xc9081319),
                    const Color(0x24081319),
                  ],
                  stops: const [0, .38, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 64 : 24,
                26,
                wide ? 56 : 24,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radar, color: _gold, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'GESTUREPLAY',
                        style: TextStyle(
                          color: _cream,
                          letterSpacing: 3,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Hướng dẫn',
                        onPressed: _help,
                        icon: const Icon(Icons.help_outline, color: _muted),
                      ),
                      IconButton(
                        tooltip: 'Cài đặt',
                        onPressed: _settings,
                        icon: const Icon(Icons.tune, color: _muted),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: wide ? math.max(40, size.maxHeight * .13) : 36,
                  ),
                  _eyebrow('TÍN HIỆU CUỐI CÙNG'),
                  const SizedBox(height: 14),
                  Text(
                    'DEAD\nSIGNAL',
                    style: TextStyle(
                      color: _cream,
                      height: .94,
                      fontSize: wide ? 88 : 60,
                      fontWeight: FontWeight.w800,
                      letterSpacing: wide ? 9 : 5,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Thị trấn đã im tiếng.\nĐừng để tín hiệu của bạn biến mất.',
                    style: TextStyle(color: _muted, fontSize: 16, height: 1.65),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [_controlChoice(false), _controlChoice(true)],
                  ),
                  if (_handMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: SizedBox(width: 360, child: _handPreview()),
                    ),
                  if (_hint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_hint, style: const TextStyle(color: _gold)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('town-start'),
                    onPressed: _start,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BẮT ĐẦU SINH TỒN',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(width: 24),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _help,
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 17),
                    label: const Text('Cách sống sót trong thị trấn'),
                  ),
                  const SizedBox(height: 42),
                  Wrap(
                    spacing: 26,
                    runSpacing: 14,
                    children: [
                      _menuFact('01', 'BẢN ĐỒ'),
                      _menuFact('03:00', 'SINH TỒN'),
                      _menuFact('05', 'ĐỢT TẤN CÔNG'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (wide)
            Positioned(
              right: 42,
              bottom: 36,
              child: _panel(
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _eyebrow('KHU VỰC DUY NHẤT'),
                      const SizedBox(height: 8),
                      const Text(
                        'THỊ TRẤN BỊ PHONG TỎA',
                        style: TextStyle(
                          color: _cream,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Phố cổ  /  Đêm mưa  /  Mất liên lạc',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _controlChoice(bool useHand) => ChoiceChip(
    selected: _handMode == useHand,
    avatar: Icon(
      useHand ? Icons.back_hand_outlined : Icons.keyboard_alt_outlined,
      size: 17,
    ),
    label: Text(useHand ? 'Bàn tay / Webcam' : 'Bàn phím / Cảm ứng'),
    onSelected: (_) => _setHand(useHand),
    selectedColor: const Color(0xff35433c),
    backgroundColor: const Color(0xb3101d23),
    side: BorderSide(
      color: _handMode == useHand
          ? _gold.withValues(alpha: .6)
          : const Color(0xff34454b),
    ),
  );
  Widget _menuFact(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(color: _cream, fontSize: 22, letterSpacing: 2),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.8),
      ),
    ],
  );

  Widget _gameContent() => LayoutBuilder(
    builder: (context, size) {
      final m = _model!;
      final compact = size.maxWidth < 900;
      final tiny = size.maxHeight < 460;
      return Stack(
        key: const ValueKey('town-game'),
        children: [
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (e) => _mouseAt = e.localPosition,
              child: Listener(
                onPointerDown: (e) {
                  if (e.kind == PointerDeviceKind.mouse &&
                      e.buttons & kPrimaryMouseButton != 0 &&
                      m.active &&
                      !_handMode) {
                    _mouseAt = e.localPosition;
                    _mouseFire = true;
                  }
                },
                onPointerMove: (e) {
                  if (e.kind == PointerDeviceKind.mouse) {
                    _mouseAt = e.localPosition;
                  }
                },
                onPointerUp: (_) => _mouseFire = false,
                onPointerCancel: (_) => _mouseFire = false,
                child: CustomPaint(
                  key: _scene,
                  painter: TownPainter(
                    m,
                    _art!,
                    reducedEffects: _reducedEffects,
                    reticle: !_handMode && !compact,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 14 : 26,
            top: compact ? 12 : 24,
            child: SizedBox(
              width: compact ? 144 : 226,
              child: _panel(
                Padding(
                  padding: EdgeInsets.all(compact ? 10 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact) ...[
                        _eyebrow('NGƯỜI GIỮ TÍN HIỆU'),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: 15,
                            color: m.lowHealth
                                ? const Color(0xffff6c64)
                                : const Color(0xffd48672),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${m.health.ceil()} / 100',
                            style: TextStyle(
                              color: m.lowHealth
                                  ? const Color(0xffff7770)
                                  : _cream,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'HP',
                            style: TextStyle(color: _muted, fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      _bar(
                        m.health / 100,
                        m.lowHealth
                            ? const Color(0xfff35353)
                            : const Color(0xffc77d65),
                        5,
                      ),
                      const SizedBox(height: 7),
                      _bar(m.stamina / 100, _teal, 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: compact ? 12 : 22,
            left: compact ? 174 : size.maxWidth / 2 - 110,
            child: SizedBox(
              width: compact ? 106 : 220,
              child: Column(
                children: [
                  _eyebrow(compact ? 'SINH TỒN' : 'GIỮ TÍN HIỆU CỨU HỘ'),
                  const SizedBox(height: 3),
                  Text(
                    _time(m.rescueIn.ceil()),
                    style: TextStyle(
                      color: m.rescueIn <= 20 ? _gold : _cream,
                      fontSize: compact ? 28 : 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _bar(m.elapsed / TownRules.duration, _gold, 2),
                  const SizedBox(height: 6),
                  Text(
                    'ĐỢT ${m.wave}/5',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: compact ? 10 : 24,
            top: compact ? 12 : 22,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact)
                  IconButton(
                    tooltip: 'Bản đồ toàn khu vực (M)',
                    onPressed: m.finished ? null : _openMap,
                    icon: const Icon(
                      Icons.map_outlined,
                      color: _muted,
                      size: 20,
                    ),
                  ),
                if (!compact)
                  IconButton(
                    tooltip: settings.muted ? 'Bật âm thanh' : 'Tắt âm thanh',
                    onPressed: _mute,
                    icon: Icon(
                      settings.muted
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      color: _muted,
                      size: 20,
                    ),
                  ),
                _panel(
                  IconButton(
                    tooltip: 'Tạm dừng',
                    onPressed: m.active ? _pause : null,
                    icon: const Icon(Icons.pause, color: _cream, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Positioned(
              right: 24,
              top: 85,
              child: _panel(
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 142,
                        height: 110,
                        child: CustomPaint(painter: TownRadar(m)),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        m.jammed
                            ? 'CẢM BIẾN BỊ NHIỄU'
                            : 'THỊ TRẤN / M XEM RỘNG',
                        style: TextStyle(
                          color: m.jammed ? _gold : _muted,
                          fontSize: 9,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_handMode && !tiny)
            Positioned(
              right: compact ? 12 : 24,
              top: compact ? 110 : 236,
              child: SizedBox(
                width: compact ? 132 : 160,
                child: _handPreview(),
              ),
            ),
          if (m.active && m.messageFor > 0 && !tiny)
            Positioned(
              top: compact ? 194 : 108,
              left: compact ? 14 : size.maxWidth / 2 - 190,
              right: compact ? (_handMode ? 154 : 14) : null,
              child: SizedBox(
                width: compact ? null : 380,
                child: _panel(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Text(
                      m.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: compact ? 14 : 26,
            bottom: compact ? 148 : 24,
            child: _panel(
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 18,
                  vertical: compact ? 8 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.gps_fixed, color: _gold, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${m.ammo}'.padLeft(2, '0'),
                          style: TextStyle(
                            color: _cream,
                            fontSize: compact ? 25 : 34,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 7, bottom: 5),
                          child: Text(
                            '/ ${m.reserve}',
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'LÕI ${m.cores}/3  ·  HẠ ${m.kills}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 14 : 26,
            top: compact ? 94 : 154,
            child: SizedBox(
              width: compact
                  ? (_handMode ? size.maxWidth - 170 : size.maxWidth - 28)
                  : 226,
              child: _tensionStatus(m, tiny),
            ),
          ),
          if (m.active && (m.nearbyHiding != null || m.hidden))
            Positioned(
              bottom: compact ? (tiny ? 136 : 282) : 100,
              left: size.maxWidth / 2 - 115,
              child: SizedBox(
                width: 230,
                child: _panel(
                  TextButton.icon(
                    key: const ValueKey('hide-button'),
                    onPressed: _toggleHide,
                    icon: Icon(
                      m.hidden
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      size: 17,
                    ),
                    label: Text(
                      m.hidden ? 'G · RỜI CHỖ ẨN' : 'G · ẨN NẤP',
                      style: const TextStyle(fontSize: 12, letterSpacing: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: compact ? 14 : 24,
            bottom: compact ? 148 : 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _skill(
                  'Q',
                  Icons.flash_on_outlined,
                  m.flashes,
                  m.flashCooldown,
                  () => m.flash(),
                  compact,
                ),
                const SizedBox(width: 8),
                _skill(
                  'E',
                  Icons.bolt,
                  m.traps,
                  m.trapCooldown,
                  () => m.trap(),
                  compact,
                ),
                const SizedBox(width: 8),
                _skill(
                  'R',
                  Icons.refresh,
                  null,
                  m.reloadFor,
                  m.reload,
                  compact,
                ),
              ],
            ),
          ),
          if (!compact && !_handMode && m.active)
            Positioned(
              left: 280,
              right: 270,
              bottom: 30,
              child: Text(
                'WASD  Đi  •  CHUỘT  Bắn  •  X  Ngồi  •  Z  Nằm\nSPACE  Lướt  •  SHIFT  Chạy  •  G  Ẩn  •  M  Bản đồ  •  ESC  Dừng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted.withValues(alpha: .8),
                  fontSize: 10,
                  height: 1.8,
                ),
              ),
            ),
          if (compact && !_handMode) ...[
            Positioned(left: 18, bottom: 18, child: _pad(false)),
            Positioned(right: 18, bottom: 18, child: _pad(true)),
            Positioned(
              left: size.maxWidth / 2 - 26,
              bottom: 32,
              child: _panel(
                IconButton(
                  tooltip: m.stance == PlayerStance.prone
                      ? 'Đứng dậy trước khi lướt'
                      : 'Lướt né',
                  onPressed: m.active ? () => m.roll() : null,
                  icon: const Icon(Icons.double_arrow, color: _gold),
                ),
              ),
            ),
          ],
          if (compact)
            Positioned(
              left: size.maxWidth / 2 - 26,
              bottom: 88,
              child: _panel(
                IconButton(
                  tooltip: 'Bản đồ toàn khu vực (M)',
                  onPressed: m.finished ? null : _openMap,
                  icon: const Icon(Icons.map_outlined, color: _gold),
                ),
              ),
            ),
          Positioned(
            left: compact ? (tiny ? 154 : 14) : 26,
            bottom: compact ? (tiny ? 18 : 228) : 126,
            child: SizedBox(
              width: compact && tiny ? 224 : 230,
              child: _stanceButtons(m),
            ),
          ),
          if (!_mapOpen &&
              (m.phase == FieldPhase.paused || m.finished && m.dyingFor == 0))
            Positioned.fill(child: _overlay(m)),
          if (_mapOpen) Positioned.fill(child: _mapOverlay(m)),
        ],
      );
    },
  );

  String _time(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _stanceButtons(ExplorationModel m) => _panel(
    Row(
      children: [
        for (final stance in PlayerStance.values)
          Expanded(
            child: Tooltip(
              message: const [
                'Đứng: nhanh, dễ lộ',
                'Ngồi: chậm, nấp vật chắn thấp',
                'Nằm: bò chậm, kín hơn trong bụi',
              ][stance.index],
              child: InkWell(
                key: ValueKey('stance-${stance.name}'),
                onTap: m.active && m.stanceFor == 0
                    ? () => setState(() => m.setStance(stance))
                    : null,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: m.stance == stance
                        ? const Color(0x3046a5a1)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: m.stance == stance ? _gold : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        const [
                          Icons.accessibility_new,
                          Icons.airline_seat_legroom_normal,
                          Icons.airline_seat_flat,
                        ][stance.index],
                        size: 16,
                        color: m.stance == stance ? _gold : _muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        const ['Đứng', 'X Ngồi', 'Z Nằm'][stance.index],
                        style: TextStyle(
                          color: m.stance == stance ? _cream : _muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _wheelPostures(ExplorationModel m) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        for (final stance in PlayerStance.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: OutlinedButton(
                onPressed: _handInput.waitingRelease
                    ? null
                    : () => setState(() => _handInput.select(stance.index + 3)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _handInput.selection == stance.index + 3
                        ? _gold
                        : _muted,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(const ['Đứng', 'Ngồi', 'Nằm'][stance.index]),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _tensionStatus(ExplorationModel m, bool tiny) => _panel(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.world.locationAt(m.player),
            style: const TextStyle(
              color: _muted,
              fontSize: 9,
              letterSpacing: 1.8,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              m.stanceFor > 0
                  ? 'ĐANG ĐỔI TƯ THẾ…'
                  : '${m.stanceName}${m.usingLowCover
                        ? ' · GẦN VẬT CHẮN'
                        : m.stance == PlayerStance.prone && m.inVegetation
                        ? ' · KÍN TRONG BỤI'
                        : ''}',
              key: const ValueKey('stance-status'),
              style: const TextStyle(color: _teal, fontSize: 10),
            ),
          ),
          if (m.lowHealth)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'NGUY KỊCH · TÌM TÚI MÁU',
                key: const ValueKey('critical-health-warning'),
                style: const TextStyle(
                  color: Color(0xffff7770),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (m.hidden) ...[
            const SizedBox(height: 5),
            Text(
              'ĐANG ẨN · ${m.hideFor.ceil()}s NÍN THỞ',
              style: const TextStyle(color: _teal, fontSize: 10),
            ),
            const SizedBox(height: 5),
            _bar(m.hideFor / TownRules.hideDuration, _teal, 3),
          ] else if (m.howlFor > 0)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'TIẾNG HÚ · QUÁI ĐANG ĐẾN GẦN',
                key: ValueKey('threat-warning'),
                style: TextStyle(
                  color: _gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (m.threatDistance < 160)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'NGUY HIỂM · QUÁI ÁP SÁT',
                style: TextStyle(color: Color(0xffed967e), fontSize: 10),
              ),
            ),
          if (m.blackoutFor > 0 && !tiny)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'MẤT ĐIỆN · ${m.blackoutFor.ceil()}s',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _mapOverlay(ExplorationModel m) => LayoutBuilder(
    builder: (context, size) => ColoredBox(
      color: const Color(0xec08131a),
      child: Center(
        child: SizedBox(
          width: math.min(size.maxWidth - 32, 790),
          height: math.min(size.maxHeight - 32, 720),
          child: _panel(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _eyebrow('MỘT THỊ TRẤN LIỀN MẠCH'),
                            const SizedBox(height: 5),
                            const Text(
                              'BẢN ĐỒ TOÀN KHU VỰC',
                              style: TextStyle(
                                color: _cream,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng bản đồ',
                        onPressed: _closeMap,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: m.world.mapWidth / m.world.mapHeight,
                        child: CustomPaint(
                          key: const ValueKey('full-town-map'),
                          painter: TownRadar(m, detailed: true),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '● Bạn  ·  Xanh lam: lõi  ·  Xanh lá: chỗ ẩn  ·  Vàng: đạn  ·  Đỏ: quái',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
                  ),
                  Text(
                    'Đang ở ${m.world.locationAt(m.player)} · Thời gian tạm dừng khi xem bản đồ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  TextButton(
                    onPressed: _closeMap,
                    child: const Text('M · TRỞ LẠI THỊ TRẤN'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _bar(double value, Color color, double height) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: height,
      backgroundColor: const Color(0xff27373d),
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );

  Widget _skill(
    String keyName,
    IconData icon,
    int? count,
    double cooldown,
    VoidCallback action,
    bool compact,
  ) => _panel(
    Tooltip(
      message: keyName == 'Q'
          ? 'Đèn chớp — choáng quái'
          : keyName == 'E'
          ? 'Đặt bẫy điện'
          : 'Thay đạn',
      child: InkWell(
        onTap:
            _model?.active == true &&
                cooldown == 0 &&
                (count == null || count > 0)
            ? () => setState(action)
            : null,
        child: SizedBox(
          width: compact ? 46 : 64,
          height: compact ? 62 : 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: cooldown > 0 || count == 0 ? _muted : _gold,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                cooldown > 0
                    ? '${cooldown.ceil()}s'
                    : count == null
                    ? keyName
                    : '$keyName · $count',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pad(bool fire) {
    void update(PointerEvent e) {
      final delta = (e.localPosition - const Offset(52, 52)) / 38;
      final direction = delta.distance > 1 ? delta / delta.distance : delta;
      if (fire) {
        _touchFire = true;
        _mouseAt = null;
        final m = _model!;
        if (delta.distance > .25) {
          m.aim = m.player + TownView.movement(direction) * 400;
        } else {
          final enemies =
              m.enemies
                  .where(
                    (e) => e.alive && m.world.clearLine(m.player, e.position),
                  )
                  .toList()
                ..sort(
                  (a, b) => (a.position - m.player).distance.compareTo(
                    (b.position - m.player).distance,
                  ),
                );
          m.aim = enemies.isEmpty
              ? m.player + Offset(math.cos(m.facing), math.sin(m.facing)) * 300
              : enemies.first.position;
        }
      } else {
        _touchMove = direction;
      }
    }

    void release(PointerEvent e) {
      if (fire) {
        _touchFire = false;
      } else {
        _touchMove = Offset.zero;
      }
    }

    return Listener(
      key: ValueKey(fire ? 'town-aim' : 'town-move'),
      onPointerDown: (e) {
        if (_model!.active) update(e);
      },
      onPointerMove: (e) {
        if (_model!.active) update(e);
      },
      onPointerUp: release,
      onPointerCancel: release,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x940c1b22),
          border: Border.all(color: const Color(0x88687974)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fire ? Icons.gps_fixed : Icons.open_with,
              color: fire ? _gold : _muted,
              size: 30,
            ),
            const SizedBox(height: 7),
            Text(
              fire ? 'NGẮM / BẮN' : 'DI CHUYỂN',
              style: const TextStyle(
                color: _muted,
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(ExplorationModel m) {
    final won = m.phase == FieldPhase.won;
    final paused = m.phase == FieldPhase.paused;
    final wheel = _handInput.wheelOpen || _handInput.waitingRelease;
    return ColoredBox(
      color: const Color(0xc9050e14),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _panel(
              Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      wheel
                          ? Icons.back_hand_outlined
                          : paused
                          ? Icons.pause_circle_outline
                          : won
                          ? Icons.radar
                          : Icons.heart_broken_outlined,
                      size: 36,
                      color: won
                          ? _teal
                          : !paused
                          ? const Color(0xffdc8b75)
                          : _gold,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wheel
                          ? 'CHỌN KỸ NĂNG'
                          : paused
                          ? 'TẠM DỪNG'
                          : won
                          ? 'BẠN ĐÃ SỐNG SÓT'
                          : 'TÍN HIỆU ĐÃ MẤT',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 23,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      wheel
                          ? (_handInput.waitingRelease
                                ? 'Mở tay ổn định để trở lại ván chơi.'
                                : 'Hàng trên: đèn / ẩn / bẫy. Hạ tay để chọn đứng / ngồi / nằm. Chụm thả để chọn.')
                          : paused
                          ? (_handMode && !hand.ready
                                ? hand.statusMessage
                                : 'Thị trấn đang chờ bạn trở lại.')
                          : won
                          ? 'Bạn đã giữ được tín hiệu trong 180 giây.'
                          : m.deathReason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, height: 1.6),
                    ),
                    if (wheel) ...[
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          for (final i in [0, 2, 1])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: OutlinedButton(
                                  onPressed: _handInput.waitingRelease
                                      ? null
                                      : () => setState(
                                          () => _handInput.select(i),
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _handInput.selection == i
                                          ? _gold
                                          : _muted,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          i == 0
                                              ? Icons.flash_on
                                              : i == 1
                                              ? Icons.bolt
                                              : Icons.visibility_off_outlined,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          i == 0
                                              ? 'Đèn · ${m.flashes}'
                                              : i == 1
                                              ? 'Bẫy · ${m.traps}'
                                              : m.hidden
                                              ? 'Rời chỗ ẩn'
                                              : 'Ẩn nấp',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      _wheelPostures(m),
                      TextButton(
                        onPressed: () =>
                            setState(() => _handInput.select(null)),
                        child: const Text('Hủy chọn'),
                      ),
                    ] else ...[
                      if (!paused) ...[
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _menuFact(_time(m.elapsed.floor()), 'THỜI GIAN'),
                            _menuFact('${m.kills}', 'HẠ GỤC'),
                            _menuFact('${m.score}', 'ĐIỂM'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lõi tín hiệu ${m.cores}/3  ·  Chính xác ${m.shots == 0 ? 0 : (m.hits / m.shots * 100).round()}%',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                      if (paused) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _controlChoice(false),
                            _controlChoice(true),
                          ],
                        ),
                      ],
                      if (_hint.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _hint,
                            style: const TextStyle(color: _gold),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: paused
                              ? _resume
                              : () => _start(retry: !won),
                          child: Text(
                            paused
                                ? 'TIẾP TỤC'
                                : won
                                ? 'CHƠI LƯỢT MỚI'
                                : 'CHƠI LẠI MAP',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (paused)
                        TextButton(
                          onPressed: _help,
                          child: const Text('Xem cách điều khiển'),
                        ),
                      TextButton(
                        onPressed: _home,
                        child: const Text('Về trang chủ'),
                      ),
                      if (!paused && !won)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Né vòng báo đòn. Dùng đèn chớp hoặc bẫy khi bị áp sát.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              height: 1.6,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mute() {
    setState(() => settings.muted = !settings.muted);
    if (settings.muted) unawaited(audio.silenceTension());
    unawaited(audio.sync(playing: _model?.active == true));
    unawaited(_saveSettings());
  }

  Future<void> _help() async {
    if (_model?.active == true) _pause();
    await showDialog<void>(
      context: _navigator.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Sống sót trong thị trấn'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 470,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Giữ mạng sống trong 180 giây. Nhặt lõi tín hiệu để có thêm điểm; không bắt buộc để thắng.',
                  style: TextStyle(color: _cream, height: 1.6),
                ),
                const SizedBox(height: 20),
                _eyebrow('BÀN PHÍM VÀ CHUỘT'),
                const SizedBox(height: 8),
                const Text(
                  'WASD / mũi tên: đi lại\nChuột: ngắm · Giữ chuột trái hoặc F: bắn\nX: ngồi xổm / đứng · Z: nằm / đứng\nShift: chạy khi đứng · Space: lướt né\nKhi nằm: Space đứng dậy, bấm tiếp sau đó để lướt\nR: thay đạn · Q: đèn chớp · E: bẫy điện\nG: ẩn / rời chỗ ẩn · M: xem toàn thị trấn\nEsc / P: tạm dừng',
                  style: TextStyle(color: _muted, height: 1.8),
                ),
                const SizedBox(height: 20),
                _eyebrow('MỘT BÀN TAY'),
                const SizedBox(height: 8),
                const Text(
                  'Mở tay và dịch lòng bàn tay: di chuyển\nChụm ngón cái với ngón trỏ: ngắm và bắn ở mọi tư thế\nNâng nhanh bàn tay đang mở: lướt; về tâm để dùng lại\nNắm ngắn rồi mở: thay đạn\nNắm 0,8 giây: mở vòng kỹ năng\nHàng trên: trái đèn, giữa ẩn, phải bẫy\nHạ tay xuống hàng tư thế: trái đứng, giữa ngồi, phải nằm\nChụm rồi thả để chọn, mở tay để trở lại\nF1: hiệu chỉnh tay mở · F2: hiệu chỉnh chụm\nC: đặt lại tâm di chuyển\nMất tay: ván tự tạm dừng; bấm Tiếp tục để chơi lại.',
                  style: TextStyle(color: _muted, height: 1.8),
                ),
                const SizedBox(height: 20),
                _eyebrow('CẢM ỨNG'),
                const SizedBox(height: 8),
                const Text(
                  'Cần trái để đi. Kéo cần phải để ngắm và bắn. Chạm giữa cần phải để bắn quái gần nhất. Nút mũi tên giữa màn để lướt.',
                  style: TextStyle(color: _muted, height: 1.7),
                ),
                const SizedBox(height: 20),
                _eyebrow('ĐỌC ĐÒN TẤN CÔNG'),
                const SizedBox(height: 8),
                const Text(
                  'Rời vòng đỏ trước khi quái đánh. Boss có giáp; bắn lúc vòng vàng sáng để gây đủ sát thương. Quái có thể giết bạn khi máu về 0.',
                  style: TextStyle(color: _muted, height: 1.7),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _settings() async {
    await showDialog<void>(
      context: _navigator.currentContext!,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Cài đặt'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tắt âm thanh'),
                  value: settings.muted,
                  onChanged: (v) {
                    update(() => settings.muted = v);
                    unawaited(audio.sync(playing: _model?.active == true));
                  },
                ),
                const Text('Âm nền', style: TextStyle(color: _muted)),
                Slider(
                  value: settings.music,
                  onChanged: (v) {
                    update(() => settings.music = v);
                    unawaited(audio.sync(playing: _model?.active == true));
                  },
                ),
                const Text(
                  'Hiệu ứng âm thanh',
                  style: TextStyle(color: _muted),
                ),
                Slider(
                  value: settings.effects,
                  onChanged: (v) => update(() => settings.effects = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giảm hiệu ứng'),
                  subtitle: const Text('Giảm mưa, sương và nhịp cảnh báo đỏ'),
                  value: _reducedEffects,
                  onChanged: (v) {
                    update(() => _reducedEffects = v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                unawaited(_saveSettings());
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Xong'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handPreview() => _panel(
    Padding(
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ValueListenableBuilder<Uint8List?>(
              valueListenable: hand.preview,
              builder: (context, bytes, child) => bytes == null
                  ? const Center(
                      child: Icon(
                        Icons.videocam_outlined,
                        color: _muted,
                        size: 28,
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          bytes,
                          gaplessPlayback: true,
                          fit: BoxFit.contain,
                        ),
                        CustomPaint(
                          painter: HandPreviewPainter(
                            hand.latest?.points ?? [],
                            hand.pinched,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            !hand.ready
                ? hand.statusMessage
                : hand.pinched
                ? 'CHỤM: NGẮM VÀ BẮN'
                : 'TAY ĐÃ SẴN SÀNG',
            maxLines: 3,
            style: TextStyle(
              color: hand.ready ? _teal : _gold,
              fontSize: 10,
              height: 1.4,
            ),
          ),
          if (!hand.ready)
            TextButton(
              onPressed: hand.retry,
              child: const Text('Kết nối lại', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    ),
  );
  Widget _panel(Widget child) => Container(
    decoration: BoxDecoration(
      color: const Color(0xd90c1a21),
      border: Border.all(color: const Color(0x66556766)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
  Widget _eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      color: _gold,
      fontSize: 10,
      letterSpacing: 2.5,
      fontWeight: FontWeight.w600,
    ),
  );
}
