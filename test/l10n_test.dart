import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every language file carries every English text, so no screen falls back to English by accident.
void main() {
  Map<String, dynamic> load(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
  final english = load('en');
  Set<String> texts(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();
  Set<String> holes(String text) => RegExp(r'\{(\w+)(?:,|\})').allMatches(text).map((m) => m.group(1)!).toSet();

  for (final lang in ['hi', 'kn', 'ml', 'ta', 'te']) {
    test('$lang has every English text, nothing extra, and the same placeholders', () {
      final arb = load(lang);
      expect(texts(english).difference(texts(arb)), isEmpty, reason: '$lang is missing texts');
      expect(texts(arb).difference(texts(english)), isEmpty, reason: '$lang has texts English lacks');
      for (final key in texts(english)) {
        final source = english[key] as String;
        final translated = arb[key] as String;
        expect(translated.trim(), isNotEmpty, reason: '$lang $key is empty');
        expect(holes(translated), holes(source), reason: '$lang $key changed a placeholder');
      }
    });
  }
}
