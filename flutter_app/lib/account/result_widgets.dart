import 'package:flutter/material.dart';
import '../survival/round_result.dart';
import 'result_journal.dart';
import 'ui.dart';

String resultTime(double seconds) =>
    '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';
String resultDate(DateTime date) {
  final at = date.toLocal();
  return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class ResultSaveNotice extends StatelessWidget {
  const ResultSaveNotice({
    super.key,
    required this.journal,
    required this.resultId,
  });
  final ResultJournal journal;
  final String resultId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: journal,
    builder: (context, _) {
      final state =
          journal.entry(resultId)?.state ?? ResultSaveState.sessionOnly;
      final failed = state == ResultSaveState.failed;
      final color = state == ResultSaveState.saved
          ? teal
          : failed
          ? const Color(0xfff2a490)
          : gold;
      final text = switch (state) {
        ResultSaveState.sessionOnly =>
          'Chưa lưu tài khoản · Kết quả chỉ giữ trong phiên trải nghiệm.',
        ResultSaveState.pending =>
          'Chờ lưu lên tài khoản. Bạn có thể gửi lại khi có mạng.',
        ResultSaveState.saving => 'Đang lưu kết quả lên tài khoản…',
        ResultSaveState.saved => 'Đã lưu kết quả vào tài khoản.',
        ResultSaveState.failed =>
          journal.cacheFailed || journal.cacheUnreadable
              ? 'Chưa lưu được lên tài khoản và thiết bị. Hãy thử lưu lại.'
              : 'Chưa lưu được lên tài khoản. Kết quả đã giữ trên thiết bị để gửi lại.',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: ValueKey('result-save-${state.name}'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              border: Border.all(color: color.withValues(alpha: .3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state == ResultSaveState.saving)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    state == ResultSaveState.saved
                        ? Icons.cloud_done_outlined
                        : failed
                        ? Icons.cloud_off_outlined
                        : Icons.info_outline,
                    color: color,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: color, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          if (journal.canSync &&
              (failed ||
                  state == ResultSaveState.pending ||
                  journal.cacheFailed))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('retry-result-$resultId'),
                onPressed: state == ResultSaveState.saving
                    ? null
                    : () => journal.retry(resultId),
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Thử lưu lại'),
              ),
            ),
        ],
      );
    },
  );
}

class PersonalStatistics extends StatelessWidget {
  const PersonalStatistics({super.key, required this.records});
  final List<RoundResult> records;
  @override
  Widget build(BuildContext context) {
    final stats = PersonalStats(records);
    final byDifficulty = {
      for (final key in ['easy', 'normal'])
        key: PersonalStats(records, difficulty: key),
    };
    Widget cell(String value, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Text(
        value,
        style: TextStyle(
          color: header ? muted : cream,
          fontWeight: header ? FontWeight.normal : FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: statTile(
                'Lượt hoàn thành',
                '${stats.completed}',
                Icons.sports_esports_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statTile(
                'Lượt thắng',
                '${stats.wins}',
                Icons.shield_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: statTile(
                'Điểm cao nhất',
                '${stats.best}',
                Icons.emoji_events_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thành tích theo độ khó',
                style: TextStyle(
                  color: cream,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 10),
              Table(
                columnWidths: const {0: FlexColumnWidth(1.2)},
                border: const TableBorder(
                  horizontalInside: BorderSide(color: Color(0xff304954)),
                ),
                children: [
                  TableRow(
                    children: [
                      for (final label in [
                        'Độ khó',
                        'Lượt',
                        'Thắng',
                        'Cao nhất',
                      ])
                        cell(label, header: true),
                    ],
                  ),
                  for (final level in ['easy', 'normal'])
                    TableRow(
                      children: [
                        cell(level == 'easy' ? 'Dễ' : 'Thường'),
                        KeyedSubtree(
                          key: ValueKey('stats-$level-completed'),
                          child: cell('${byDifficulty[level]!.completed}'),
                        ),
                        cell('${byDifficulty[level]!.wins}'),
                        KeyedSubtree(
                          key: ValueKey('stats-$level-best'),
                          child: cell('${byDifficulty[level]!.best}'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RoundDetailPage extends StatelessWidget {
  const RoundDetailPage({super.key, required this.result, this.journal});
  final RoundResult result;
  final ResultJournal? journal;
  @override
  Widget build(BuildContext context) {
    final r = result;
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: muted)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: cream, height: 1.5),
            ),
          ),
        ],
      ),
    );
    return PortalPage(
      title: 'Chi tiết lượt chơi',
      subtitle: 'Kết quả đã chốt khi lượt sinh tồn kết thúc.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          surface(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      r.won
                          ? Icons.shield_outlined
                          : Icons.heart_broken_outlined,
                      color: r.won ? teal : gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.won ? 'SỐNG SÓT' : 'TÍN HIỆU ĐÃ MẤT',
                        style: TextStyle(
                          color: r.won ? teal : const Color(0xfff2a490),
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${r.score} điểm',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                line('Ngày chơi', resultDate(r.playedAt)),
                if (r.endedAt != null) line('Kết thúc', resultDate(r.endedAt!)),
                line('Độ khó', r.difficultyLabel),
                line('Thời gian sống sót', resultTime(r.seconds)),
                line('Điều khiển', r.controls),
                if (r.reason.isNotEmpty) line('Nguyên nhân thất bại', r.reason),
              ],
            ),
          ),
          const SizedBox(height: 20),
          surface(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chiến đấu & tài nguyên còn lại',
                  style: TextStyle(
                    color: cream,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                line('Máu', '${r.health.ceil()}/100 HP'),
                line(
                  'Súng đang dùng',
                  r.weapon.isEmpty ? 'Chưa ghi nhận' : r.weapon,
                ),
                line('Đạn trong súng', r.ammo?.toString() ?? 'Chưa ghi nhận'),
                line(
                  'Đạn dự trữ của súng',
                  r.reserve?.toString() ?? 'Chưa ghi nhận',
                ),
                line(
                  'Túi máu',
                  '${r.medkits?.toString() ?? 'Chưa ghi nhận'}${r.medkits == null ? '' : '/3'}',
                ),
                const Divider(height: 26),
                line('Quái đã hạ', '${r.kills}'),
                line('Lõi tín hiệu', '${r.cores}/3'),
                line('Phát bắn / trúng đích', '${r.shots} / ${r.hits}'),
                line('Độ chính xác', '${r.accuracy}%'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (journal != null) ...[
            ResultSaveNotice(journal: journal!, resultId: r.id),
            const SizedBox(height: 20),
          ],
          surface(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mã lượt chơi',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  r.id,
                  key: const ValueKey('round-id'),
                  style: const TextStyle(color: cream, fontSize: 12),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Gửi lại kết quả vẫn giữ mã này để không tạo thêm lượt trùng.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
