import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillingService {
  BillingService._internal();
  static final BillingService instance = BillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  final Set<String> _productIds = {
    'premium_lifetime',
    'premium',
  };

  List<ProductDetails> products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    // Listen for purchase updates
    _subscription = _iap.purchaseStream.listen(_handlePurchaseUpdates);

    // Load product details
    final response = await _iap.queryProductDetails(_productIds);
    products = response.productDetails;

    // 🔥 CRITICAL: Restore purchases on startup
    await _iap.restorePurchases();
  }

  void buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {

        // Unlock premium
        await _unlockPremium();

        // Complete the purchase if needed
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);
  }

  Future<bool> isPremium() async {
    if (kDebugMode) return true; // Always premium in debug

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isPremium') ?? false;
  }

  void dispose() {
    _subscription?.cancel();
  }
}