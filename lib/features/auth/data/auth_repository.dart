import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/core/utils/formatters.dart';

class AuthRegistrationResult {
  const AuthRegistrationResult({
    this.response,
    this.authenticatedUser,
    this.errorMessage,
  });

  final AuthResponse? response;
  final User? authenticatedUser;
  final String? errorMessage;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn(String identifier, String password) async {
    final trimmed = identifier.trim();
    AuthResponse? response;

    Future<void> signInWithLegacyId(String employeeId) async {
      final aliases = [
        if (RegExp(r'^\d{8}$').hasMatch(employeeId))
          accountLoginEmail(employeeId),
        employeeLoginEmail(employeeId),
        'employee-$employeeId@employee-login.invalid',
      ];
      AuthException? lastAuthError;
      for (final alias in aliases) {
        try {
          response = await _client.auth.signInWithPassword(
            email: alias,
            password: password,
          );
          return;
        } on AuthException catch (error) {
          lastAuthError = error;
        }
      }
      throw lastAuthError!;
    }

    if (trimmed.contains('@')) {
      response = await _client.auth.signInWithPassword(
        email: trimmed.toLowerCase(),
        password: password,
      );
    } else if (looksLikePhoneNumber(trimmed)) {
      try {
        response = await _client.auth.signInWithPassword(
          phone: normalizeAuthPhone(trimmed),
          password: password,
        );
      } on AuthException catch (error) {
        final message = error.message.toLowerCase();
        if (!RegExp(r'^\d{8}$').hasMatch(trimmed) ||
            (!message.contains('invalid') &&
                !message.contains('credentials'))) {
          rethrow;
        }
        await signInWithLegacyId(cleanEmployeeId(trimmed));
      }
    } else {
      await signInWithLegacyId(cleanEmployeeId(trimmed));
    }

    final result = response;
    if (result == null) {
      throw const AuthException('Authentication returned no response.');
    }
    return result;
  }

  Future<AuthRegistrationResult> register({
    required String name,
    required String identifier,
    required String organisationName,
    required String password,
  }) async {
    final trimmedIdentifier = identifier.trim();
    if (RegExp(r'^\d{8}$').hasMatch(trimmedIdentifier)) {
      if (organisationName.trim().isEmpty) {
        throw const FormatException(
          'Enter an organisation name for an 8-digit ID account.',
        );
      }
      await _client.rpc(
        'create_owner_account',
        params: {
          'p_name': name.trim(),
          'p_login_id': cleanAccountId(trimmedIdentifier),
          'p_password': password,
          'p_organisation_name': organisationName.trim(),
        },
      );
      final response = await _client.auth.signInWithPassword(
        email: accountLoginEmail(trimmedIdentifier),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException(
          'Account created but sign-in returned no user.',
        );
      }
      return AuthRegistrationResult(authenticatedUser: user);
    }

    final isEmail = trimmedIdentifier.contains('@');
    final normalizedIdentifier = isEmail
        ? trimmedIdentifier.toLowerCase()
        : normalizeAuthPhone(trimmedIdentifier);
    final response = isEmail
        ? await _client.auth.signUp(
            email: normalizedIdentifier,
            password: password,
            data: {'full_name': name.trim()},
          )
        : await _client.auth.signUp(
            phone: normalizedIdentifier,
            password: password,
            data: {'full_name': name.trim()},
          );
    if (response.user == null) {
      throw const AuthException('Registration returned no user.');
    }
    if (response.session != null) {
      return AuthRegistrationResult(
        response: response,
        authenticatedUser: response.user,
      );
    }

    try {
      final loginResponse = isEmail
          ? await _client.auth.signInWithPassword(
              email: normalizedIdentifier,
              password: password,
            )
          : await _client.auth.signInWithPassword(
              phone: normalizedIdentifier,
              password: password,
            );
      return AuthRegistrationResult(
        response: response,
        authenticatedUser: loginResponse.user,
      );
    } on AuthException {
      return AuthRegistrationResult(
        response: response,
        errorMessage: "Compte créé. Supabase exige la confirmation d'email : désactivez 'Confirm email' dans Supabase (Authentication > Providers > Email) ou exécutez le script SQL.",
      );
    }
  }

  Future<AuthResponse> verifyPhoneSignup({
    required String phone,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: normalizeAuthPhone(phone),
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return AuthRepository(client);
});
