import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/event.dart';
import 'screens/create_event_screen.dart';
import 'screens/event_details_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/my_events_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'services/auth_store.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const _destinations = ['/', '/create', '/profile'];

  int _indexForLocation(String location) {
    if (location.startsWith('/create')) return 1;
    if (location.startsWith('/profile') || location.startsWith('/my-events')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(location);

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == index) return;
          context.go(_destinations[i]);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'События'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Создать'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

GoRouter buildRouter(AuthStore auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.isReady) return null;

      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isLoggedIn) {
        return loggingIn ? null : '/login';
      }
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/create',
            builder: (_, state) {
              final existing = state.extra is Event ? state.extra as Event : null;
              return CreateEventScreen(existing: existing);
            },
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
          GoRoute(path: '/my-events', builder: (_, __) => const MyEventsScreen()),
        ],
      ),
      GoRoute(
        path: '/events/:id',
        builder: (ctx, st) => EventDetailsScreen(id: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (ctx, st) => PublicProfileScreen(userId: st.pathParameters['id']!),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
    ],
  );
}
