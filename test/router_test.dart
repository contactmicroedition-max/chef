import 'package:flutter_test/flutter_test.dart';
import 'package:zone/app/router.dart';
import 'package:zone/providers/app_state.dart';

void main() {
  const locations = ['/splash', '/login', '/register', '/org-setup', '/home'];

  group('auth redirects', () {
    test(
      'unknown auth status stays on splash and redirects every other route',
      () {
        for (final location in locations) {
          expect(
            authRedirectLocation(AuthStatus.unknown, location),
            location == '/splash' ? null : '/splash',
            reason: 'location: $location',
          );
        }
      },
    );

    test(
      'unauthenticated status stays on login and redirects every other route',
      () {
        for (final location in locations) {
          expect(
            authRedirectLocation(AuthStatus.unauthenticated, location),
            location == '/login' ? null : '/login',
            reason: 'location: $location',
          );
        }
      },
    );

    test('authenticated status redirects login and splash to home', () {
      for (final location in locations) {
        expect(
          authRedirectLocation(AuthStatus.authenticated, location),
          location == '/login' || location == '/splash' ? '/home' : null,
          reason: 'location: $location',
        );
      }
    });
  });
}
