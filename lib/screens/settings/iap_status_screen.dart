import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/iap_service.dart';
import '../../utils/hosting_fee.dart';

/// Shows the status of each party-hosting in-app purchase product.
///
/// This screen exists primarily to help App Review (Guideline 2.1(b)) verify
/// that StoreKit is wired up correctly: it fires a fresh
/// `SKProductsRequest` for every declared product ID and renders the result.
/// It also gives users a quick way to confirm the App Store is reachable
/// before they reach the paywall.
class IapStatusScreen extends StatefulWidget {
  const IapStatusScreen({super.key});

  @override
  State<IapStatusScreen> createState() => _IapStatusScreenState();
}

class _IapStatusScreenState extends State<IapStatusScreen> {
  IapWarmUpResult? _result;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _result = IapService.instance.lastWarmUp;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await IapService.instance.warmUp();
    if (!mounted) return;
    setState(() {
      _result = result;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('In-App Purchases')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PawPartyColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PawPartyColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront, color: PawPartyColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'App Store status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIos
                        ? 'Verifies that StoreKit can load every party-hosting product '
                            'from App Store Connect. Useful before submitting a meetup.'
                        : 'Party hosting on this platform is processed via Stripe, '
                            'not the App Store. This screen is informational.',
                    style: TextStyle(
                      color: PawPartyColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_running && result == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (result != null) ...[
              _statusBanner(result),
              const SizedBox(height: 12),
              for (final productId in kPartyHostingProductIds)
                _productRow(productId, result),
              if (result.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PawPartyColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PawPartyColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    result.errorMessage!,
                    style: TextStyle(
                      color: PawPartyColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _running ? null : _refresh,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_running ? 'Checking…' : 'Re-check products'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(IapWarmUpResult result) {
    final ok = result.allFound;
    final bg =
        (ok ? PawPartyColors.success : PawPartyColors.error).withValues(alpha: 0.1);
    final fg = ok ? PawPartyColors.success : PawPartyColors.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'All ${result.foundProductIds.length} hosting products loaded from the App Store.'
                  : !result.storeAvailable
                      ? 'App Store unavailable. Check the network and try again.'
                      : '${result.notFoundProductIds.length} of '
                          '${kPartyHostingProductIds.length} products are missing.',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productRow(String productId, IapWarmUpResult result) {
    final loaded = result.foundProductIds.contains(productId);
    final icon = loaded ? Icons.check_circle : Icons.cancel;
    final color = loaded ? PawPartyColors.success : PawPartyColors.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              productId,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          Text(
            loaded ? 'Loaded' : 'Missing',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
