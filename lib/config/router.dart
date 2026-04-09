import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/neighborhood_news.dart';
import '../models/pet.dart';
import '../providers/app_providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/discover/community_vet_clinics_screen.dart';
import '../screens/create_pet/create_pet_screen.dart';
import '../screens/meetup/host_meetup_screen.dart';
import '../screens/passport/passport_screen.dart';
import '../screens/passport/add_passport_entry_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/stories/party_stories_screen.dart';
import '../screens/stories/add_story_screen.dart';
import '../screens/pet/pet_detail_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/meetup/invite_friends_screen.dart';
import '../screens/meetup/manage_party_guests_screen.dart';
import '../screens/neighborhood_news/neighborhood_news_compose_screen.dart';
import '../screens/neighborhood_news/neighborhood_news_feed_screen.dart';
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
    final container = ProviderScope.containerOf(context);
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
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const DiscoverScreen(),
          ),
        ),
        GoRoute(
          path: '/passport',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const PassportScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/community-vet-clinics',
      builder: (context, state) => const CommunityVetClinicsScreen(),
    ),
    GoRoute(
      path: '/pet/:id',
      builder: (context, state) => PetDetailScreen(
        petId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/create-pet',
      builder: (context, state) => const CreatePetScreen(),
    ),
    GoRoute(
      path: '/edit-pet/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra;
        final initial = extra is Pet ? extra : null;
        return CreatePetScreen(editPetId: id, initialPet: initial);
      },
    ),
    GoRoute(
      path: '/host',
      builder: (context, state) => const HostMeetupScreen(),
    ),
    GoRoute(
      path: '/party-stories',
      builder: (context, state) => const PartyStoriesScreen(),
    ),
    GoRoute(
      path: '/add-story',
      builder: (context, state) => const AddStoryScreen(),
    ),
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/chat/:friendUid',
      builder: (context, state) => ChatScreen(
        friendUid: state.pathParameters['friendUid']!,
      ),
    ),
    GoRoute(
      path: '/invite-friends/:meetupId',
      builder: (context, state) => InviteFriendsScreen(
        meetupId: state.pathParameters['meetupId']!,
      ),
    ),
    GoRoute(
      path: '/party-guests/:meetupId',
      builder: (context, state) => ManagePartyGuestsScreen(
        meetupId: state.pathParameters['meetupId']!,
      ),
    ),
    GoRoute(
      path: '/add-passport-entry',
      builder: (context, state) {
        final extra = state.extra;
        final initialPetId = extra is String ? extra : null;
        return AddPassportEntryScreen(initialPetId: initialPetId);
      },
    ),
    GoRoute(
      path: '/neighborhood-news',
      builder: (context, state) => const NeighborhoodNewsFeedScreen(),
    ),
    GoRoute(
      path: '/neighborhood-news/new',
      builder: (context, state) => const NeighborhoodNewsComposeScreen(),
    ),
    GoRoute(
      path: '/neighborhood-news/post/:postId',
      builder: (context, state) {
        final id = state.pathParameters['postId']!;
        final extra = state.extra;
        final initial = extra is NeighborhoodNewsPost ? extra : null;
        return NeighborhoodNewsPostDetailScreen(
          postId: id,
          initialPost: initial,
        );
      },
    ),
    GoRoute(
      path: '/moderation/neighborhood-news',
      builder: (context, state) => const NeighborhoodNewsModerationScreen(),
    ),
  ],
);
