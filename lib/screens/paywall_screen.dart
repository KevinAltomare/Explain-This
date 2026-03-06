import 'package:flutter/material.dart';
import 'package:explain_this/services/billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool loading = true;
  List<ProductDetails> products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    await BillingService.instance.init();
    products = BillingService.instance.products;

    products.sort((a, b) {
    int rank(ProductDetails p) {
      final id = p.id.toLowerCase();

      if (id == "premium") return 0;
      if (id == "premium_lifetime") return 2;

      return 1; // fallback for anything else
    }

    return rank(a).compareTo(rank(b));
  });

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text("Upgrade"),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (products.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text("Upgrade"),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: const Center(child: Text("No products available.")),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Upgrade"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),

      // ⭐ Scrollable content
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Unlock unlimited explanations",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You’ve used your 3 free explanations.\nUpgrade to continue without limits.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 32),

              _buildBenefit(theme, Icons.bolt, "Unlimited explanations"),
              _buildBenefit(theme, Icons.lock_open, "No usage limits"),
              _buildBenefit(theme, Icons.history, "Full history saved"),
              _buildBenefit(theme, Icons.language, "English + Spanish output"),

              const SizedBox(height: 32),

              for (final product in products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildOption(
                    context,
                    theme,
                    title: product.title,
                    price: product.price,
                    subtitle: product.description,
                    onTap: () => _purchase(product),
                  ),
                ),

              const SizedBox(height: 80), // space above bottom button
            ],
          ),
        ),
      ),

      // ⭐ Fixed bottom button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Not now",
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(ProductDetails product) async {
    BillingService.instance.buy(product);
    await Future.delayed(const Duration(seconds: 1));

    final isPremium = await BillingService.instance.isPremium();
    if (isPremium && mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildBenefit(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String price,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}