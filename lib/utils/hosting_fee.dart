import '../config/constants.dart';
import '../models/user_profile.dart';

// App Store (iOS): create **consumable** IAPs in App Store Connect with these
// exact IDs (required for 3.1.1). Android uses Stripe; see IapService.

/// Canonical product IDs for the four party-hosting consumables.
///
/// Apple's App Review tooling (Guideline 2.1(b)) looks for these IDs as string
/// literals referenced by a `SKProductsRequest` in the binary. We list them
/// here as top-level constants and pass the whole [kPartyHostingProductIds]
/// set to `InAppPurchase.queryProductDetails(...)` at app launch (see
/// `IapService.warmUp()` and `main.dart`) so the request fires from the very
/// first launch — not only when a user happens to reach the paywall.
const String kProductIdPartyHostRegular = 'party_host_regular';
const String kProductIdPartyHostBizSmall = 'party_host_biz_small';
const String kProductIdPartyHostBizMedium = 'party_host_biz_medium';
const String kProductIdPartyHostBizLarge = 'party_host_biz_large';

/// All party-hosting consumable product IDs, in display order.
const Set<String> kPartyHostingProductIds = <String>{
  kProductIdPartyHostRegular,
  kProductIdPartyHostBizSmall,
  kProductIdPartyHostBizMedium,
  kProductIdPartyHostBizLarge,
};

/// Returns the hosting fee for a party based on the user's account type,
/// host count, and guest limit.
double calculateHostingFee(UserProfile user, int maxGuests) {
  if (!user.isBusinessAccount) {
    return user.hostCount < AppConstants.maxFreeHostings
        ? 0.0
        : AppConstants.partyFeeRegular;
  }
  if (maxGuests <= AppConstants.bizSmallGuestMax) {
    return AppConstants.partyFeeBizSmall;
  }
  if (maxGuests <= AppConstants.bizMediumGuestMax) {
    return AppConstants.partyFeeBizMedium;
  }
  return AppConstants.partyFeeBizLarge;
}

/// IAP product ID that corresponds to the given fee.
String hostingFeeProductId(double fee) {
  if (fee == AppConstants.partyFeeRegular) return kProductIdPartyHostRegular;
  if (fee == AppConstants.partyFeeBizSmall) return kProductIdPartyHostBizSmall;
  if (fee == AppConstants.partyFeeBizMedium) return kProductIdPartyHostBizMedium;
  if (fee == AppConstants.partyFeeBizLarge) return kProductIdPartyHostBizLarge;
  return kProductIdPartyHostRegular;
}
