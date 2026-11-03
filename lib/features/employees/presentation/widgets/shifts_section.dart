import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/widgets/paginated_list.dart';
import 'package:zone/features/employees/data/shifts_repository.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/domain/work_shift.dart';
import 'package:zone/features/employees/presentation/dialogs/work_shift_dialog.dart';
import 'package:zone/providers/app_state.dart';

class ShiftsSection extends ConsumerStatefulWidget {
  const ShiftsSection({super.key, this.onShiftsChanged});

  final VoidCallback? onShiftsChanged;

  @override
  ConsumerState<ShiftsSection> createState() => _ShiftsSectionState();
}

class _ShiftsSectionState extends ConsumerState<ShiftsSection> {
  String? _organisationId;
  List<WorkShift> _shifts = [];
  Object? _loadError;
  bool _isLoading = true;
  bool _isSaving = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _organisationId = ref.read(appStateProvider).selectedOrganisationId;
    Future.microtask(() => _loadShifts(_organisationId));
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final canManageShifts =
        appState.currentRole == EmployeeRole.owner ||
        appState.currentRole == EmployeeRole.manager;
    final organisationId = appState.selectedOrganisationId;
    ref.listen(
      appStateProvider.select((state) => state.selectedOrganisationId),
      (previous, next) {
        if (previous != next) {
          _organisationId = next;
          _loadShifts(next);
        }
      },
    );

    final totalMinutes = _shifts.fold<int>(
      0,
      (total, shift) => total + shift.durationMinutes,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Shifts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (canManageShifts && organisationId != null)
              FilledButton.icon(
                onPressed: _isSaving || totalMinutes >= 24 * 60
                    ? null
                    : () => _editShift(organisationId),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add shift'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Total duration: ${_formatDuration(totalMinutes)} / 24 hours',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (organisationId == null)
          const Card(
            child: ListTile(
              title: Text('Select an organisation to view its shifts.'),
            ),
          )
        else if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Card(
            child: ListTile(
              title: Text('Could not load shifts: $_loadError'),
              trailing: IconButton(
                tooltip: 'Retry loading shifts',
                onPressed: () => _loadShifts(organisationId),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          )
        else if (_shifts.isEmpty)
          const Card(
            child: ListTile(title: Text('No shifts have been defined yet.')),
          )
        else
          PaginatedList<WorkShift>(
            key: ValueKey(organisationId),
            items: _shifts,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, shift, index) => Card(
              child: ListTile(
                title: Text(shift.name),
                subtitle: Text(
                  '${shift.startTimeLabel} – ${shift.endTimeLabel} · '
                  '${_formatDuration(shift.durationMinutes)}',
                ),
                trailing: canManageShifts
                    ? Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Edit ${shift.name}',
                            onPressed: _isSaving
                                ? null
                                : () => _editShift(organisationId, shift),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete ${shift.name}',
                            onPressed: _isSaving
                                ? null
                                : () => _confirmDelete(organisationId, shift),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadShifts(String? organisationId) async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _shifts = [];
      });
    }
    try {
      final shifts = organisationId == null
          ? <WorkShift>[]
          : await ref
                .read(shiftsRepositoryProvider)
                .shiftsForOrganisation(organisationId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _shifts = shifts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _editShift(String organisationId, [WorkShift? shift]) async {
    final result = await showDialog<WorkShift>(
      context: context,
      builder: (context) => WorkShiftDialog(
        organisationId: organisationId,
        shifts: _shifts,
        initialShift: shift,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(shiftsRepositoryProvider);
      if (shift == null) {
        await repository.createShift(
          organisationId: organisationId,
          name: result.name,
          startMinute: result.startMinute,
          endMinute: result.endMinute,
        );
      } else {
        await repository.updateShift(
          organisationId: organisationId,
          shift: result,
        );
      }
      await _loadShifts(organisationId);
      if (!mounted) return;
      widget.onShiftsChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shift == null ? 'Shift added.' : 'Shift updated.'),
        ),
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete(String organisationId, WorkShift shift) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shift?'),
        content: Text(
          'Delete "${shift.name}"? Employees assigned to it will become unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(shiftsRepositoryProvider)
          .deleteShift(organisationId: organisationId, shiftId: shift.id);
      await _loadShifts(organisationId);
      if (!mounted) return;
      widget.onShiftsChanged?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Shift deleted.')));
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not save shifts: $error')));
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}m';
  }
}
