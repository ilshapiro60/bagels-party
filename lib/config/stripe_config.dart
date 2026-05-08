/// Stripe configuration — replace placeholder values with your real keys.
///
/// **iOS (App Store):** Party hosting fees must use **In-App Purchase** (StoreKit).
/// Client implementation: `IapService` + consumable product IDs in `hosting_fee.dart`.
/// Do **not** offer Stripe Payment Sheet on iOS for these digital goods (Guideline 3.1.1).
///
/// **Android:** Stripe Payment Sheet + Cloud Function `createPaymentIntent` remains in use.
///
/// 1. Create a Stripe account at https://dashboard.stripe.com
/// 2. Copy your Publishable Key (pk_test_... or pk_live_...)
/// 3. Set the Secret Key on your Firebase Cloud Function environment
///    (never embed the secret key in client code)
///
/// **Production checklist**
/// - Users must be signed in with **Firebase Auth** before pay; [IapService]
///   refreshes the ID token before calling `createPaymentIntent`.
/// - Deploy the callable with **invoker: authenticated** (default for callable)
///   and verify `context.auth` in the function.
/// - Use **live** Stripe keys in the client for store release builds; Google Pay
///   uses `testEnv: false` when `kReleaseMode` is true ([IapService]).
///
/// **Local testing without Stripe / Functions**
/// - Run with `--dart-define=SKIP_PARTY_PAYMENT=true` (debug/profile only;
///   release builds throw if this define is set). Skips Payment Sheet and the
///   callable so you can publish meetups without enabling billing.
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
