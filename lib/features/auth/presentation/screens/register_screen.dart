import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zone/core/widgets/widgets.dart';
import 'package:zone/features/auth/domain/auth_formatters.dart';
import 'package:zone/providers/app_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _organisationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _message;
  bool _phoneVerificationRequired = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _organisationController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _message = null);
    try {
      final response = await ref
          .read(appStateProvider.notifier)
          .register(
            name: _nameController.text,
            identifier: _identifierController.text,
            organisationName: _organisationController.text,
            password: _passwordController.text,
          );
      if (response == null) return;
      if (!mounted) return;
      if (response.session == null) {
        setState(() {
          _phoneVerificationRequired = looksLikePhoneNumber(
            _identifierController.text,
          );
          _message = _phoneVerificationRequired
              ? 'Enter the 6-digit code sent by SMS.'
              : ref.read(appStateProvider).errorMessage ??
                    'Account created. Confirm your email before signing in.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = ref.read(appStateProvider).errorMessage);
      }
    }
  }

  Future<void> _verifyPhone() async {
    if (_otpController.text.trim().length != 6) {
      setState(() => _message = 'Enter the 6-digit SMS code.');
      return;
    }
    try {
      await ref
          .read(appStateProvider.notifier)
          .verifyPhoneSignup(
            phone: _identifierController.text,
            token: _otpController.text,
          );
    } catch (_) {
      if (mounted) {
        setState(() => _message = ref.read(appStateProvider).errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email, phone number, or 8-digit ID',
                    hintText: 'name@example.com, +21695125268, or 95125268',
                    prefixIcon: Icon(Icons.contact_mail_outlined),
                  ),
                  validator: (value) {
                    final identifier = value?.trim() ?? '';
                    if (identifier.isEmpty) {
                      return 'Enter an email, phone number, or 8-digit ID';
                    }
                    if (identifier.contains('@')) {
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(identifier)
                          ? null
                          : 'Enter a valid email address';
                    }
                    if (RegExp(r'^\d{8}$').hasMatch(identifier)) return null;
                    try {
                      normalizeAuthPhone(identifier);
                      return null;
                    } on FormatException catch (error) {
                      return error.message;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _organisationController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Organisation name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  validator: (value) =>
                      RegExp(r'^\d{8}$')
                              .hasMatch(_identifierController.text.trim()) &&
                          (value == null || value.trim().isEmpty)
                      ? 'Enter your organisation name for an 8-digit ID account'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (at least 6 characters)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'Use at least 6 characters'
                      : null,
                ),
                if (_phoneVerificationRequired) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'SMS verification code',
                      prefixIcon: Icon(Icons.sms_outlined),
                    ),
                  ),
                  FilledButton(
                    onPressed: appState.isLoading ? null : _verifyPhone,
                    child: const Text('Verify phone'),
                  ),
                ],
                if (_message != null || appState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _message ?? appState.errorMessage!,
                        style: TextStyle(
                          color:
                              (_message?.contains('Check your email') ?? false)
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  onPressed: appState.isLoading ? null : _register,
                  isLoading: appState.isLoading,
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
