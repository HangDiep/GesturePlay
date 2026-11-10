import 'package:flutter/material.dart';
import '../survival/round_result.dart';
import 'models.dart';
import 'result_journal.dart';
import 'result_widgets.dart';
import 'ui.dart';
export 'history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.records,
    required this.onRename,
    this.journal,
  });
  final PlayerProfile profile;
  final List<RoundResult> records;
  final ResultJournal? journal;
  final Future<PlayerProfile> Function(String) onRename;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onRename(_name.text.trim());
      if (mounted) {
        setState(
          () => _message = widget.profile.preview
              ? 'Đã đổi tên trong phiên trải nghiệm.'
              : 'Đã cập nhật hồ sơ.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.journal != null) {
      return AnimatedBuilder(
        animation: widget.journal!,
        builder: (context, _) => _content(context, widget.journal!.records),
      );
    }
    return _content(context, widget.records);
  }

  Widget _content(BuildContext context, List<RoundResult> records) {
    return PortalPage(
      title: 'Hồ sơ người chơi',
      subtitle: 'Thông tin và thành tích của người giữ tín hiệu.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.profile.preview) ...[
            note(
              'Hồ sơ thử nghiệm. Tên và thành tích ở đây chỉ thuộc phiên trải nghiệm hiện tại.',
              color: gold,
            ),
            const SizedBox(height: 20),
          ],
          PersonalStatistics(records: records),
          const SizedBox(height: 24),
          surface(
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      color: cream,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('profile-name'),
                    controller: _name,
                    maxLength: 40,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Tên cần từ 2 đến 40 ký tự.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined, color: gold),
                    title: const Text('Email'),
                    subtitle: Text(
                      widget.profile.email.isEmpty
                          ? 'Chưa có tài khoản đăng nhập'
                          : widget.profile.email,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    note(_message!),
                  ],
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const ValueKey('profile-save'),
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.check),
                      label: Text(_busy ? 'Đang lưu…' : 'LƯU THAY ĐỔI'),
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
