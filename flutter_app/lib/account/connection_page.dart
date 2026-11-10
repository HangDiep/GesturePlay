import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../dead_signal/settings.dart';
import '../services/hand_bridge.dart';
import '../survival/hand_preview.dart';
import 'ui.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key, required this.hand, required this.settings});
  final HandBridge hand;
  final SignalSettings settings;
  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  late final _camera = TextEditingController(
    text: '${widget.settings.cameraIndex}',
  );
  late String _backend = widget.settings.backend;
  late bool _two = widget.settings.controlMode != 'oneHand';
  bool _busy = false;
  String? _message;
  final _centers = <String, Offset>{};
  HandBridge get hand => widget.hand;
  SignalSettings get settings => widget.settings;
  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final index = int.tryParse(_camera.text);
    if (index == null || index < 0 || index > 20) {
      setState(() => _message = 'Chọn chỉ số camera từ 0 đến 20.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      settings.cameraIndex = index;
      settings.backend = _backend;
      settings.controlMode = _two ? 'twoHands' : 'oneHand';
      if (index != hand.cameraIndex || _backend != hand.backend) {
        await hand.configure(index, _backend);
      } else {
        await hand.start();
      }
      hand.setPreview(true);
      await settings.save();
    } catch (e) {
      if (mounted) {
        setState(
          () => _message =
              'Chưa kết nối được webcam. Kiểm tra phần nhận diện rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    try {
      await settings.save();
      if (mounted) setState(() => _message = 'Đã lưu thiết lập trên thiết bị.');
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = 'Chưa lưu được thiết lập. Bạn có thể thử lại.',
        );
      }
    }
  }

  Widget _status(String title, String value, bool ok) => Chip(
    avatar: Icon(
      ok ? Icons.check_circle : Icons.radio_button_unchecked,
      color: ok ? teal : gold,
      size: 17,
    ),
    label: Text('$title: $value', style: const TextStyle(fontSize: 12)),
  );
  @override
  Widget build(BuildContext context) => PortalPage(
    title: 'Kết nối & hiệu chỉnh',
    subtitle:
        'Kiểm tra webcam và cử chỉ trước khi vào thị trấn. Camera chỉ được mở khi bạn chọn kết nối hoặc chế độ điều khiển tay.',
    child: AnimatedBuilder(
      animation: hand,
      builder: (context, _) {
        final packet = hand.latest;
        final camera = packet?.text('camera_phase') ?? 'stopped';
        final tracker = packet?.text('tracker_phase') ?? 'stopped';
        final ready = _two ? hand.twoHandsReady : hand.ready;
        final preview = surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'WEBCAM',
                style: TextStyle(
                  color: gold,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: night,
                    child: ValueListenableBuilder<Uint8List?>(
                      valueListenable: hand.preview,
                      builder: (context, bytes, _) => bytes == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.videocam_off_outlined,
                                    color: muted,
                                    size: 44,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Chưa có hình webcam',
                                    style: TextStyle(color: muted),
                                  ),
                                ],
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
                                  painter: TownHandsPreviewPainter(
                                    packet,
                                    swap: settings.swapHands,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hand.statusMessage,
                key: const ValueKey('connection-status'),
                style: const TextStyle(color: muted, height: 1.6, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _status(
                    'Dịch vụ',
                    hand.connected ? 'Đã kết nối' : 'Chưa kết nối',
                    hand.connected,
                  ),
                  _status(
                    'Camera',
                    camera == 'running'
                        ? 'Đang hoạt động'
                        : camera == 'error'
                        ? 'Không truy cập được'
                        : camera == 'starting'
                        ? 'Đang mở'
                        : 'Chưa bật',
                    camera == 'running',
                  ),
                  _status(
                    'Nhận diện',
                    tracker == 'running'
                        ? 'Sẵn sàng'
                        : tracker == 'error'
                        ? 'Có lỗi'
                        : 'Đang chờ',
                    tracker == 'running',
                  ),
                  _status(
                    'Tay trái',
                    hand.handReady('left') ? 'Sẵn sàng' : 'Chưa thấy rõ',
                    hand.handReady('left'),
                  ),
                  _status(
                    'Tay phải',
                    hand.handReady('right') ? 'Sẵn sàng' : 'Chưa thấy rõ',
                    hand.handReady('right'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Camera ${packet?.number('camera_fps')?.toStringAsFixed(0) ?? '—'} FPS · Nhận diện ${packet?.number('result_fps')?.toStringAsFixed(0) ?? '—'} FPS',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        );
        final controls = surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chuẩn bị điều khiển',
                style: TextStyle(
                  color: cream,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Một tay'),
                    selected: !_two,
                    onSelected: (_) => setState(() => _two = false),
                  ),
                  ChoiceChip(
                    label: const Text('Hai tay'),
                    selected: _two,
                    onSelected: (_) => setState(() => _two = true),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('camera-index'),
                controller: _camera,
                keyboardType: TextInputType.number,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Chỉ số webcam',
                  helperText: 'Thường là 0; thử 1 nếu dùng camera ngoài.',
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _backend,
                decoration: const InputDecoration(labelText: 'Cách mở camera'),
                items: const [
                  DropdownMenuItem(value: 'dshow', child: Text('DirectShow')),
                  DropdownMenuItem(
                    value: 'msmf',
                    child: Text('Media Foundation'),
                  ),
                  DropdownMenuItem(value: 'auto', child: Text('Tự động')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _backend = v ?? 'dshow'),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('connection-connect'),
                    onPressed: _busy ? null : _connect,
                    icon: const Icon(Icons.link),
                    label: Text(_busy ? 'Đang kết nối…' : 'KẾT NỐI'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('connection-retry'),
                    onPressed: _busy
                        ? null
                        : () async {
                            await hand.retry();
                            hand.setPreview(true);
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kết nối lại'),
                  ),
                  TextButton(
                    onPressed: hand.connected
                        ? () {
                            hand.stop();
                            setState(
                              () => _message = 'Đã ngắt kết nối camera.',
                            );
                          }
                        : null,
                    child: const Text('Ngắt kết nối'),
                  ),
                ],
              ),
              const Divider(height: 36),
              Text(
                'Độ nhạy con trỏ ${settings.sensitivity.toStringAsFixed(1)}×',
                style: const TextStyle(color: cream),
              ),
              Slider(
                key: const ValueKey('pointer-sensitivity'),
                value: settings.sensitivity,
                min: .5,
                max: 2,
                divisions: 15,
                onChanged: (v) => setState(() => settings.sensitivity = v),
                onChangeEnd: (_) => _save(),
              ),
              Text(
                'Độ nhạy di chuyển ${settings.movementSensitivity.toStringAsFixed(1)}×',
                style: const TextStyle(color: cream),
              ),
              Slider(
                key: const ValueKey('movement-sensitivity'),
                value: settings.movementSensitivity,
                min: .5,
                max: 2,
                divisions: 15,
                onChanged: (v) =>
                    setState(() => settings.movementSensitivity = v),
                onChangeEnd: (_) => _save(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đổi vai hai tay'),
                subtitle: const Text('Tay phải đi, tay trái ngắm'),
                value: settings.swapHands,
                onChanged: (v) {
                  setState(() => settings.swapHands = v);
                  _save();
                },
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) => box.maxWidth > 760
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: preview),
                        const SizedBox(width: 20),
                        Expanded(child: controls),
                      ],
                    )
                  : Column(
                      children: [preview, const SizedBox(height: 20), controls],
                    ),
            ),
            const SizedBox(height: 20),
            surface(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Vị trí điều khiển & hiệu chỉnh',
                    style: TextStyle(
                      color: cream,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Mở tay ở tư thế thoải mái rồi đặt lại tâm. Dịch tay để kiểm tra dấu điều khiển bên dưới.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 220,
                    child: CustomPaint(
                      key: const ValueKey('connection-cursor'),
                      painter: _CursorPainter(
                        hand,
                        _centers,
                        settings.sensitivity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: ready
                            ? () {
                                setState(() {
                                  for (final side in ['left', 'right']) {
                                    final p = hand.latest?.hand(side)?.palm;
                                    if (p != null) _centers[side] = p;
                                  }
                                });
                              }
                            : null,
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Đặt lại tâm'),
                      ),
                      FilledButton.tonal(
                        onPressed: ready
                            ? () => hand.calibrateOpen(both: _two)
                            : null,
                        child: const Text('1. Ghi tay mở'),
                      ),
                      FilledButton.tonal(
                        onPressed: ready
                            ? () => hand.calibrateClosed(both: _two)
                            : null,
                        child: const Text('2. Ghi tay chụm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final side in _two ? ['left', 'right'] : ['primary'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${side == 'primary'
                            ? 'Một tay'
                            : side == 'left'
                            ? 'Tay trái'
                            : 'Tay phải'}: ${(side == 'primary' ? packet : packet?.hand(side))?.text('calibration_message') ?? 'Giữ tay rõ và ổn định để hiệu chỉnh.'}',
                        style: const TextStyle(
                          color: teal,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    note(_message!),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _CursorPainter extends CustomPainter {
  _CursorPainter(this.hand, this.centers, this.sensitivity);
  final HandBridge hand;
  final Map<String, Offset> centers;
  final double sensitivity;
  @override
  void paint(Canvas c, Size size) {
    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = night,
    );
    for (var i = 1; i < 4; i++) {
      c.drawLine(
        Offset(size.width * i / 4, 0),
        Offset(size.width * i / 4, size.height),
        Paint()..color = const Color(0xff253d47),
      );
      c.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        Paint()..color = const Color(0xff253d47),
      );
    }
    c.drawCircle(
      size.center(Offset.zero),
      22,
      Paint()
        ..color = gold.withValues(alpha: .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final side in ['left', 'right']) {
      final h = hand.latest?.hand(side);
      if (!hand.handReady(side) || h?.palm == null) continue;
      final delta =
          h!.palm! - (centers[side] ?? Offset(side == 'left' ? .25 : .75, .5));
      final p = Offset(
        (.5 + delta.dx * sensitivity / .5).clamp(0, 1) * size.width,
        (.5 + delta.dy * sensitivity / .5).clamp(0, 1) * size.height,
      );
      final color = side == 'left' ? teal : gold;
      c.drawCircle(p, 12, Paint()..color = color.withValues(alpha: .25));
      c.drawCircle(p, 5, Paint()..color = color);
      final t = TextPainter(
        text: TextSpan(
          text: side == 'left' ? 'TRÁI' : 'PHẢI',
          style: TextStyle(color: color, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(
        c,
        Offset(
          (p.dx + 12).clamp(0, size.width - t.width),
          (p.dy - 20).clamp(0, size.height - t.height),
        ),
      );
      t.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) => true;
}
