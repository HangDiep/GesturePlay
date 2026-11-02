part of 'app.dart';

extension _WaveBriefing on _DeadSignalAppState {
  void _showWavePlan() {
    final plan = SignalWaves.plan(c.difficulty, advanced: c.advanced);
    showDialog<void>(
      context: _navigator.currentContext!,
      builder: (context) => Dialog(
        child: RepaintBoundary(
          key: const ValueKey('wave-plan-preview'),
          child: SizedBox(
            width: 560,
            height: (_canvasSize.height - 100).clamp(250, 580),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: text(
                          'Kế hoạch các đợt',
                          size: 21,
                          weight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  text(
                    '${c.difficulty == SignalDifficulty.easy ? 'Mức dễ' : 'Mức thường'} · ${plan.fold<int>(0, (sum, w) => sum + w.spawns.length)} sinh vật · ${c.advanced ? 'Đủ bốn loại' : 'Luyện hai loại cơ bản'}',
                    size: 12,
                    color: signalMuted,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: plan.length,
                      separatorBuilder: (_, index) =>
                          const Divider(color: signalLine),
                      itemBuilder: (_, i) {
                        final wave = plan[i];
                        final counts = <EnemyKind, int>{};
                        for (final spawn in wave.spawns) {
                          counts.update(
                            spawn.kind,
                            (n) => n + 1,
                            ifAbsent: () => 1,
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 48,
                              child: text(
                                '${wave.at.toInt() ~/ 60}:${(wave.at.toInt() % 60).toString().padLeft(2, '0')}',
                                size: 14,
                                color: signalGreen,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    text(
                                      'Đợt ${i + 1} · ${wave.title}',
                                      size: 13,
                                      weight: FontWeight.w600,
                                    ),
                                    const SizedBox(height: 4),
                                    text(
                                      counts.entries
                                          .map(
                                            (entry) =>
                                                '${entry.value} ${entry.key.label.toLowerCase()}',
                                          )
                                          .join(' + '),
                                      size: 11,
                                      color: signalMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (c.advanced)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: text(
                        'Boss: chờ đòn đánh mạnh, rồi bắn vào điểm yếu đang phát sáng. Đèn và bẫy có thể ngắt đòn đang nạp.',
                        size: 11,
                        color: signalAmber,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
