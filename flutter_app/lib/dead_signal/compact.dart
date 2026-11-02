part of 'app.dart';

/// Touch-sized layout for the Android emulator and narrow browser panels.
extension _CompactSignal on _DeadSignalAppState {
  Widget _compactRoot() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Trang chủ',
                  onPressed: () => _go(SignalPage.home),
                  icon: const Icon(Icons.radar, color: signalGreen, size: 23),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      text(
                        'DEAD SIGNAL',
                        size: 14,
                        weight: FontWeight.w700,
                        spacing: 2,
                      ),
                      if (c.needsHand)
                        text(
                          _trackingLabel,
                          size: 9,
                          color: hand.valid ? signalGreen : signalAmber,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Thực hành',
                  onPressed: () => _go(SignalPage.tutorial),
                  icon: const Icon(Icons.pan_tool_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Cài đặt',
                  onPressed: () => _go(SignalPage.settings),
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (c.page) {
              SignalPage.home => _compactHome(),
              SignalPage.setup => _compactSetup(),
              SignalPage.calibration => _compactCalibration(),
              SignalPage.tutorial => _compactTutorial(),
              SignalPage.settings => _compactSettings(),
              SignalPage.game => _compactGame(),
              SignalPage.result => SingleChildScrollView(child: _result()),
            },
          ),
        ],
      ),
    ),
  );
  Widget _compactHome() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 270,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: SecurityScene(preview: true)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        signalBg.withValues(alpha: .9),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: tag('TÍN HIỆU KHẨN CẤP', color: signalAmber),
                ),
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text('DEAD SIGNAL', size: 34, weight: FontWeight.w800),
                      text(
                        '180 giây. Giữ phòng trực an toàn.',
                        size: 13,
                        color: signalGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        text(
          'Quan sát camera, quản lý điện và ngăn sinh vật xâm nhập cho đến khi cứu hộ tới.',
          size: 14,
          color: signalMuted,
        ),
        const SizedBox(height: 22),
        button(
          'Bắt đầu ca trực',
          () => c.navigate(SignalPage.setup),
          primary: true,
          icon: Icons.arrow_forward,
        ),
        const SizedBox(height: 12),
        button(
          'Hướng dẫn và thực hành',
          () => c.navigate(SignalPage.tutorial),
          icon: Icons.pan_tool_outlined,
        ),
        const SizedBox(height: 22),
        text(
          '3 camera mô phỏng  ·  2 cửa phòng thủ  ·  1 bàn tay',
          size: 12,
          color: signalMuted,
        ),
      ],
    ),
  );
  Widget _compactSetup() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Chuẩn bị ca trực', 'Sống sót 3 phút để chờ cứu hộ.'),
        _choice(
          'Dễ',
          '130 điện · 7 đợt · 12 quái',
          c.difficulty == SignalDifficulty.easy,
          () {
            c.difficulty = SignalDifficulty.easy;
            c.refresh();
          },
        ),
        const SizedBox(height: 10),
        _choice(
          'Thường',
          '100 điện · 7 đợt · 15 quái',
          c.difficulty == SignalDifficulty.normal,
          () {
            c.difficulty = SignalDifficulty.normal;
            c.refresh();
          },
        ),
        const SizedBox(height: 20),
        _choice(
          'Chuột / chạm',
          'Bắt đầu ngay',
          !c.handControl,
          () => c.setHand(false),
        ),
        const SizedBox(height: 10),
        _choice(
          'Bàn tay',
          'Kết nối webcam trên laptop',
          c.handControl,
          () => c.setHand(true),
        ),
        const SizedBox(height: 12),
        Material(
          color: signalPanel,
          child: SwitchListTile(
            title: text('Đầy đủ loại quái', size: 14),
            subtitle: text(
              'Có quái gây nhiễu và boss; tắt để luyện hai loại cơ bản.',
              size: 12,
              color: signalMuted,
            ),
            value: c.advanced,
            onChanged: (v) {
              c.advanced = v;
              c.refresh();
            },
          ),
        ),
        const SizedBox(height: 18),
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
          icon: Icons.play_arrow,
        ),
        const SizedBox(height: 18),
        text(
          'Khóa cửa tiêu hao điện liên tục. Chuyển camera để tìm quái, bật ngắm rồi chọn mục tiêu để bắn.',
          size: 13,
          color: signalMuted,
        ),
      ],
    ),
  );
  Widget _compactCalibration() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Kết nối bàn tay', 'Một bàn tay trước webcam của laptop.'),
        SizedBox(height: 190, child: _webcam()),
        const SizedBox(height: 12),
        text(hand.statusMessage, size: 13, color: signalAmber),
        const SizedBox(height: 12),
        button('1. Ghi tay mở', hand.valid ? hand.calibrateOpen : null),
        const SizedBox(height: 8),
        button('2. Ghi tay chụm', hand.valid ? hand.calibrateClosed : null),
        const SizedBox(height: 10),
        text(
          hand.latest?.text('calibration_message') ??
              'Mở ngón cái và trỏ, giữ ổn định rồi ghi lại.',
          size: 12,
          color: signalMuted,
        ),
        _sensitivity(),
        button(
          'Bắt đầu ca trực',
          hand.ready
              ? () {
                  if (c.inputReady) c.prepare();
                }
              : null,
          primary: true,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: button(
                'Thử lại',
                () => unawaited(hand.retry()),
                small: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: button('Dùng chuột / chạm', () {
                c.setHand(false);
                c.prepare();
              }, small: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
  Widget _compactSettings() => SingleChildScrollView(
    child: panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title('Cài đặt', 'Âm thanh, độ nhạy và webcam.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: text('Tắt âm thanh'),
            value: settings.muted,
            onChanged: (v) {
              settings.muted = v;
              c.refresh();
              unawaited(_saveSettings());
            },
          ),
          text('Nhạc nền', color: signalMuted),
          Slider(
            value: settings.music,
            onChanged: (v) {
              settings.music = v;
              c.refresh();
            },
            onChangeEnd: (_) => unawaited(_saveSettings()),
          ),
          text('Hiệu ứng', color: signalMuted),
          Slider(
            value: settings.effects,
            onChanged: (v) {
              settings.effects = v;
              c.refresh();
            },
            onChangeEnd: (_) => unawaited(_saveSettings()),
          ),
          _sensitivity(),
          DropdownButtonFormField<int>(
            initialValue: settings.cameraIndex,
            decoration: const InputDecoration(labelText: 'Webcam trên laptop'),
            items: List.generate(
              4,
              (i) => DropdownMenuItem(value: i, child: Text('Camera $i')),
            ),
            onChanged: (v) {
              settings.cameraIndex = v ?? 0;
              hand.cameraIndex = settings.cameraIndex;
              unawaited(_saveSettings());
              c.refresh();
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: settings.backend,
            decoration: const InputDecoration(labelText: 'Cách mở webcam'),
            items: ['dshow', 'msmf', 'auto']
                .map(
                  (v) =>
                      DropdownMenuItem(value: v, child: Text(v.toUpperCase())),
                )
                .toList(),
            onChanged: (v) {
              settings.backend = v ?? 'dshow';
              hand.backend = settings.backend;
              unawaited(_saveSettings());
              c.refresh();
            },
          ),
          const SizedBox(height: 22),
          button('Khôi phục mặc định', () {
            settings.reset();
            c.refresh();
            unawaited(_saveSettings());
          }),
          const SizedBox(height: 12),
          text(_settingsMessage, size: 12, color: signalMuted),
        ],
      ),
    ),
  );
  Widget _compactTutorial() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          'Hướng dẫn và thực hành',
          'Không tiêu hao điện và không tính điểm.',
        ),
        button(
          c.handControl ? 'Đang dùng bàn tay' : 'Dùng bàn tay',
          () => c.setHand(!c.handControl),
          icon: Icons.pan_tool_outlined,
        ),
        const SizedBox(height: 18),
        _instruction(
          Icons.near_me_outlined,
          'Di chuyển ngón trỏ',
          'Trỏ để đưa con trỏ đến thiết bị hoặc mục tiêu.',
        ),
        _instruction(
          Icons.touch_app,
          'Chụm rồi thả',
          'Chọn thiết bị hoặc bắn khi đang ngắm. Giữ chụm để kéo nguồn điện.',
        ),
        _instruction(
          Icons.back_hand_outlined,
          'Nắm tay',
          'Chọn cửa trước, sau đó nắm tay để khóa khẩn cấp.',
        ),
        button(
          c.trainingSelected ? 'Đã chọn mục tiêu ✓' : '1. Chọn mục tiêu',
          () {
            c.trainingSelected = true;
            c.refresh();
          },
          primary: true,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Draggable<String>(
              data: 'practice',
              feedback: _powerToken(),
              child: _powerToken(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DragTarget<String>(
                onWillAcceptWithDetails: (d) => d.data == 'practice',
                onAcceptWithDetails: (_) {
                  c.trainingDragged = true;
                  c.refresh();
                },
                builder: (_, items, unused) => Container(
                  height: 75,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: signalPanel,
                    border: Border.all(
                      color: items.isNotEmpty || c.trainingDragged
                          ? signalGreen
                          : signalLine,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: text(
                    c.trainingDragged
                        ? 'Đã cấp điện ✓'
                        : 'Thả nguồn điện vào đây',
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        button(c.trainingLocked ? 'Cửa mẫu đã khóa ✓' : 'Chọn cửa mẫu', () {
          c.trainingLocked = true;
          c.refresh();
        }, icon: Icons.lock_outline),
        const SizedBox(height: 12),
        button('Bắn thử (${c.practiceShots})', () {
          c.practiceShots++;
          c.refresh();
        }, icon: Icons.my_location),
        const SizedBox(height: 20),
        button(
          'Sẵn sàng nhận nhiệm vụ',
          () => c.navigate(SignalPage.setup),
          primary: true,
        ),
        const SizedBox(height: 12),
      ],
    ),
  );

  Widget _compactGame() {
    final m = c.model!;
    final time =
        '${(m.remaining.ceil() ~/ 60).toString().padLeft(2, '0')}:${(m.remaining.ceil() % 60).toString().padLeft(2, '0')}';
    if (_canvasSize.width > 650) return _compactWideGame(m, time);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: signalMuted),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text(time, size: 20, color: signalGreen),
                    text(
                      'ĐỢT ${m.wave}/${m.totalWaves}',
                      size: 9,
                      color: signalMuted,
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.bolt, size: 18, color: signalAmber),
                text(
                  '${(m.battery * 100).ceil()}%',
                  size: 18,
                  color: m.battery < .2 ? signalRed : signalGreen,
                ),
                const SizedBox(width: 14),
                button(
                  'Tạm dừng',
                  () => c.pause('Bạn đã tạm dừng.'),
                  small: true,
                  icon: Icons.pause,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 7),
                      child: button(
                        'CAM 0${i + 1}${m.sensor(i) ? ' •' : ''}',
                        () => c.action((m) => m.selectCamera(i)),
                        primary: m.camera == i,
                        small: true,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _viewport(m)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 2; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                      child: button(
                        '${i == 0 ? 'Trái' : 'Phải'}: ${m.doors[i].broken
                            ? 'Đã vỡ'
                            : m.doors[i].locked
                            ? 'Mở cửa'
                            : 'Khóa cửa'}',
                        m.doors[i].broken
                            ? null
                            : () => c.action((m) => m.toggleDoor(i)),
                        small: true,
                        icon: m.doors[i].locked
                            ? Icons.lock_outline
                            : Icons.lock_open,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: button(
                    'Thiết bị',
                    _compactDevices,
                    small: true,
                    icon: Icons.shield_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: button(
                    'Nguồn điện',
                    _compactPower,
                    small: true,
                    icon: Icons.bolt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 30,
              child: Text(
                m.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: signalAmber),
              ),
            ),
          ],
        ),
        if (m.phase == RoundPhase.paused && c.countdown == 0) _compactPause(),
        if (c.countdown > 0) _countdown(),
      ],
    );
  }

  Widget _compactWideGame(SignalModel m, String time) => Stack(
    children: [
      Column(
        children: [
          Row(
            children: [
              text(
                'CỨU HỘ $time · ĐỢT ${m.wave}/${m.totalWaves}',
                size: 17,
                color: signalGreen,
              ),
              const Spacer(),
              const Icon(Icons.bolt, size: 18, color: signalAmber),
              text(
                '${(m.battery * 100).ceil()}%',
                size: 17,
                color: signalGreen,
              ),
              const SizedBox(width: 15),
              button(
                'Tạm dừng',
                () => c.pause('Bạn đã tạm dừng.'),
                small: true,
                icon: Icons.pause,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                                child: button(
                                  'CAM 0${i + 1}${m.sensor(i) ? ' •' : ''}',
                                  () => c.action((m) => m.selectCamera(i)),
                                  primary: m.camera == i,
                                  small: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(child: _viewport(m)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 205,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < 2; i++) ...[
                        button(
                          '${i == 0 ? 'Trái' : 'Phải'}: ${m.doors[i].broken
                              ? 'Đã vỡ'
                              : m.doors[i].locked
                              ? 'Mở cửa'
                              : 'Khóa cửa'}',
                          m.doors[i].broken
                              ? null
                              : () => c.action((m) => m.toggleDoor(i)),
                          small: true,
                          icon: m.doors[i].locked
                              ? Icons.lock_outline
                              : Icons.lock_open,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: LinearProgressIndicator(
                            value: (m.doors[i].health / m.doors[i].maxHealth)
                                .clamp(0, 1),
                            minHeight: 3,
                            color: signalGreen,
                            backgroundColor: signalLine,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      button(
                        'Thiết bị',
                        _compactDevices,
                        small: true,
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 6),
                      button(
                        'Nguồn điện',
                        _compactPower,
                        small: true,
                        icon: Icons.bolt,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          m.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: signalAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (m.phase == RoundPhase.paused && c.countdown == 0) _compactPause(),
      if (c.countdown > 0) _countdown(),
    ],
  );

  Widget _compactPause() => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: .9),
      child: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: panel(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text(
                    'Ca trực đã tạm dừng',
                    size: 21,
                    weight: FontWeight.w600,
                  ),
                  const SizedBox(height: 8),
                  text(c.pauseReason, size: 12, color: signalMuted),
                  if (c.handControl)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: text(
                        hand.ready
                            ? 'Mở tay rồi chọn Tiếp tục.'
                            : 'Đưa tay vào webcam hoặc chuyển sang chạm.',
                        size: 12,
                        color: signalAmber,
                      ),
                    ),
                  const SizedBox(height: 14),
                  button(
                    'Tiếp tục',
                    !c.focused || (c.handControl && !hand.ready)
                        ? null
                        : c.resume,
                    primary: true,
                    small: true,
                  ),
                  const SizedBox(height: 8),
                  button(
                    c.handControl
                        ? 'Chuyển sang chuột / chạm'
                        : 'Chuyển sang bàn tay',
                    () => c.setHand(!c.handControl),
                    small: true,
                  ),
                  const SizedBox(height: 8),
                  button(
                    'Rời ca trực',
                    () => unawaited(_leave(SignalPage.home)),
                    small: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  void _compactDevices() {
    showDialog<void>(
      context: _navigator.currentContext!,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 340,
          height: (_canvasSize.height - 100).clamp(250, 650),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(child: text('PHÒNG THỦ CHIẾN THUẬT', size: 12)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: 620,
                    child: AnimatedBuilder(
                      animation: c,
                      builder: (_, unused) => Column(
                        children: [
                          SizedBox(height: 160, child: _map(c.model!)),
                          const SizedBox(height: 8),
                          Expanded(child: _defenses(c.model!)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _compactPower() {
    showDialog<void>(
      context: _navigator.currentContext!,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, unused) {
                final m = c.model!;
                return panel(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: text('PHÂN BỔ ĐIỆN', size: 13)),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      for (var i = 0; i < 3; i++)
                        SwitchListTile(
                          title: Text('CAM 0${i + 1}'),
                          value: m.cameraPower[i],
                          onChanged: (v) =>
                              c.action((m) => m.power('camera$i', v)),
                        ),
                      for (var i = 0; i < 2; i++)
                        SwitchListTile(
                          title: Text(i == 0 ? 'Cửa trái' : 'Cửa phải'),
                          value: m.doors[i].powered,
                          onChanged: (v) =>
                              c.action((m) => m.power('door$i', v)),
                        ),
                      SwitchListTile(
                        title: const Text('Súng'),
                        value: m.gunPowered,
                        onChanged: (v) => c.action((m) => m.power('gun', v)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
