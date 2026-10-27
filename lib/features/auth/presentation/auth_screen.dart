import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chunky_button.dart';
import '../../profile/application/profile_controller.dart';
import '../application/auth_controller.dart';

/// Create an account (default) or sign in. Pops `true` once signed in, so
/// callers such as the quiz launcher can carry on.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final _name = TextEditingController(text: ref.read(profileProvider).name);
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signIn = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final email = _email.text.trim();
    final password = _password.text;
    String? problem;
    if (!_signIn && _name.text.trim().isEmpty) {
      problem = l.authErrorName;
    } else if (!email.contains('@') || password.isEmpty || (!_signIn && password.length < 8)) {
      problem = l.authErrorInvalid;
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (_signIn) {
        await auth.signIn(email: email, password: password);
      } else {
        await auth.register(name: _name.text, email: email, password: password);
      }
      TextInput.finishAutofillContext();
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e) {
          ApiException(isNetwork: true) => l.authErrorNetwork,
          ApiException(code: 'invalid_credentials') => l.authErrorCredentials,
          ApiException(code: 'email_taken') => l.authErrorEmailTaken,
          ApiException(code: 'rate_limited') => l.authErrorRateLimited,
          ApiException(code: 'validation_failed') => l.authErrorInvalid,
          _ => l.commonSomethingWrong,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = context.nyaya;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.commonClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xl),
            children: [
              Text(
                _signIn ? l.authSignInTitle : l.authCreateTitle,
                style: AppTheme.serif(TextStyle(fontSize: 34, height: 1.1, color: context.colors.onSurface)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _signIn ? l.authSignInSubtitle : l.authCreateSubtitle,
                style: context.text.bodyLarge?.copyWith(color: n.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_signIn) ...[
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: l.authName),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l.authEmail),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: [_signIn ? AutofillHints.password : AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l.authPassword,
                  helperText: _signIn ? null : l.authPasswordHint,
                  suffixIcon: IconButton(
                    tooltip: l.authPassword,
                    icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: context.text.bodyMedium?.copyWith(color: n.error),
                  semanticsLabel: _error,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ChunkyButton(
                label: _busy ? '…' : (_signIn ? l.authSignIn : l.authCreate),
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _signIn = !_signIn;
                          _error = null;
                        }),
                child: Text(_signIn ? l.authNeedAccount : l.authHaveAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
