import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/cloud_functions_region.dart';

/// When `true`, skips Stripe + Cloud Function (debug/profile only). See [StripeConfig].
const bool _skipPartyPaymentFromDefine =
    bool.fromEnvironment('SKIP_PARTY_PAYMENT', defaultValue: false);

/// Handles party-hosting payments via Stripe.
///
/// Flow:
///  1. Call Firebase Cloud Function to create a PaymentIntent
///  2. Present the Stripe Payment Sheet to the user
///  3. Return true on success, false on cancellation / failure
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  /// Whether dev-only payment skip is compiled in (still requires non-release).
  static bool get skipPartyPaymentRequested => _skipPartyPaymentFromDefine;

  /// Initiates a Stripe payment for the given [productId].
  /// Returns `true` on successful payment, `false` if the user cancels
  /// or the payment fails.
  Future<bool> purchasePartyHosting(String productId) async {
    if (_skipPartyPaymentFromDefine) {
      if (kReleaseMode) {
        throw StateError(
          'SKIP_PARTY_PAYMENT cannot be used in release builds. '
          'Remove the dart-define for production.',
        );
      }
      debugPrint(
        'IapService: SKIP_PARTY_PAYMENT=true — skipping createPaymentIntent & Stripe.',
      );
      return true;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw StateError(
        'You must be signed in to pay. Sign out and sign in again, then retry.',
      );
    }
    // Ensures a fresh ID token is minted before the callable (avoids UNAUTHENTICATED
    // when the session was restored from disk or tokens expired).
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
