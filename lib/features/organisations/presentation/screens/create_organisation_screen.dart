import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zone/core/widgets/app_button.dart';
import 'package:zone/core/widgets/dialog_form_field.dart';
import 'package:zone/features/organisations/domain/organisation_draft.dart';

class CreateOrganisationScreen extends StatefulWidget {
  const CreateOrganisationScreen({super.key});

  @override
  State<CreateOrganisationScreen> createState() =>
      _CreateOrganisationScreenState();
}

class _CreateOrganisationScreenState extends State<CreateOrganisationScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final logoUrlController = TextEditingController();
  final timezoneController = TextEditingController(text: 'Africa/Tunis');
  String _currency = 'TND';

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    logoUrlController.dispose();
    timezoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isInitialSetup =
        GoRouterState.of(context).matchedLocation == '/org-setup';
    final draft = OrganisationDraft(
      name: nameController.text.trim(),
      address: addressController.text,
      phone: phoneController.text,
      logoUrl: logoUrlController.text,
      currency: _currency,
      timezone: timezoneController.text.trim(),
    );
    context.push(
      isInitialSetup ? '/org-setup/zone' : '/organisations/new/zone',
      extra: draft,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create organisation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'New organisation',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Create your business to start managing employees.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            DialogFormField(
              controller: nameController,
              label: 'Organisation name',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an organisation name'
                  : null,
            ),
            DialogFormField(
              controller: addressController,
              label: 'Address (optional)',
              validator: (_) => null,
            ),
            DialogFormField(
              controller: phoneController,
              label: 'Phone (optional)',
              keyboardType: TextInputType.phone,
              validator: (_) => null,
            ),
            DialogFormField(
              controller: logoUrlController,
              label: 'Logo URL (optional)',
              keyboardType: TextInputType.url,
              validator: (_) => null,
            ),
            DialogFormField(
              controller: timezoneController,
              label: 'Timezone',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a timezone'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              items: const [
                DropdownMenuItem(
                  value: 'TND',
                  child: Text('TND - Tunisian dinar'),
                ),
                DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                DropdownMenuItem(value: 'USD', child: Text('USD - Dollar')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
              decoration: const InputDecoration(
                labelText: 'Currency',
                prefixIcon: Icon(Icons.currency_exchange_rounded),
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: _save,
              icon: const Icon(Icons.arrow_forward_rounded),
              child: const Text('Continue to work zone'),
            ),
          ],
        ),
      ),
    );
  }
}
