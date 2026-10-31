import 'package:flutter_test/flutter_test.dart';
import 'package:zone/providers/app_state.dart';

void main() {
  test('operation loading does not change authentication status', () {
    const authenticatedState = AppState(authStatus: AuthStatus.authenticated);

    final operationInProgress = authenticatedState.copyWith(isLoading: true);

    expect(operationInProgress.isLoading, isTrue);
    expect(operationInProgress.authStatus, AuthStatus.authenticated);

    final operationComplete = operationInProgress.copyWith(isLoading: false);
    expect(operationComplete.authStatus, AuthStatus.authenticated);
  });
}
