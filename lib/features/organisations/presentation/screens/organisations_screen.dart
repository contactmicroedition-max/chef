import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zone/core/widgets/paginated_list.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/organisations/data/organisations_repository.dart';
import 'package:zone/features/organisations/domain/organisation.dart';
import 'package:zone/providers/app_state.dart';

class OrganisationsScreen extends ConsumerStatefulWidget {
  const OrganisationsScreen({super.key});

  @override
  ConsumerState<OrganisationsScreen> createState() =>
      _OrganisationsScreenState();
}

class _OrganisationsScreenState extends ConsumerState<OrganisationsScreen> {
  late Future<List<Organisation>> _organisations;

  @override
  void initState() {
    super.initState();
    _organisations = _loadOrganisations();
  }

  Future<List<Organisation>> _loadOrganisations() {
    return ref.read(organisationsRepositoryProvider).listMyOrganisations();
  }

  Future<void> _refresh() async {
    setState(() => _organisations = _loadOrganisations());
    try {
      await _organisations;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh organisations: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        ref.watch(appStateProvider).currentRole == EmployeeRole.owner;
    if (!isOwner) {
      return const Center(
        child: Text('Only organisation owners can view this page.'),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Organisation>>(
          future: _organisations,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load organisations: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _organisations = _loadOrganisations()),
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final organisations = snapshot.data!;
            if (organisations.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.business_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Center(child: Text('No owned organisations yet.')),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PaginatedList(
                  items: organisations,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, organisation, index) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.business_rounded),
                        title: Text(organisation.name),
                        subtitle: Text(
                          '${organisation.status} · ${organisation.hasWorkZone ? 'Work zone set' : 'Work zone missing'}',
                        ),
                        trailing: Icon(
                          organisation.hasWorkZone
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                          color: organisation.hasWorkZone
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        onTap: () async {
                          await context.push(
                            '/organisations/${organisation.id}/zone',
                            extra: organisation,
                          );
                          if (mounted) await _refresh();
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/organisations/new');
          if (mounted) await _refresh();
        },
        tooltip: 'Add organisation',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
