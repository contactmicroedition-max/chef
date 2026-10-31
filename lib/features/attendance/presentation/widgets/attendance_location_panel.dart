import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/core/config/map_config.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

class AttendanceLocationPanel extends StatefulWidget {
  const AttendanceLocationPanel({
    super.key,
    required this.zone,
    required this.position,
    required this.isInsideZone,
    required this.isLoading,
    required this.isRecording,
    required this.hasOpenShift,
    required this.errorMessage,
    required this.onRefreshLocation,
    required this.onRecordShift,
  });

  final OrganisationZone? zone;
  final Position? position;
  final bool isInsideZone;
  final bool isLoading;
  final bool isRecording;
  final bool hasOpenShift;
  final String? errorMessage;
  final VoidCallback onRefreshLocation;
  final Future<void> Function(bool clockIn, Position? position) onRecordShift;

  @override
  State<AttendanceLocationPanel> createState() =>
      _AttendanceLocationPanelState();
}

class _AttendanceLocationPanelState extends State<AttendanceLocationPanel> {
  final _mapController = MapController();
  bool _mapReady = false;

  @override
  void didUpdateWidget(covariant AttendanceLocationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady && oldWidget.position == null && widget.position != null) {
      _fitZoneAndPosition();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _pointFromPosition(Position position) =>
      LatLng(position.latitude, position.longitude);

  void _fitZoneAndPosition() {
    final points = [
      ...?widget.zone?.points,
      if (widget.position != null) _pointFromPosition(widget.position!),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.single, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(32),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInside = widget.isInsideZone && widget.position != null;
    final zoneColor = isInside
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final initialCenter = widget.position != null
        ? _pointFromPosition(widget.position!)
        : widget.zone?.points.firstOrNull ?? const LatLng(36.8, 10.18);
    final canClockIn =
        widget.hasOpenShift || (isInside && widget.position != null);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: widget.position == null ? 14 : 16,
                    onMapReady: () {
                      _mapReady = true;
                      _fitZoneAndPosition();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: organisationMapTileUrlTemplate,
                      userAgentPackageName: 'com.example.zone',
                    ),
                    if (widget.zone != null && widget.zone!.points.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: widget.zone!.points,
                            color: zoneColor.withValues(alpha: 0.22),
                            borderColor: zoneColor,
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                    if (widget.position != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pointFromPosition(widget.position!),
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.person_pin_circle_rounded,
                              color: theme.colorScheme.secondary,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                PositionedDirectional(
                  end: 8,
                  top: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Refresh my location',
                    onPressed: widget.isLoading
                        ? null
                        : widget.onRefreshLocation,
                    icon: widget.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 12,
                  child: FilledButton.icon(
                    onPressed: widget.isRecording || !canClockIn
                        ? null
                        : () => widget.onRecordShift(
                            !widget.hasOpenShift,
                            widget.position,
                          ),
                    icon: Icon(
                      widget.hasOpenShift
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      widget.isRecording
                          ? 'Recording…'
                          : widget.hasOpenShift
                          ? 'Clock out'
                          : 'Clock in',
                    ),
                  ),
                ),
                if (widget.isLoading && widget.zone == null)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  isInside ? Icons.check_circle_rounded : Icons.location_off,
                  color: zoneColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.position == null
                        ? widget.hasOpenShift
                              ? 'Your shift is open. You can clock out from here.'
                              : 'Location is required to clock in.'
                        : isInside
                        ? 'You are inside the work zone.'
                        : widget.hasOpenShift
                        ? 'You are outside the work zone. Clock-out is still available.'
                        : 'You must be inside the work zone to register your presence.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: widget.position != null && !isInside
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                widget.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
