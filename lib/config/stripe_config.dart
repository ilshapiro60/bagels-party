/// Stripe configuration — replace placeholder values with your real keys.
///
/// 1. Create a Stripe account at https://dashboard.stripe.com
/// 2. Copy your Publishable Key (pk_test_... or pk_live_...)
/// 3. Set the Secret Key on your Firebase Cloud Function environment
///    (never embed the secret key in client code)
class StripeConfig {
  StripeConfig._();

  /// Publishable key visible to the client (safe to embed).
  /// Replace with your real key from the Stripe Dashboard.
  static const publishableKey = 'pk_test_REPLACE_WITH_YOUR_PUBLISHABLE_KEY';

  // Cloud Function endpoint that creates a PaymentIntent.
  // After deploying, replace YOUR_PROJECT_ID with your Firebase project ID.
  static const paymentIntentEndpoint =
      'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/createPaymentIntent';

  /// Apple Merchant ID for Apple Pay (optional).
  static const appleMerchantId = 'merchant.com.yourcompany.pawparty';
}
