import 'package:flutter/material.dart';
import 'models.dart';
import 'ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.gateway,
    required this.onAuthenticated,
    required this.onPreview,
  });
  final AccountGateway gateway;
  final Future<void> Function(PlayerProfile) onAuthenticated;
  final Future<void> Function() onPreview;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _register = false, _hidden = true, _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final player = _register
          ? await widget.gateway.signUp(
              _name.text.trim(),
              _email.text.trim(),
              _password.text,
            )
          : await widget.gateway.signIn(_email.text.trim(), _password.text);
      await widget.onAuthenticated(player);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onPreview();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Không mở được giao diện. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/town/ground-v2.png',
            fit: BoxFit.cover,
            color: const Color(0xff18323b),
            colorBlendMode: BlendMode.modulate,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  night.withValues(alpha: .9),
                  night.withValues(alpha: .55),
                  night.withValues(alpha: .9),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 960;
              final brand = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar, color: gold),
                      SizedBox(width: 10),
                      Text(
                        'GESTUREPLAY',
                        style: TextStyle(
                          color: cream,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 64 : 20),
                  Text(
                    wide ? 'DEAD\nSIGNAL' : 'DEAD SIGNAL',
                    style: TextStyle(
                      fontSize: wide ? 86 : 36,
                      height: .95,
                      letterSpacing: wide ? 6 : 2,
                      fontWeight: FontWeight.w900,
                      color: cream,
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Giữ lấy tín hiệu.\nTìm đường sống giữa thị trấn im lặng.',
                      style: TextStyle(color: muted, fontSize: 16, height: 1.8),
                    ),
                    const SizedBox(height: 28),
                    const Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('01 BẢN ĐỒ')),
                        Chip(label: Text('03:00 SINH TỒN')),
                        Chip(label: Text('ĐIỀU KHIỂN BẰNG TAY')),
                      ],
                    ),
                  ],
                ],
              );
              final card = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: surface(
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                          style: const TextStyle(
                            color: cream,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _register
                              ? 'Chuẩn bị hồ sơ người giữ tín hiệu của bạn.'
                              : 'Đăng nhập để tiếp tục hành trình.',
                          style: const TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        if (!widget.gateway.configured) ...[
                          note(
                            'Giao diện đang ở chế độ trải nghiệm. Kết nối dữ liệu tài khoản sẽ được bổ sung sau.',
                            icon: Icons.cloud_off_outlined,
                            color: gold,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_register) ...[
                          TextFormField(
                            key: const ValueKey('auth-name'),
                            controller: _name,
                            maxLength: 40,
                            enabled: !_busy,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v?.trim().length ?? 0) < 2
                                ? 'Nhập tên từ 2 đến 40 ký tự.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          key: const ValueKey('auth-email'),
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) =>
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Nhập email hợp lệ.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('auth-password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _hidden,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: _register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_register) _submit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hidden
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => (v?.length ?? 0) < 8
                              ? 'Mật khẩu cần ít nhất 8 ký tự.'
                              : null,
                        ),
                        if (_register) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('auth-confirm'),
                            controller: _confirm,
                            enabled: !_busy,
                            obscureText: _hidden,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Xác nhận mật khẩu',
                              prefixIcon: Icon(Icons.lock_reset),
                            ),
                            validator: (v) => v != _password.text
                                ? 'Mật khẩu xác nhận chưa khớp.'
                                : null,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          note(
                            _error!,
                            color: const Color(0xfff6a391),
                            icon: Icons.error_outline,
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey('auth-submit'),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          key: const ValueKey('auth-toggle'),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _register = !_register;
                                  _error = null;
                                  _form.currentState?.reset();
                                }),
                          child: Text(
                            _register
                                ? 'Đã có tài khoản? Đăng nhập'
                                : 'Chưa có tài khoản? Đăng ký',
                          ),
                        ),
                        const Divider(height: 28, color: Color(0xff304954)),
                        OutlinedButton.icon(
                          key: const ValueKey('auth-preview'),
                          onPressed: _busy ? null : _preview,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('TRẢI NGHIỆM GIAO DIỆN'),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Chế độ trải nghiệm không tạo tài khoản. Kết quả thử chỉ giữ trong phiên hiện tại.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 48 : 22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: brand),
                              const SizedBox(width: 60),
                              Expanded(child: card),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              brand,
                              const SizedBox(height: 30),
                              Center(child: card),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
