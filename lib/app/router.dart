import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zone/features/auth/presentation/screens/login_screen.dart';
import 'package:zone/features/auth/presentation/screens/register_screen.dart';
import 'package:zone/features/auth/presentation/screens/splash_screen.dart';
import 'package:zone/features/organisations/presentation/screens/create_organisation_screen.dart';
import 'package:zone/features/shell/presentation/home_shell.dart';
import 'package:zone/providers/app_state.dart';

final _routerKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthStatusRefreshListenable();
  ref.listen(
    appStateProvider.select((appState) => appState.authStatus),
    (previous, next) => refreshListenable.refresh(),
  );

  final router = GoRouter(
    navigatorKey: _routerKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authStatus = ref.read(appStateProvider).authStatus;
      return authRedirectLocation(authStatus, state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/org-setup',
        builder: (context, state) => const CreateOrganisationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShellScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refreshListenable.dispose();
  });
  return router;
});

String? authRedirectLocation(AuthStatus authStatus, String matchedLocation) {
  if (authStatus == AuthStatus.unknown) {
    return matchedLocation == '/splash' ? null : '/splash';
  }
  if (authStatus == AuthStatus.unauthenticated) {
    return matchedLocation == '/login' ? null : '/login';
  }
  if (matchedLocation == '/login' || matchedLocation == '/splash') {
    return '/home';
  }
  return null;
}

class _AuthStatusRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}
