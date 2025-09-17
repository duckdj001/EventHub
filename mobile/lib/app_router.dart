import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/event_details_screen.dart';
import 'screens/login_screen.dart'; 


class MainScaffold extends StatefulWidget {
final Widget child;
const MainScaffold({super.key, required this.child});
@override
State<MainScaffold> createState() => _MainScaffoldState();
}


class _MainScaffoldState extends State<MainScaffold> {
int _index = 0;
void _onTap(int i) {
setState(() => _index = i);
switch (i) {
case 0:
context.go('/');
break;
case 1:
context.go('/create');
break;
case 2:
context.go('/profile');
break;
}
}


@override
Widget build(BuildContext context) {
return Scaffold(
body: SafeArea(child: widget.child),
bottomNavigationBar: NavigationBar(
selectedIndex: _index,
onDestinationSelected: _onTap,
destinations: const [
NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'События'),
NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Создать'),
NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
],
),
);
}
}


GoRouter buildRouter() {
return GoRouter(
initialLocation: '/',
routes: [
ShellRoute(
builder: (context, state, child) => MainScaffold(child: child),
routes: [
GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
GoRoute(path: '/create', builder: (_, __) => const CreateEventScreen()),
GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
],
),
// Детали события — отдельный маршрут без нижнего меню
GoRoute(
path: '/events/:id',
builder: (ctx, st) => EventDetailsScreen(id: st.pathParameters['id']!),
),
GoRoute(
  path: '/login',
  builder: (_, __) => const LoginScreen(),
),
],
);
}
