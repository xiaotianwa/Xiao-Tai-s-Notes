import 'package:flutter_test/flutter_test.dart';
import 'package:xiaotai_life/app/app_router.dart';
import 'package:xiaotai_life/core/constants/app_routes.dart';

void main() {
  group('authRedirectLocation', () {
    test('waits until auth state is initialized', () {
      expect(
        authRedirectLocation(
          initialized: false,
          isSignedIn: false,
          matchedLocation: AppRoutes.today,
        ),
        isNull,
      );
    });

    test('redirects signed-out users to login for app pages', () {
      expect(
        authRedirectLocation(
          initialized: true,
          isSignedIn: false,
          matchedLocation: AppRoutes.today,
        ),
        AppRoutes.login,
      );
    });

    test('keeps signed-out users on login page', () {
      expect(
        authRedirectLocation(
          initialized: true,
          isSignedIn: false,
          matchedLocation: AppRoutes.login,
        ),
        isNull,
      );
    });

    test('redirects signed-in users away from login page', () {
      expect(
        authRedirectLocation(
          initialized: true,
          isSignedIn: true,
          matchedLocation: AppRoutes.login,
        ),
        AppRoutes.today,
      );
    });

    test('allows signed-in users to open app pages', () {
      expect(
        authRedirectLocation(
          initialized: true,
          isSignedIn: true,
          matchedLocation: AppRoutes.treasureBox,
        ),
        isNull,
      );
    });
  });
}
