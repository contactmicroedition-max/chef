import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zone/features/auth/presentation/auth_screens.dart';
import 'package:zone/features/organisations/presentation/create_organisation_screen.dart';
import 'package:zone/features/shell/presentation/home_shell.dart';
import 'package:zone/providers/app_state.dart';

final _routerKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final appState = ref.watch(appStateProvider);

  return GoRouter(
    navigatorKey: _routerKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // While loading, don't redirect — let the current page stay visible.
      if (appState.isLoading) return null;

      // Not authenticated → force login.
      if (!appState.isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Authenticated
      if (appState.isAuthenticated) {
        // No organisations yet → go to setup.
        if (appState.organisations.isEmpty &&
            state.matchedLocation != '/org-setup') {
          return '/org-setup';
        }

        // Has organisations but on setup → go home.
        if (appState.organisations.isNotEmpty &&
            state.matchedLocation == '/org-setup') {
          return '/home';
        }

        // Already authenticated but on an auth page → go home.
        if (isAuthRoute) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
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
});
