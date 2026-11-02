import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ViewFocusEvent, ViewFocusState;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../services/hand_bridge.dart';
import '../dead_signal/audio.dart';
import '../dead_signal/settings.dart';
import '../dead_signal/hand_preview.dart';
import 'hand_input.dart';
import 'model.dart';
import 'painter.dart';
import 'world.dart';

const fieldBackground = Color(0xff101e26),
    fieldPanel = Color(0xff182b34),
    fieldText = Color(0xffe5eeea),
    fieldMuted = Color(0xff9badae),
    fieldAccent = Color(0xffb4d3a5);

class ExplorationApp extends StatefulWidget {
  const ExplorationApp({
    super.key,
    this.bridge,
    this.settings,
    this.audioEnabled = true,
  });
  final HandBridge? bridge;
  final SignalSettings? settings;
  final bool audioEnabled;
  @override
  State<ExplorationApp> createState() => _ExplorationAppState();
}

class _ExplorationAppState extends State<ExplorationApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final HandBridge hand;
  late final SignalSettings settings;
  late final SignalAudio audio;
  late final Ticker ticker;
  final handInput = FieldHandInput();
  final _sceneKey = GlobalKey();
  final _previews = {
    for (final map in FieldMap.values) map: ExplorationModel(map),
  };
  FieldMap selected = FieldMap.forest;
  ExplorationModel? model;
  bool inGame = false,
      handControl = false,
      _mouseFiring = false,
      _touchFiring = false,
      _music = false;
  Offset _touchMove = Offset.zero;
  Offset? _mouseAt;
  Duration _last = Duration.zero;
  int _soundSerial = 0;
  String _menuMessage = '';

  @override
  void initState() {
    super.initState();
    hand = widget.bridge ?? HandBridge();
    settings = widget.settings ?? SignalSettings();
    audio = SignalAudio(settings, enabled: widget.audioEnabled);
    hand.addListener(_handChanged);
    ticker = createTicker(_tick)..start();
    HardwareKeyboard.instance.addHandler(_key);
    WidgetsBinding.instance.addObserver(this);
    if (widget.settings == null) unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      await settings.load();
    } on Object {
      /* Session defaults remain usable. */
    }
    if (!mounted) return;
    hand.cameraIndex = settings.cameraIndex;
    hand.backend = settings.backend;
    setState(() {});
  }

  void _handChanged() {
    if (mounted && handControl) setState(() {});
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1000000).clamp(0.0, .1);
    _last = elapsed;
    final m = model;
    if (inGame && m != null) {
      if (m.active) {
        if (handControl) {
          handInput.apply(m, hand);
        } else {
          final keys = HardwareKeyboard.instance.logicalKeysPressed;
          bool down(LogicalKeyboardKey key) => keys.contains(key);
          m.movement =
              Offset(
                (down(LogicalKeyboardKey.keyD) ||
                            down(LogicalKeyboardKey.arrowRight)
                        ? 1
                        : 0) -
                    (down(LogicalKeyboardKey.keyA) ||
                                down(LogicalKeyboardKey.arrowLeft)
                            ? 1
                            : 0)
                        .toDouble(),
                (down(LogicalKeyboardKey.keyS) ||
                            down(LogicalKeyboardKey.arrowDown)
                        ? 1
                        : 0) -
                    (down(LogicalKeyboardKey.keyW) ||
                                down(LogicalKeyboardKey.arrowUp)
                            ? 1
                            : 0)
                        .toDouble(),
              ) +
              _touchMove;
          m.sprinting =
              down(LogicalKeyboardKey.shiftLeft) ||
              down(LogicalKeyboardKey.shiftRight);
          m.firing =
              _mouseFiring || _touchFiring || down(LogicalKeyboardKey.keyF);
          final scene =
              _sceneKey.currentContext?.findRenderObject() as RenderBox?;
          if (_mouseAt != null && scene != null && scene.hasSize) {
            m.aim = FieldViewport(m.player, scene.size).unproject(_mouseAt!);
          } else if (!_touchFiring) {
            m.aim =
                m.player + Offset(math.cos(m.facing), math.sin(m.facing)) * 300;
          }
        }
        m.update(dt);
        final scene =
            _sceneKey.currentContext?.findRenderObject() as RenderBox?;
        if (!handControl &&
            _mouseAt != null &&
            scene != null &&
            scene.hasSize) {
          m.aim = FieldViewport(m.player, scene.size).unproject(_mouseAt!);
        }
      }
      if (m.soundSerial != _soundSerial) {
        _soundSerial = m.soundSerial;
        audio.play(m.sound);
      }
      setState(() {});
    }
    final playing = inGame && m?.active == true;
    if (_music != playing) {
      _music = playing;
      unawaited(audio.sync(playing: playing));
    }
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (handControl && key == LogicalKeyboardKey.f1) {
      hand.calibrateOpen();
      return true;
    }
    if (handControl && key == LogicalKeyboardKey.f2) {
      hand.calibrateClosed();
      return true;
    }
    if (handControl && key == LogicalKeyboardKey.keyC) {
      handInput.reset();
      return true;
    }
    final m = model;
    if (!inGame || m == null) return false;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (m.active) {
        _pause();
      } else if (m.phase == FieldPhase.paused) {
        _resume();
      }
      return true;
    }
    if (!m.active) return false;
    if (key == LogicalKeyboardKey.keyR) {
      m.reload();
      return true;
    }
    if (key == LogicalKeyboardKey.keyQ) {
      m.flash();
      return true;
    }
    if (key == LogicalKeyboardKey.keyE) {
      m.trap();
      return true;
    }
    if (key == LogicalKeyboardKey.space) {
      m.roll();
      return true;
    }
    return false;
  }

  void _setHand(bool value) {
    setState(() {
      handControl = value;
      _menuMessage = '';
      handInput.reset();
    });
    if (value) {
      unawaited(hand.start());
      hand.setPreview(true);
    } else {
      hand.stop();
    }
  }

  void _start() {
    if (handControl && (!hand.ready || !hand.released)) {
      setState(
        () => _menuMessage =
            'Chờ nhận diện sẵn sàng và mở tay rõ trong webcam trước khi vào bản đồ.',
      );
      return;
    }
    setState(() {
      model = ExplorationModel(
        selected,
        seed: DateTime.now().millisecondsSinceEpoch,
      )..start();
      inGame = true;
      _soundSerial = 0;
      _clearInput();
      handInput.reset();
    });
  }

  void _clearInput() {
    _mouseAt = null;
    _mouseFiring = _touchFiring = false;
    _touchMove = Offset.zero;
    model?.firing = false;
    model?.movement = Offset.zero;
  }

  void _pause() {
    setState(() {
      model?.pause();
      _clearInput();
    });
  }

  void _resume() {
    if (handControl && (!hand.ready || !hand.released)) return;
    setState(() {
      _clearInput();
      model?.resume();
    });
  }

  void _back() {
    setState(() {
      _clearInput();
      inGame = false;
      model = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && model?.active == true) _pause();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (event.state == ViewFocusState.unfocused && model?.active == true) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_key);
    ticker.dispose();
    hand.removeListener(_handChanged);
    hand.stop();
    if (widget.bridge == null) hand.dispose();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GesturePlay — DEAD SIGNAL 2D',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: fieldBackground,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.dark(
        primary: fieldAccent,
        surface: fieldPanel,
      ),
      useMaterial3: true,
    ),
    home: Scaffold(
      body: SafeArea(
        child: RepaintBoundary(
          key: const ValueKey('exploration-canvas'),
          child: ColoredBox(
            color: fieldBackground,
            child: inGame ? _game() : _menu(),
          ),
        ),
      ),
    ),
  );

  Widget _menu() => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 900;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GESTUREPLAY / SINH TỒN 2D',
                            style: TextStyle(
                              color: fieldAccent,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'DEAD SIGNAL',
                            style: TextStyle(
                              fontSize: wide ? 42 : 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: settings.muted ? 'Bật âm thanh' : 'Tắt âm thanh',
                      onPressed: () {
                        setState(() => settings.muted = !settings.muted);
                        unawaited(settings.save());
                        unawaited(audio.sync(playing: false));
                      },
                      icon: Icon(
                        settings.muted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Điều khiển nhân vật, khám phá bản đồ và tìm đường trở về.',
                  style: TextStyle(color: fieldMuted, fontSize: 15),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: wide
                      ? 4
                      : size.maxWidth > 540
                      ? 2
                      : 1,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: wide
                      ? .88
                      : size.maxWidth > 540
                      ? 1.5
                      : 1.65,
                  children: [for (final id in FieldMap.values) _mapCard(id)],
                ),
                const SizedBox(height: 22),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Điều khiển bằng bàn tay'),
                        subtitle: const Text(
                          'Mở tay để đi • chụm để ngắm/bắn • nắm để thay đạn',
                          style: TextStyle(fontSize: 12, color: fieldMuted),
                        ),
                        value: handControl,
                        onChanged: _setHand,
                      ),
                      if (handControl) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            _preview(const Size(208, 156)),
                            SizedBox(
                              width: math.min(size.maxWidth - 80, 560),
                              child: _handHelp(),
                            ),
                          ],
                        ),
                      ],
                      if (_menuMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _menuMessage,
                            style: const TextStyle(color: Color(0xffecc698)),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 20,
                        runSpacing: 16,
                        children: [
                          const Text(
                            'Tìm 3 lõi • Sống sót 3 phút • Trở về cứu hộ\nWASD đi • Chuột ngắm/bắn • Q đèn • E bẫy',
                            style: TextStyle(
                              color: fieldMuted,
                              height: 1.6,
                              fontSize: 12,
                            ),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('start-exploration'),
                            onPressed: _start,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text('Vào bản đồ'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _mapCard(FieldMap id) {
    final preview = _previews[id]!, picked = selected == id;
    return InkWell(
      key: ValueKey('map-${id.name}'),
      onTap: () => setState(() {
        selected = id;
        _menuMessage = '';
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: picked ? const Color(0xff243b3d) : fieldPanel,
          border: Border.all(
            color: picked ? preview.world.accent : const Color(0xff31454d),
            width: picked ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: ExplorationPainter(
                      preview,
                      overview: true,
                      reticle: false,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _badge('0${id.index + 1}', preview.world.accent),
                  ),
                  if (picked)
                    const Positioned(
                      top: 9,
                      right: 9,
                      child: Icon(
                        Icons.check_circle,
                        size: 21,
                        color: fieldAccent,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.world.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: picked ? preview.world.accent : fieldText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Text(
                        preview.world.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: fieldMuted,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _game() {
    final m = model!;
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 900;
        final smallHeight = bounds.maxHeight < 480;
        return Column(
          children: [
            _header(m, compact),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, viewport) => MouseRegion(
                        onHover: (event) =>
                            _aimAt(event.localPosition, viewport.biggest),
                        onExit: (_) {
                          _mouseFiring = false;
                        },
                        cursor: SystemMouseCursors.precise,
                        child: Listener(
                          onPointerDown: (e) {
                            _aimAt(e.localPosition, viewport.biggest);
                            if (e.kind == PointerDeviceKind.mouse &&
                                e.buttons & kPrimaryButton != 0) {
                              _mouseFiring = true;
                              if (!handControl) m.shoot(m.aim);
                            }
                          },
                          onPointerMove: (e) =>
                              _aimAt(e.localPosition, viewport.biggest),
                          onPointerUp: (_) => _mouseFiring = false,
                          onPointerCancel: (_) => _mouseFiring = false,
                          child: CustomPaint(
                            key: _sceneKey,
                            painter: ExplorationPainter(m),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: IgnorePointer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: smallHeight ? 104 : 164,
                            height: smallHeight ? 85 : 134,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xff748c86),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CustomPaint(painter: FieldMinimap(m)),
                          ),
                          if (!smallHeight)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                '● Lõi tín hiệu    ◯ Cứu hộ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: fieldText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (m.messageFor > 0 || m.cores == 3)
                    Positioned(
                      top: 12,
                      left: smallHeight ? 140 : 200,
                      right: handControl && !smallHeight ? 200 : 14,
                      child: IgnorePointer(
                        child: Center(
                          child: _panel(
                            Text(
                              m.messageFor > 0 ? m.message : m.objective,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            padding: 9,
                          ),
                        ),
                      ),
                    ),
                  if (handControl && !smallHeight)
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _preview(const Size(164, 123)),
                    ),
                  if (compact) ...[
                    Positioned(left: 20, bottom: 14, child: _movementPad()),
                    Positioned(right: 20, bottom: 14, child: _firePad()),
                  ],
                  if (!m.active)
                    Positioned.fill(child: _pauseOverlay(m, compact)),
                ],
              ),
            ),
            _toolbar(m, compact),
          ],
        );
      },
    );
  }

  Widget _header(ExplorationModel m, bool compact) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 12 : 22,
      vertical: compact ? 8 : 12,
    ),
    decoration: const BoxDecoration(
      color: fieldPanel,
      border: Border(bottom: BorderSide(color: Color(0xff31454d))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '0${selected.index + 1} / ${m.world.title.toUpperCase()}',
                style: TextStyle(
                  fontSize: compact ? 12 : 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 13,
                runSpacing: 3,
                children: [
                  Text(
                    'LÕI ${m.cores}/3',
                    style: const TextStyle(
                      color: Color(0xffefd39b),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'ĐỢT ${m.wave}/5  •  HẠ ${m.kills}',
                    style: const TextStyle(color: fieldMuted, fontSize: 11),
                  ),
                  Text(
                    'CỨU HỘ ${(m.rescueIn.ceil() ~/ 60).toString().padLeft(2, '0')}:${(m.rescueIn.ceil() % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: fieldMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          width: compact ? 98 : 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _meter(
                'MÁU ${m.health.ceil()}',
                m.health / 100,
                const Color(0xffd79581),
              ),
              const SizedBox(height: 6),
              _meter('THỂ LỰC', m.stamina / 100, fieldAccent),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (compact)
          IconButton(
            tooltip: 'Tạm dừng',
            onPressed: m.active ? _pause : null,
            icon: const Icon(Icons.pause),
          )
        else
          OutlinedButton.icon(
            onPressed: m.active ? _pause : null,
            icon: const Icon(Icons.pause, size: 17),
            label: const Text('Tạm dừng'),
          ),
      ],
    ),
  );

  Widget _meter(String label, double value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 9, color: color)),
      const SizedBox(height: 3),
      LinearProgressIndicator(
        value: value.clamp(0, 1),
        color: color,
        backgroundColor: const Color(0xff31454d),
        minHeight: 4,
        borderRadius: BorderRadius.circular(3),
      ),
    ],
  );

  Widget _toolbar(ExplorationModel m, bool compact) => Container(
    color: fieldPanel,
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 22, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            m.reloadFor > 0
                ? 'THAY ĐẠN ${m.reloadFor.toStringAsFixed(1)}s'
                : 'ĐẠN ${m.ammo} / ${m.reserve}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 14,
              color: const Color(0xffead7ac),
            ),
          ),
        ),
        _actionButton(
          compact ? 'R' : 'R · Thay đạn',
          Icons.sync,
          m.reloadFor > 0 || m.ammo == 24 || m.reserve == 0 ? null : m.reload,
        ),
        const SizedBox(width: 7),
        _actionButton(
          'Q · ${m.flashes}${m.flashCooldown > 0 ? ' (${m.flashCooldown.ceil()}s)' : ''}',
          Icons.flash_on,
          m.flashes > 0 && m.flashCooldown <= 0 ? m.flash : null,
        ),
        const SizedBox(width: 7),
        _actionButton(
          'E · ${m.traps}${m.trapCooldown > 0 ? ' (${m.trapCooldown.ceil()}s)' : ''}',
          Icons.electric_bolt,
          m.traps > 0 && m.trapCooldown <= 0 ? m.trap : null,
        ),
        if (!compact) ...[
          const SizedBox(width: 20),
          const Text(
            'WASD đi • Shift chạy • Space lướt • Chuột/F bắn',
            style: TextStyle(color: fieldMuted, fontSize: 11),
          ),
        ],
      ],
    ),
  );

  Widget _actionButton(String label, IconData icon, VoidCallback? action) =>
      OutlinedButton(
        onPressed: model?.active == true ? action : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(36, 35),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );

  Widget _pauseOverlay(ExplorationModel m, bool compact) => ColoredBox(
    color: const Color(0xa6101e26),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _panel(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m.phase == FieldPhase.paused
                      ? 'Tạm dừng'
                      : m.phase == FieldPhase.won
                      ? 'Đã sơ tán an toàn'
                      : 'Nhiệm vụ thất bại',
                  style: TextStyle(
                    fontSize: compact ? 23 : 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  m.finished
                      ? '${m.world.title} • ${m.cores}/3 lõi • ${m.kills} quái\n${m.score} điểm • ${m.elapsed.floor()} giây'
                      : handControl
                      ? hand.statusMessage
                      : 'Tiếp tục khám phá hoặc chọn bản đồ khác.',
                  style: const TextStyle(color: fieldMuted, height: 1.6),
                ),
                if (handControl)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: () => _setHand(false),
                          child: const Text('Dùng chuột / chạm'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            handInput.reset();
                            hand.calibrateOpen();
                          },
                          child: const Text('Hiệu chỉnh tay mở'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (!m.finished)
                  FilledButton(
                    onPressed: !handControl || hand.ready && hand.released
                        ? _resume
                        : null,
                    child: const Text('Tiếp tục'),
                  ),
                if (m.finished)
                  FilledButton(
                    onPressed: _start,
                    child: const Text('Chơi lại'),
                  ),
                const SizedBox(height: 9),
                OutlinedButton(
                  onPressed: _back,
                  child: const Text('Chọn bản đồ khác'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _aimAt(Offset local, Size size) {
    final m = model;
    if (m == null || !m.active || handControl) return;
    _mouseAt = local;
    m.aim = FieldViewport(m.player, size).unproject(local);
  }

  Widget _movementPad() => GestureDetector(
    key: const ValueKey('move-pad'),
    onPanStart: (e) => _movePad(e.localPosition),
    onPanUpdate: (e) => _movePad(e.localPosition),
    onPanEnd: (_) => _touchMove = Offset.zero,
    onPanCancel: () => _touchMove = Offset.zero,
    child: Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x9920353e),
        border: Border.all(color: const Color(0x997ea69d)),
      ),
      child: const Icon(Icons.open_with, size: 35, color: Color(0xaaddede7)),
    ),
  );
  void _movePad(Offset at) {
    _touchMove = (at - const Offset(46, 46)) / 34;
  }

  Widget _firePad() => GestureDetector(
    key: const ValueKey('fire-pad'),
    onPanDown: (e) {
      _touchFiring = true;
      _aimPad(e.localPosition);
      if (!handControl) model!.shoot(model!.aim);
    },
    onPanUpdate: (e) => _aimPad(e.localPosition),
    onPanEnd: (_) => _touchFiring = false,
    onPanCancel: () => _touchFiring = false,
    onTapUp: (_) => _touchFiring = false,
    child: Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xaa624b38),
        border: Border.all(color: const Color(0xffc4aa78)),
      ),
      child: const Icon(Icons.my_location, color: Color(0xfff4dbaa), size: 33),
    ),
  );
  void _aimPad(Offset at) {
    final m = model!;
    final direction = at - const Offset(41, 41);
    if (direction.distance > 8) {
      m.aim = m.player + direction / direction.distance * 350;
    } else {
      final targets =
          m.enemies
              .where((e) => e.alive && m.world.clearLine(m.player, e.position))
              .toList()
            ..sort(
              (a, b) => (a.position - m.player).distance.compareTo(
                (b.position - m.player).distance,
              ),
            );
      if (targets.isNotEmpty) m.aim = targets.first.position;
    }
  }

  Widget _handHelp() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        hand.statusMessage,
        style: const TextStyle(color: fieldAccent, fontSize: 12),
      ),
      const SizedBox(height: 9),
      const Text(
        'Giữ tay mở ở vị trí thoải mái trước khi vào game. Dịch tay để đi; chụm rồi hướng tay để ngắm/bắn. C đặt lại tâm điều khiển.',
        style: TextStyle(color: fieldMuted, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          OutlinedButton(
            onPressed: hand.calibrateOpen,
            child: const Text('F1 · Tay mở'),
          ),
          OutlinedButton(
            onPressed: hand.calibrateClosed,
            child: const Text('F2 · Tay chụm'),
          ),
          OutlinedButton(
            onPressed: () => unawaited(hand.retry()),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ],
  );
  Widget _preview(Size size) => Container(
    width: size.width,
    height: size.height,
    decoration: BoxDecoration(
      color: const Color(0xff0b171e),
      borderRadius: BorderRadius.circular(9),
    ),
    clipBehavior: Clip.antiAlias,
    child: ValueListenableBuilder(
      valueListenable: hand.preview,
      builder: (context, bytes, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)
          else
            const Center(
              child: Icon(Icons.videocam_outlined, color: fieldMuted),
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
  );
  Widget _panel(Widget child, {double padding = 18}) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: fieldPanel.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xff344b52)),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xe6162a31),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
