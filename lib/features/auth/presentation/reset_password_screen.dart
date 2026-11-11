import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../application/auth_controller.dart';
import 'widgets/password_rules.dart';

/// Forgot password: the email first, then the emailed code and a new
/// password. Pops `true` once signed in with the new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(ApiException e) {
    final l = context.l10n;
    return switch (e) {
      ApiException(isNetwork: true) => l.authErrorNetwork,
      ApiException(code: 'invalid_reset_code') => l.authResetErrorCode,
      ApiException(code: 'password_reset_unavailable') => l.authResetUnavailable,
      ApiException(code: 'rate_limited') => l.authErrorRateLimited,
      ApiException(code: 'validation_failed') => _codeSent ? l.authResetErrorInvalid : l.authErrorInvalid,
      _ => l.commonSomethingWrong,
    };
  }

  Future<void> _run(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = context.l10n.authErrorInvalid);
      return;
    }
    await _run(() async {
      await ref.read(authProvider.notifier).requestPasswordReset(email: _email.text);
      _code.clear();
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    final problem = !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())
        ? l.authResetErrorEnterCode
        : passwordProblem(context, _password.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _run(() async {
      await ref
          .read(authProvider.notifier)
          .resetPassword(email: _email.text, code: _code.text, newPassword: _password.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.authResetDone)));
      context.pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = context.nyaya;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xl),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.authResetTitle,
                  style: AppTheme.serif(TextStyle(fontSize: 34, height: 1.1, color: context.colors.onSurface)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _codeSent ? l.authResetSentTo(_email.text.trim()) : l.authResetSubtitle,
                style: context.text.bodyLarge?.copyWith(color: n.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_codeSent)
                TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _sendCode(),
                  decoration: InputDecoration(labelText: l.authEmail),
                )
              else ...[
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: InputDecoration(labelText: l.authResetCode, counterText: ''),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: l.authResetNewPassword,
                    suffixIcon: IconButton(
                      tooltip: l.authPassword,
                      icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                // Read out as soon as it appears.
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: n.error)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ChunkyButton(
                label: _busy ? '…' : (_codeSent ? l.authResetSave : l.authResetSend),
                onPressed: _busy ? null : (_codeSent ? _save : _sendCode),
              ),
              if (_codeSent) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: _busy ? null : _sendCode, child: Text(l.authResetResend)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
