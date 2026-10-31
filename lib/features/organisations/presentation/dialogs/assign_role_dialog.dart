import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/widgets/dialog_form_field.dart';
import 'package:zone/features/auth/domain/auth_formatters.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

class AssignRoleDialog extends ConsumerStatefulWidget {
  const AssignRoleDialog({super.key});

  @override
  ConsumerState<AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends ConsumerState<AssignRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _loginId.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(appStateProvider.notifier)
          .assignOrganisationRole(
            loginIdentifier: _loginId.text,
            role: EmployeeRole.manager,
          );
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
      title: const Text('Assign manager access'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogFormField(
              controller: _loginId,
              label: 'Employee email or legacy ID',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().contains('@')) {
                  try {
                    cleanEmployeeEmail(value);
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                }
                try {
                  cleanAccountId(value ?? '');
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _assign,
          child: Text(_saving ? 'Assigning…' : 'Assign role'),
        ),
      ],
    );
  }
}
