import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Simulates an auth state that can be toggled.
final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(true);

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/home',
      refreshListenable: isAuthenticated,
      onEnter:
          (
            BuildContext context,
            GoRouterState current,
            GoRouterState next,
            GoRouter router,
          ) {
            final goingTo = next.matchedLocation;
            debugPrint(
              '[onEnter] authenticated=${isAuthenticated.value}, '
              'going to $goingTo',
            );

            // Public routes — always allow
            if (goingTo == '/login') return const Allow();

            // Protected routes — require auth
            if (!isAuthenticated.value) {
              debugPrint('[onEnter] Blocking, returning Block.then(go /login)');
              return Block.then(() {
                debugPrint('[Block.then] Calling router.go(/login)');
                router.go('/login');
              });
            }

            return const Allow();
          },
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const _Screen(title: 'Home (protected)'),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const _Screen(title: 'Login (public)'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Block.then() re-entrancy bug',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final isOnLogin = currentLocation == '/login';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),

            // Bug indicator
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isOnLogin ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOnLogin ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isOnLogin ? Icons.check_circle : Icons.bug_report,
                    size: 48,
                    color: isOnLogin ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOnLogin
                        ? 'FIXED: Reached /login'
                        : 'BUG: Stuck at $currentLocation',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isOnLogin
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnLogin
                        ? 'Block.then(() => router.go("/login")) worked correctly'
                        : 'Block.then() callback navigation was lost due to re-entrancy',
                    style: TextStyle(
                      fontSize: 14,
                      color: isOnLogin
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Route info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Route Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow('Current route:', currentLocation),
                    _InfoRow('Page title:', title),
                    ValueListenableBuilder<bool>(
                      valueListenable: isAuthenticated,
                      builder: (_, authed, _) =>
                          _InfoRow('Authenticated:', '$authed'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            FilledButton.icon(
              onPressed: () {
                isAuthenticated.value = !isAuthenticated.value;
              },
              icon: const Icon(Icons.swap_horiz),
              label: ValueListenableBuilder<bool>(
                valueListenable: isAuthenticated,
                builder: (_, authed, _) => Text(
                  authed ? 'Sign Out (set false)' : 'Sign In (set true)',
                ),
              ),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),

            const SizedBox(height: 24),

            // Reproduction steps
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reproduction Steps',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. App starts authenticated on /home\n'
                      '2. Tap "Sign Out" to set isAuthenticated = false\n'
                      '3. refreshListenable fires, guard returns '
                      'Block.then(() => router.go("/login"))\n\n'
                      'Expected: Navigate to /login (green indicator)\n'
                      'Bug: Stay on /home (red indicator) — the callback\'s\n'
                      'router.go() triggers re-entrant route parsing and\n'
                      'the navigation is silently lost.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
