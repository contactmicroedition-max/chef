import 'package:flutter/material.dart';
import 'package:zone/core/widgets/paginated_list.dart';
import 'package:zone/features/organisations/domain/organisation.dart';

typedef OrganisationSelectionCallback = Future<void> Function(
  BuildContext dialogContext,
  Organisation organisation,
);

class OrganisationSwitcherDialog extends StatelessWidget {
  const OrganisationSwitcherDialog({
    super.key,
    required this.organisations,
    required this.selectedOrganisationId,
    required this.onSelect,
  });

  final List<Organisation> organisations;
  final String? selectedOrganisationId;
  final OrganisationSelectionCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose organisation'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: SingleChildScrollView(
          child: PaginatedList(
            items: organisations,
            itemBuilder: (context, organisation, index) => ListTile(
              leading: const Icon(Icons.business_rounded),
              title: Text(organisation.name),
              trailing: organisation.id == selectedOrganisationId
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await onSelect(context, organisation);
              },
            ),
          ),
        ),
      ),
    );
  }
}
