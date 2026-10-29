import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/providers/app_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    // Clear any previous error
    ref.read(appStateProvider.notifier).clearError();
    await ref
        .read(appStateProvider.notifier)
        .signIn(_identifierController.text.trim(), _passwordController.text);
    // Error (if any) will be shown via appStateProvider.errorMessage
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Center(child: CHEFLogo()),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: '8-digit ID',
                      hintText: '95125268',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      try {
                        cleanAccountId(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password'
                        : null,
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  if (appState.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          appState.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: appState.isLoading ? null : _signIn,
                    icon: appState.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(appState.isLoading ? 'Signing in…' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Create one'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _loginIdController = TextEditingController();
  final _organisationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _loginIdController.dispose();
    _organisationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _message = null);
    try {
      await ref
          .read(appStateProvider.notifier)
          .register(
            name: _nameController.text,
            loginId: _loginIdController.text,
            organisationName: _organisationController.text,
            password: _passwordController.text,
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
                  controller: _loginIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Owner ID (8 digits)',
                    hintText: '95125268',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    try {
                      cleanAccountId(value ?? '');
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
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your organisation name'
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
                if (_message != null || appState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _message ?? appState.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: appState.isLoading ? null : _register,
                  child: appState.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
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

class CHEFLogo extends StatelessWidget {
  const CHEFLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: 44,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
