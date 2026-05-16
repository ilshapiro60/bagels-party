import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/cloud_functions_region.dart';
import '../utils/hosting_fee.dart';

/// When `true`, skips Stripe + Cloud Function (debug/profile only). See StripeConfig.
const bool _skipPartyPaymentFromDefine =
    bool.fromEnvironment('SKIP_PARTY_PAYMENT', defaultValue: false);

/// Result of warming / probing the App Store IAP catalogue.
///
/// Used by the "Verify In-App Purchases" tile in Profile so App Review can
/// confirm StoreKit is wired up without first reaching the paywall.
class IapWarmUpResult {
  IapWarmUpResult({
    required this.storeAvailable,
    required this.foundProductIds,
    required this.notFoundProductIds,
    this.errorMessage,
  });

  final bool storeAvailable;
  final List<String> foundProductIds;
  final List<String> notFoundProductIds;
  final String? errorMessage;

  bool get allFound =>
      storeAvailable && notFoundProductIds.isEmpty && errorMessage == null;
}

/// Party-hosting payments:
/// - **iOS**: App Store In-App Purchase (consumables) — Guideline 3.1.1.
/// - **Android & others**: Stripe Payment Sheet + Cloud Function `createPaymentIntent`.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  PurchaseDetails? _pendingIosPurchase;

  /// Last warmup outcome, cached so Profile can show status without re-querying.
  IapWarmUpResult? _lastWarmUp;
  IapWarmUpResult? get lastWarmUp => _lastWarmUp;

  /// Cached ProductDetails keyed by productId, populated by [warmUp].
  /// Used by [purchasePartyHosting] to avoid a second `SKProductsRequest`.
  final Map<String, ProductDetails> _productCache = <String, ProductDetails>{};

  /// Whether dev-only payment skip is compiled in (still requires non-release).
  static bool get skipPartyPaymentRequested => _skipPartyPaymentFromDefine;

  /// Eagerly issues a single `SKProductsRequest` for **all four** party-hosting
  /// consumables on iOS at app launch.
  ///
  /// This is critical for App Review (Guideline 2.1(b)): Apple's automated
  /// check scans the running binary for StoreKit traffic referencing the
  /// declared product IDs. Querying every ID early — instead of only when the
  /// paywall is reached — guarantees the products are "found in the submitted
  /// binary". Safe to call multiple times; failures are swallowed.
  Future<IapWarmUpResult> warmUp() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      final result = IapWarmUpResult(
        storeAvailable: false,
        foundProductIds: const <String>[],
        notFoundProductIds: kPartyHostingProductIds.toList(),
        errorMessage: 'Not iOS — App Store IAP not used on this platform.',
      );
      _lastWarmUp = result;
      return result;
    }

    final iap = InAppPurchase.instance;
    try {
      final available = await iap.isAvailable();
      if (!available) {
        final result = IapWarmUpResult(
          storeAvailable: false,
          foundProductIds: const <String>[],
          notFoundProductIds: kPartyHostingProductIds.toList(),
          errorMessage: 'App Store is unavailable (no network or store down).',
        );
        _lastWarmUp = result;
        return result;
      }

      final response = await iap.queryProductDetails(kPartyHostingProductIds);
      _productCache
        ..clear()
        ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));

      final result = IapWarmUpResult(
        storeAvailable: true,
        foundProductIds: response.productDetails.map((p) => p.id).toList(),
        notFoundProductIds: response.notFoundIDs,
        errorMessage: response.error?.message,
      );
      _lastWarmUp = result;
      if (kDebugMode) {
        debugPrint(
          'IapService.warmUp: found=${result.foundProductIds} '
          'notFound=${result.notFoundProductIds} '
          'err=${result.errorMessage}',
        );
      }
      return result;
    } catch (e, st) {
      debugPrint('IapService.warmUp failed: $e\n$st');
      final result = IapWarmUpResult(
        storeAvailable: false,
        foundProductIds: const <String>[],
        notFoundProductIds: kPartyHostingProductIds.toList(),
        errorMessage: e.toString(),
      );
      _lastWarmUp = result;
      return result;
    }
  }

  /// Call after hosting digital content is delivered (meetup saved) or attempt ends,
  /// so StoreKit can finish the transaction (consumables).
  Future<void> finalizeIosPurchaseIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final pending = _pendingIosPurchase;
    if (pending == null) return;
    try {
      if (pending.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(pending);
      }
    } catch (e, st) {
      debugPrint('finalizeIosPurchaseIfNeeded: $e $st');
    } finally {
      _pendingIosPurchase = null;
    }
  }

  /// Initiates payment for party hosting. Returns `true` when payment succeeded.
  ///
  /// On iOS, finishes StoreKit only after you call [finalizeIosPurchaseIfNeeded]
  /// (e.g. after Firestore publish succeeds or fails).
  Future<bool> purchasePartyHosting(String productId) async {
    if (_skipPartyPaymentFromDefine) {
      if (kReleaseMode) {
        throw StateError(
          'SKIP_PARTY_PAYMENT cannot be used in release builds. '
          'Remove the dart-define for production.',
        );
      }
      debugPrint(
        'IapService: SKIP_PARTY_PAYMENT=true — skipping payment.',
      );
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _purchasePartyHostingIos(productId);
    }

    return _purchasePartyHostingStripe(productId);
  }

  Future<bool> _purchasePartyHostingIos(String productId) async {
    final iap = InAppPurchase.instance;
    final storeOk = await iap.isAvailable();
    if (!storeOk) {
      throw StateError(
        'App Store purchases are unavailable. Check network and try again.',
      );
    }

    ProductDetails? product = _productCache[productId];
    if (product == null) {
      // Cache miss — warmUp hasn't completed or store rejected this ID earlier.
      // Re-query to surface a precise error to the user.
      final response = await iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        throw StateError(
          'Hosting product "$productId" is missing in App Store Connect. '
          'Confirm the consumable IAP exists with this exact product ID, is in '
          '"Ready to Submit" state, and is attached to the current app version.',
        );
      }
      product = response.productDetails.first;
      _productCache[productId] = product;
    }

    final completer = Completer<PurchaseDetails?>();
    StreamSubscription<List<PurchaseDetails>>? sub;

    Future<void> onPurchases(List<PurchaseDetails> purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != productId) continue;
        switch (purchase.status) {
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (!completer.isCompleted) completer.complete(purchase);
            break;
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) completer.complete(null);
            break;
        }
      }
    }

    sub = iap.purchaseStream.listen(onPurchases);

    try {
      final ok = await iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!ok) {
        await sub.cancel();
        return false;
      }

      final details = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => null,
      );
      await sub.cancel();

      if (details == null) return false;
      if (details.status == PurchaseStatus.error ||
          details.status == PurchaseStatus.canceled) {
        return false;
      }

      _pendingIosPurchase = details;
      return true;
    } catch (e, st) {
      debugPrint('iOS IAP error: $e $st');
      await sub.cancel();
      rethrow;
    }
  }

  Future<bool> _purchasePartyHostingStripe(String productId) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError(
        'You must be signed in to pay. Sign out and sign in again, then retry.',
      );
    }
    // Refresh user record + ID token so callables receive a valid Bearer token.
    try {
      await authUser.reload();
    } catch (_) {
      // Non-fatal; continue with getIdToken.
    }
    await authUser.getIdToken(true);
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError(
        'Your session expired. Sign out and sign in again, then retry payment.',
      );
    }

    try {
      final callable = pawPartyFirebaseFunctions().httpsCallable(
        'createPaymentIntent',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'productId': productId,
      });

      final data = result.data;
      final clientSecret = data['clientSecret'] as String;
      final ephemeralKey = data['ephemeralKey'] as String;
      final customerId = data['customerId'] as String;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'PawParty',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          applePay: const PaymentSheetApplePay(
            merchantCountryCode: 'US',
          ),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            testEnv: !kReleaseMode,
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw StateError(
          'Payment could not verify your Firebase login (${e.message ?? e.code}). '
          'Sign out and sign in again. If this persists: deploy latest '
          '`createPaymentIntent` (Firebase Console → Functions), confirm this build '
          'uses the same Firebase project as production (google-services.json / '
          'flutterfire), and add your debug/release SHA-1 in Firebase Console → '
          'Project settings → Your apps.',
        );
      }
      rethrow;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return false;
      }
      rethrow;
    }
  }
}
