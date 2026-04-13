import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/cloud_functions_region.dart';

/// Handles party-hosting payments via Stripe.
///
/// Flow:
///  1. Call Firebase Cloud Function to create a PaymentIntent
///  2. Present the Stripe Payment Sheet to the user
///  3. Return true on success, false on cancellation / failure
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  /// Initiates a Stripe payment for the given [productId].
  /// Returns `true` on successful payment, `false` if the user cancels
  /// or the payment fails.
  Future<bool> purchasePartyHosting(String productId) async {
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
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            testEnv: true,
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return false;
      }
      rethrow;
    }
  }
}
