import 'package:flutter/widgets.dart';

import '../../../../core/l10n/l10n.dart';

/// The rules a new password must meet. Keep in step with the API
/// (backend/src/auth/passwords.ts), which enforces the same ones.
bool pwHasLength(String p) => p.length >= 8 && p.length <= 200;
bool pwHasUpper(String p) => RegExp('[A-Z]').hasMatch(p);
bool pwHasLower(String p) => RegExp('[a-z]').hasMatch(p);
bool pwHasDigit(String p) => RegExp(r'\d').hasMatch(p);
bool pwHasSymbol(String p) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(p);
bool pwHasNoSpace(String p) => !RegExp(r'\s').hasMatch(p);

bool isStrongPassword(String p) =>
    pwHasLength(p) && pwHasUpper(p) && pwHasLower(p) && pwHasDigit(p) && pwHasSymbol(p) && pwHasNoSpace(p);

/// What is wrong with [p], as one sentence ("Password needs at least 8
/// characters, a number."), or null when it meets every rule.
String? passwordProblem(BuildContext context, String p) {
  final l = context.l10n;
  if (p.isEmpty) return l.authErrorPasswordEmpty;
  final missing = <String>[
    if (!pwHasLength(p)) l.authPwNeedLength,
    if (!pwHasUpper(p)) l.authPwNeedUpper,
    if (!pwHasLower(p)) l.authPwNeedLower,
    if (!pwHasDigit(p)) l.authPwNeedDigit,
    if (!pwHasSymbol(p)) l.authPwNeedSymbol,
    if (!pwHasNoSpace(p)) l.authPwNeedNoSpace,
  ];
  return missing.isEmpty ? null : l.authErrorPasswordNeeds(missing.join(', '));
}
