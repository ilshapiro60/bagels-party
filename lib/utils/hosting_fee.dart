import '../config/constants.dart';
import '../models/user_profile.dart';

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
  if (fee == AppConstants.partyFeeRegular) return 'party_host_regular';
  if (fee == AppConstants.partyFeeBizSmall) return 'party_host_biz_small';
  if (fee == AppConstants.partyFeeBizMedium) return 'party_host_biz_medium';
  if (fee == AppConstants.partyFeeBizLarge) return 'party_host_biz_large';
  return 'party_host_regular';
}
