import 'package:flutter/material.dart';
import '../survival/round_result.dart';
import 'result_journal.dart';
import 'result_widgets.dart';
import 'ui.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.records,
    required this.preview,
    this.journal,
  });
  final List<RoundResult> records;
  final bool preview;
  final ResultJournal? journal;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _filter = 0;
  String _difficulty = 'all';
  @override
  Widget build(BuildContext context) => widget.journal == null
      ? _content(context)
      : AnimatedBuilder(
          animation: widget.journal!,
          builder: (context, _) => _content(context),
        );
  Widget _content(BuildContext context) {
    final journal = widget.journal;
    final all =
        journal?.records ??
        {for (final r in widget.records) r.id: r}.values.toList();
    final records =
        all
            .where(
              (r) =>
                  (_filter == 0 || (_filter == 1 ? r.won : !r.won)) &&
                  (_difficulty == 'all' || r.difficultyKey == _difficulty),
            )
            .toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return PortalPage(
      title: 'Lịch sử sinh tồn',
      subtitle: 'Kết quả, tài nguyên và thành tích cá nhân sau mỗi lượt chơi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.preview) ...[
            note(
              'Kết quả trải nghiệm chỉ giữ trong phiên này, chưa được lưu lên tài khoản.',
              color: gold,
            ),
            const SizedBox(height: 20),
          ],
          if (journal?.historyUnavailable == true) ...[
            note(
              'Chưa tải được lịch sử từ tài khoản. Đang hiển thị những kết quả có trên thiết bị.',
              color: gold,
            ),
            const SizedBox(height: 16),
          ],
          if (journal?.cacheFailed == true) ...[
            note(
              'Chưa lưu được bản sao trên thiết bị. Hãy kiểm tra trạng thái của từng lượt và thử lưu lại.',
              color: gold,
            ),
            const SizedBox(height: 16),
          ],
          if (journal?.cacheUnreadable == true) ...[
            note(
              'Chưa đọc được bản lịch sử trên thiết bị. Đang hiển thị dữ liệu tải được từ tài khoản và các lượt trong phiên này.',
              color: gold,
            ),
            const SizedBox(height: 16),
          ],
          PersonalStatistics(records: all),
          const SizedBox(height: 26),
          const Text(
            'Các lượt đã hoàn thành',
            style: TextStyle(
              color: cream,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (journal != null && journal.canSync)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('refresh-history'),
                onPressed: journal.refreshing ? null : journal.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(
                  journal.refreshing ? 'Đang tải lịch sử…' : 'Tải lại lịch sử',
                ),
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                  label: Text(const ['Tất cả', 'Sống sót', 'Thất bại'][i]),
                  selected: _filter == i,
                  onSelected: (_) => setState(() => _filter = i),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final level in ['all', 'easy', 'normal'])
                ChoiceChip(
                  key: ValueKey('history-difficulty-$level'),
                  label: Text(
                    level == 'all'
                        ? 'Mọi độ khó'
                        : level == 'easy'
                        ? 'Dễ'
                        : 'Thường',
                  ),
                  selected: _difficulty == level,
                  onSelected: (_) => setState(() => _difficulty = level),
                ),
            ],
          ),
          if (journal != null && journal.canSync && journal.pendingCount > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('retry-all-results'),
                onPressed: journal.retryPending,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text('Thử lưu lại ${journal.pendingCount} lượt'),
              ),
            ),
          const SizedBox(height: 22),
          if (records.isEmpty)
            surface(
              Column(
                key: const ValueKey('history-empty'),
                children: [
                  const Icon(Icons.history, color: gold, size: 48),
                  const SizedBox(height: 18),
                  Text(
                    _filter == 0 && _difficulty == 'all'
                        ? 'Chưa có lượt chơi nào'
                        : 'Chưa có kết quả phù hợp',
                    style: const TextStyle(color: cream, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Hoàn thành một lượt sinh tồn để xem kết quả. Thực hành và lượt rời giữa chừng không được tính vào lịch sử.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.7),
                  ),
                ],
              ),
            ),
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: surface(
                Column(
                  key: ValueKey('history-card-${r.id}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          r.won ? 'SỐNG SÓT' : 'TÍN HIỆU ĐÃ MẤT',
                          style: TextStyle(
                            color: r.won ? teal : const Color(0xfff2a490),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          resultDate(r.playedAt),
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${r.score} điểm',
                      style: const TextStyle(
                        color: cream,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text('Sống ${resultTime(r.seconds)}'),
                        Text('Hạ ${r.kills} quái'),
                        Text('Lõi ${r.cores}/3'),
                        Text('Chính xác ${r.accuracy}%'),
                      ],
                    ),
                    const Divider(height: 30),
                    Text(
                      '${r.difficultyLabel} · ${r.controls}',
                      style: const TextStyle(color: gold, fontSize: 12),
                    ),
                    if (r.reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.reason,
                        style: const TextStyle(color: muted, height: 1.5),
                      ),
                    ],
                    if (journal != null) ...[
                      const SizedBox(height: 14),
                      ResultSaveNotice(journal: journal, resultId: r.id),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: ValueKey('result-detail-${r.id}'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RoundDetailPage(result: r, journal: journal),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('Xem chi tiết'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
