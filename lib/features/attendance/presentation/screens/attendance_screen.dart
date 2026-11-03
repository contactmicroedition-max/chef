import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/core/widgets/paginated_list.dart';
import 'package:zone/features/attendance/presentation/widgets/attendance_card.dart';
import 'package:zone/features/attendance/presentation/widgets/attendance_location_panel.dart';
import 'package:zone/features/attendance/presentation/widgets/shift_attendance_groups.dart';
import 'package:zone/features/attendance/data/attendance_repository.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';
import 'package:zone/providers/app_state.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isRecording = false;
  bool _isLocationLoading = false;
  String? _locationError;
  String? _loadedOrganisationId;
  OrganisationZone? _zone;
  Position? _position;
  StreamSubscription<Position>? _positionSubscription;
  final _shiftGroupsKey = GlobalKey<ShiftAttendanceGroupsState>();

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _recordShift(bool clockIn, Position? position) async {
    if (clockIn && position == null) {
      setState(
        () => _locationError = 'Current location is required to clock in.',
      );
      return;
    }
    setState(() => _isRecording = true);
    try {
      final notificationMessage = await ref
          .read(appStateProvider.notifier)
          .recordEmployeeShift(
            clockIn: clockIn,
            latitude: position?.latitude,
            longitude: position?.longitude,
          );
      if (!mounted) return;
      final action = clockIn ? 'Clocked in' : 'Clocked out';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationMessage == null
                ? '$action successfully. The organisation admins were notified.'
                : '$action successfully. $notificationMessage',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _refreshAttendance() async {
    try {
      await ref.read(appStateProvider.notifier).refreshAttendance();
      await _shiftGroupsKey.currentState?.reload();
      if (!mounted) return;
      if (ref.read(appStateProvider).currentRole == EmployeeRole.employee) {
        final organisationId = ref
            .read(appStateProvider)
            .selectedOrganisationId;
        if (organisationId != null) await _loadLocationFor(organisationId);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh attendance: $error')),
      );
    }
  }

  Future<void> _loadLocationFor(String organisationId) async {
    _loadedOrganisationId = organisationId;
    _positionSubscription?.cancel();
    setState(() {
      _isLocationLoading = true;
      _locationError = null;
      _zone = null;
      _position = null;
    });

    try {
      final zone = await ref
          .read(attendanceRepositoryProvider)
          .employeeWorkZone(organisationId);
      if (!mounted || _loadedOrganisationId != organisationId) return;
      setState(() => _zone = zone);
    } catch (error) {
      if (mounted && _loadedOrganisationId == organisationId) {
        setState(() => _locationError = error.toString());
      }
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Enable location services to check your work zone.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is disabled. Enable it in app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted || _loadedOrganisationId != organisationId) return;
      setState(() {
        _position = position;
        if (_zone != null) _locationError = null;
      });
      _listenForLocationUpdates(organisationId);
    } catch (error) {
      if (mounted && _loadedOrganisationId == organisationId) {
        setState(() => _locationError = error.toString());
      }
    } finally {
      if (mounted && _loadedOrganisationId == organisationId) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  void _listenForLocationUpdates(String organisationId) {
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (position) {
            if (!mounted || _loadedOrganisationId != organisationId) return;
            setState(() => _position = position);
          },
          onError: (Object error) {
            if (mounted && _loadedOrganisationId == organisationId) {
              setState(() => _locationError = error.toString());
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final isEmployee = state.currentRole == EmployeeRole.employee;
    final organisationId = state.selectedOrganisationId;
    if (isEmployee &&
        organisationId != null &&
        organisationId != _loadedOrganisationId) {
      _loadedOrganisationId = organisationId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLocationFor(organisationId);
      });
    } else if ((!isEmployee || organisationId == null) &&
        _loadedOrganisationId != null) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _loadedOrganisationId = null;
    }

    final employeeId = state.currentEmployeeId;
    final employee = state.employees
        .where((item) => item.id == employeeId)
        .firstOrNull;
    final openShift = state.attendance
        .where(
          (record) =>
              record.employeeId == employeeId && record.clockOut == null,
        )
        .firstOrNull;

    // Filter attendance by role
    final records = state.currentRole == EmployeeRole.employee
        ? state.attendance.where((r) => r.employeeId == employeeId).toList()
        : state.attendance;

    return RefreshIndicator(
      onRefresh: _refreshAttendance,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Attendance', style: Theme.of(context).textTheme.headlineSmall),
          if (state.currentRole == EmployeeRole.employee &&
              state.currentEmployeeId != null) ...[
            const SizedBox(height: 12),
            if (openShift != null)
              Card(
                color: openShift.approvalStatus == 'pending'
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            openShift.approvalStatus == 'pending'
                                ? Icons.warning_amber_rounded
                                : Icons.timer_rounded,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Shift started ${formatDateTime(openShift.clockIn)}',
                          ),
                        ],
                      ),
                      if (openShift.approvalStatus == 'pending') ...[
                        const SizedBox(height: 8),
                        Text(
                          'You are assigned to ${openShift.assignedShiftName ?? 'another shift'}, '
                          'but clocked in during ${openShift.shiftName ?? 'a different shift'}. '
                          'An admin must approve your attendance.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            AttendanceLocationPanel(
              zone: _zone,
              position: _position,
              isInsideZone:
                  _zone?.containsPoint(
                    _position == null
                        ? const LatLng(0, 0)
                        : LatLng(_position!.latitude, _position!.longitude),
                  ) ??
                  false,
              isLoading: _isLocationLoading,
              isRecording: _isRecording,
              hasOpenShift: openShift != null,
              hasAssignedShift: employee?.shiftId != null,
              errorMessage: _locationError,
              onRefreshLocation: () {
                if (organisationId != null) _loadLocationFor(organisationId);
              },
              onRecordShift: _recordShift,
            ),
          ],
          const SizedBox(height: 12),
          if (state.currentRole == EmployeeRole.owner ||
              state.currentRole == EmployeeRole.manager)
            organisationId == null
                ? const SizedBox.shrink()
                : ShiftAttendanceGroups(
                    key: _shiftGroupsKey,
                    organisationId: organisationId,
                    records: records,
                    employees: state.employees,
                  )
          else if (records.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No attendance records yet.'),
              ),
            )
          else
            PaginatedList(
              items: records,
              itemBuilder: (context, record, index) =>
                  AttendanceCard(record: record),
            ),
        ],
      ),
    );
  }
}
