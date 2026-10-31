import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/widgets/widgets.dart';
import 'package:zone/features/auth/domain/auth_formatters.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

class AddEmployeeDialog extends ConsumerStatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  ConsumerState<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _loginEmail = TextEditingController();
  final _jobTitle = TextEditingController();
  final _salaryAmount = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _emailEdited = false;
  EmployeePayType _payType = EmployeePayType.hourly;

  void _updateGeneratedEmail(String name, String organisationName) {
    if (_emailEdited) return;
    final baseEmail = employeeEmailAddress(name, organisationName);
    var email = baseEmail;
    var suffix = 2;
    final existingEmails = ref
        .read(appStateProvider)
        .employees
        .map((employee) => employee.loginEmail?.toLowerCase())
        .whereType<String>()
        .toSet();
    while (existingEmails.contains(email)) {
      email = employeeEmailAddress(name, organisationName, suffix: suffix++);
    }
    _loginEmail.value = TextEditingValue(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _loginEmail.dispose();
    _jobTitle.dispose();
    _salaryAmount.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final createdLoginEmail = await ref
          .read(appStateProvider.notifier)
          .createEmployee(
            name: _name.text,
            loginEmail: _loginEmail.text,
            jobTitle: _jobTitle.text,
            payType: _payType,
            salaryAmount: double.parse(_salaryAmount.text),
            password: _password.text,
          );
      _loginEmail.text = createdLoginEmail;
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add employee'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                onChanged: (name) => _updateGeneratedEmail(
                  name,
                  ref.read(appStateProvider).selectedOrganisation?.name ?? '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              TextFormField(
                controller: _loginEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Employee login email',
                  helperText:
                      'Generated from the employee and organisation names.',
                ),
                onChanged: (_) => _emailEdited = true,
                validator: (value) {
                  try {
                    cleanEmployeeEmail(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EmployeePayType>(
                initialValue: _payType,
                decoration: const InputDecoration(labelText: 'Pay type'),
                items: const [
                  DropdownMenuItem(
                    value: EmployeePayType.hourly,
                    child: Text('Paid by hour'),
                  ),
                  DropdownMenuItem(
                    value: EmployeePayType.monthly,
                    child: Text('Fixed monthly salary'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (payType) {
                        if (payType != null) {
                          setState(() => _payType = payType);
                        }
                      },
              ),
              DialogFormField(controller: _jobTitle, label: 'Job title'),
              DialogFormField(
                controller: _salaryAmount,
                label: _payType == EmployeePayType.hourly
                    ? 'Hourly wage'
                    : 'Monthly salary',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || !amount.isFinite || amount <= 0
                      ? 'Enter an amount greater than zero'
                      : null;
                },
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Initial password (min 8 chars)',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'The employee signs in with this email and the password you set.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
