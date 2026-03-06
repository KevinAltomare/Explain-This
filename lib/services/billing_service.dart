import 'dart:async';
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

    _subscription = _iap.purchaseStream.listen(_handlePurchaseUpdates);

    final response = await _iap.queryProductDetails(_productIds);
    products = response.productDetails;
  }

  void buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _unlockPremium();
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);
  }

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('isPremium') ?? false;

    return value;
  }

  void dispose() {
    _subscription?.cancel();
  }
}