import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_screen.dart';
import '../screens/vault_screen.dart';
import '../screens/search_screen.dart';
import '../screens/mission_screen.dart';
import '../screens/ingest_screen.dart';
import '../screens/item_detail_screen.dart';
import '../screens/scan_screen.dart';

/// Shell scaffold with bottom navigation.
class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.child, required this.currentIndex});

  final Widget child;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/vault');
              break;
            case 2:
              context.go('/search');
              break;
            case 3:
              context.go('/missions');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Vault',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.saved_search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.backpack_outlined),
            selectedIcon: Icon(Icons.backpack),
            label: 'Missions',
          ),
        ],
      ),
    );
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter manifestRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        int index = 0;
        final location = state.uri.path;
        if (location.startsWith('/vault')) {
          index = 1;
        } else if (location.startsWith('/search')) {
          index = 2;
        } else if (location.startsWith('/missions')) {
          index = 3;
        }
        return _ShellScaffold(currentIndex: index, child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/vault', builder: (context, state) => const VaultScreen()),
        GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
        GoRoute(path: '/missions', builder: (context, state) => const MissionScreen()),
      ],
    ),
    // Full-screen routes (no bottom nav)
    GoRoute(path: '/ingest', builder: (context, state) => const IngestScreen()),
    GoRoute(
      path: '/item/:id',
      builder: (context, state) => ItemDetailScreen(
        itemId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
  ],
);
