import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PremiumPlan { monthly, yearly }

/// Store abstraction. Ship with an `in_app_purchase` / RevenueCat
/// implementation; [DemoPurchaseService] lets the full flow be exercised in
/// development without a store account.
abstract interface class PurchaseService {
  Future<bool> purchase(PremiumPlan plan);
  Future<bool> restore();
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) => DemoPurchaseService());

class DemoPurchaseService implements PurchaseService {
  bool _owned = false;

  @override
  Future<bool> purchase(PremiumPlan plan) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _owned = true;
    return true;
  }

  @override
  Future<bool> restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _owned;
  }
}
