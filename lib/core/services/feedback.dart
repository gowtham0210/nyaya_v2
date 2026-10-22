import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/application/profile_controller.dart';

enum Haptic { tap, select, success, error, celebrate }

/// Haptic feedback that respects the user's setting.
final feedbackProvider = Provider<FeedbackService>((ref) => FeedbackService(ref));

class FeedbackService {
  FeedbackService(this._ref);

  final Ref _ref;

  void play(Haptic kind) {
    if (!_ref.read(profileProvider).hapticsOn) return;
    switch (kind) {
      case Haptic.tap:
        HapticFeedback.lightImpact();
      case Haptic.select:
        HapticFeedback.selectionClick();
      case Haptic.success:
        HapticFeedback.mediumImpact();
      case Haptic.error:
        HapticFeedback.heavyImpact();
      case Haptic.celebrate:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 120), HapticFeedback.mediumImpact);
    }
  }
}
