import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/meetup.dart';
import '../models/neighborhood_news.dart';
import '../models/passport_entry.dart';
import '../models/pet.dart';
import '../providers/app_providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/discover/community_vet_clinics_screen.dart';
import '../screens/create_pet/create_pet_screen.dart';
import '../screens/meetup/edit_party_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/help_support_screen.dart';
import '../screens/settings/privacy_safety_screen.dart';
import '../screens/meetup/host_meetup_screen.dart';
import '../screens/passport/passport_screen.dart';
import '../screens/passport/add_passport_entry_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/pet/pet_detail_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/messenger_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/friends/friend_profile_screen.dart';
import '../screens/meetup/invite_friends_screen.dart';
import '../screens/meetup/manage_party_guests_screen.dart';
import '../screens/meetup/my_parties_list_screen.dart';
import '../screens/meetup/party_invitations_list_screen.dart';
import '../screens/neighborhood_news/neighborhood_news_compose_screen.dart';
import '../screens/neighborhood_news/neighborhood_news_feed_screen.dart';
import '../screens/moderation/chat_safety_moderation_screen.dart';
import '../screens/neighborhood_news/neighborhood_news_moderation_screen.dart';
import '../screens/neighborhood_news/neighborhood_news_post_detail_screen.dart';
import '../widgets/nav_shell.dart';
import 'auth_router_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: authRouterRefresh,
  redirect: (BuildContext context, GoRouterState state) {
    final container = ProviderScope.containerOf(context, listen: false);
    final auth = container.read(authStateProvider);
    final loc = state.matchedLocation;

    final isPublicAuth = loc == '/login' || loc == '/register';
    final isOnboarding = loc == '/onboarding';

    if (!auth.isAuthenticated) {
      if (isPublicAuth || isOnboarding) return null;
      return '/login';
    }

    if (auth.isAuthenticated && isPublicAuth) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => NavShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/discover',
          pageBuilder: (context, state) {
            final tab = state.extra is int ? state.extra as int : 0;
            return NoTransitionPage(
              key: state.pageKey,
              child: DiscoverScreen(initialTab: tab),
            );
          },
        ),
        GoRoute(
          path: '/passport',
          pageBuilder: (context, state) {
            final meetupId = state.uri.queryParameters['meetupId'];
            return NoTransitionPage(
              key: ValueKey('passport-${meetupId ?? ''}'),
              child: PassportScreen(initialMeetupId: meetupId),
            );
          },
        ),
        GoRoute(
          path: '/neighborhood-news',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const NeighborhoodNewsFeedScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => CupertinoPage<void>(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/my-parties',
          pageBuilder: (context, state) => CupertinoPage<void>(
            key: state.pageKey,
            child: const MyPartiesListScreen(),
          ),
        ),
        GoRoute(
          path: '/party-invitations',
          pageBuilder: (context, state) => CupertinoPage<void>(
            key: state.pageKey,
            child: const PartyInvitationsListScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/feed',
      pageBuilder: (context, state) => CupertinoPage(
        child: const FeedScreen(),
      ),
    ),
    GoRoute(
      path: '/community-vet-clinics',
      pageBuilder: (context, state) => CupertinoPage(
        child: const CommunityVetClinicsScreen(),
      ),
    ),
    GoRoute(
      path: '/pet/:id',
      pageBuilder: (context, state) => CupertinoPage(
        child: PetDetailScreen(petId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/create-pet',
      pageBuilder: (context, state) => CupertinoPage(
        child: const CreatePetScreen(),
      ),
    ),
    GoRoute(
      path: '/edit-pet/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra;
        final initial = extra is Pet ? extra : null;
        return CupertinoPage(
          child: CreatePetScreen(editPetId: id, initialPet: initial),
        );
      },
    ),
    GoRoute(
      path: '/host',
      pageBuilder: (context, state) => CupertinoPage(
        child: const HostMeetupScreen(),
      ),
    ),
    GoRoute(
      path: '/settings/privacy',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: PrivacySafetyScreen()),
    ),
    GoRoute(
      path: '/settings/help',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: HelpSupportScreen()),
    ),
    GoRoute(
      path: '/settings/about',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: AboutScreen()),
    ),
    GoRoute(
      path: '/edit-party/:id',
      pageBuilder: (context, state) {
        final meetup = state.extra as Meetup;
        return CupertinoPage(child: EditPartyScreen(meetup: meetup));
      },
    ),
    GoRoute(
      path: '/friends',
      pageBuilder: (context, state) => CupertinoPage(
        child: const FriendsScreen(),
      ),
    ),
    GoRoute(
      path: '/messenger',
      pageBuilder: (context, state) => CupertinoPage(
        child: const MessengerScreen(),
      ),
    ),
    GoRoute(
      path: '/friend/:friendUid',
      pageBuilder: (context, state) => CupertinoPage(
        child: FriendProfileScreen(
          friendUid: state.pathParameters['friendUid']!,
        ),
      ),
    ),
    GoRoute(
      path: '/conversation/:conversationId',
      pageBuilder: (context, state) => CupertinoPage(
        child: ChatScreen.conversation(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/chat/:friendUid',
      pageBuilder: (context, state) => CupertinoPage(
        child: ChatScreen.friend(friendUid: state.pathParameters['friendUid']!),
      ),
    ),
    GoRoute(
      path: '/invite-friends/:meetupId',
      pageBuilder: (context, state) => CupertinoPage(
        child: InviteFriendsScreen(
          meetupId: state.pathParameters['meetupId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/party-guests/:meetupId',
      pageBuilder: (context, state) => CupertinoPage(
        child: ManagePartyGuestsScreen(
          meetupId: state.pathParameters['meetupId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/add-passport-entry',
      pageBuilder: (context, state) {
        final extra = state.extra;
        if (extra is PassportEntry) {
          return CupertinoPage(
            child: AddPassportEntryScreen(existingEntry: extra),
          );
        }
        final initialPetId = extra is String ? extra : null;
        return CupertinoPage(
          child: AddPassportEntryScreen(initialPetId: initialPetId),
        );
      },
    ),
    GoRoute(
      path: '/neighborhood-news/new',
      pageBuilder: (context, state) => CupertinoPage(
        child: const NeighborhoodNewsComposeScreen(),
      ),
    ),
    GoRoute(
      path: '/neighborhood-news/post/:postId',
      pageBuilder: (context, state) {
        final id = state.pathParameters['postId']!;
        final extra = state.extra;
        final initial = extra is NeighborhoodNewsPost ? extra : null;
        return CupertinoPage(
          child: NeighborhoodNewsPostDetailScreen(
            postId: id,
            initialPost: initial,
          ),
        );
      },
    ),
    GoRoute(
      path: '/moderation/neighborhood-news',
      pageBuilder: (context, state) => CupertinoPage(
        child: const NeighborhoodNewsModerationScreen(),
      ),
    ),
    GoRoute(
      path: '/moderation/chat-safety',
      pageBuilder: (context, state) => CupertinoPage(
        child: const ChatSafetyModerationScreen(),
      ),
    ),
  ],
);
