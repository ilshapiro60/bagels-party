import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/cloud_functions_region.dart';

/// When `true`, skips Stripe + Cloud Function (debug/profile only). See StripeConfig.
const bool _skipPartyPaymentFromDefine =
    bool.fromEnvironment('SKIP_PARTY_PAYMENT', defaultValue: false);

/// Party-hosting payments:
/// - **iOS**: App Store In-App Purchase (consumables) — Guideline 3.1.1.
/// - **Android & others**: Stripe Payment Sheet + Cloud Function `createPaymentIntent`.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  PurchaseDetails? _pendingIosPurchase;

  /// Whether dev-only payment skip is compiled in (still requires non-release).
  static bool get skipPartyPaymentRequested => _skipPartyPaymentFromDefine;

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

    final response = await iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw StateError(
        'Hosting product "$productId" is missing in App Store Connect. '
        'Add a consumable IAP with this exact product ID (see hosting_fee.dart).',
      );
    }
    final product = response.productDetails.first;

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
    await authUser.getIdToken(true);

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
          'Payment service could not verify your login (${e.message ?? e.code}). '
          'Try signing out and back in. For production, ensure the Cloud Function '
          'allows authenticated callables and Firebase Auth matches this app.',
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
