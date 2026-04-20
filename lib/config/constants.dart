class AppConstants {
  static const String appName = 'ZumiTok';
  static const String appTagline = 'Where Paws Meet Pizza';
  static const String supportEmail = 'il_shapiro@hotmail.com';
  static const String privacyPolicyUrl = 'https://ilshapiro60.github.io/bagels-party/privacy';
  static const String termsOfServiceUrl = 'https://ilshapiro60.github.io/bagels-party/terms';
  static const double defaultRadius = 5.0; // miles
  static const int maxFreeHostings = 999;

  // Per-party hosting fees
  static const double partyFeeRegular = 3.99;
  static const double partyFeeBizSmall = 9.99;
  static const double partyFeeBizMedium = 19.99;
  static const double partyFeeBizLarge = 29.99;
  static const int bizSmallGuestMax = 20;
  static const int bizMediumGuestMax = 50;
  static const int maxPetsPerHousehold = 5;
  static const int passportFreeEntries = 10;

  static const List<String> playStyles = [
    'Chaser',
    'Wrestler',
    'Parallel Player',
    'Fetch Lover',
    'Snuggler',
    'Explorer',
    'Swimmer',
    'Tug Player',
  ];

  static const List<String> triggers = [
    'Loud noises',
    'Small children',
    'Large dogs',
    'Small dogs',
    'Cats',
    'Food aggression',
    'Leash reactive',
    'Separation anxiety',
    'Thunder/fireworks',
    'Strangers',
  ];

  static const List<String> petTypes = [
    'Dog',
    'Cat',
    'Rabbit',
    'Bird',
    'Guinea Pig',
    'Other',
  ];

  static const List<String> petGenders = [
    'Female',
    'Male',
    'Prefer not to say',
  ];

  static const List<String> sizeCategories = [
    'Tiny (under 10 lbs)',
    'Small (10-25 lbs)',
    'Medium (25-50 lbs)',
    'Large (50-80 lbs)',
    'Extra Large (80+ lbs)',
  ];

  static const List<String> eventThemes = [
    'Casual Hangout',
    'Puppy Bowl Sunday',
    'Halloween Costume Party',
    'Summer Splash',
    'Holiday Howl',
    'Birthday Bash',
    'New Pet Welcome',
    'Training Session',
  ];
}
