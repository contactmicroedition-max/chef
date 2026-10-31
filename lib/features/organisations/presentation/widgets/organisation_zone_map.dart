import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/core/config/map_config.dart';
import 'package:zone/features/organisations/presentation/controllers/organisation_zone_controller.dart';

class OrganisationZoneMap extends StatefulWidget {
  const OrganisationZoneMap({
    super.key,
    required this.mapController,
    required this.zoneController,
    required this.isDrawing,
    required this.onMapReady,
  });

  final MapController mapController;
  final OrganisationZoneController zoneController;
  final bool isDrawing;
  final VoidCallback onMapReady;

  @override
  State<OrganisationZoneMap> createState() => _OrganisationZoneMapState();
}

class _OrganisationZoneMapState extends State<OrganisationZoneMap> {
  final _mapKey = GlobalKey();

  LatLng? _latLngAt(Offset globalPosition) {
    final renderObject = _mapKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final localPosition = renderObject.globalToLocal(globalPosition);
    return widget.mapController.camera.screenOffsetToLatLng(localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.zoneController,
      builder: (context, child) {
        final points = widget.zoneController.points;
        return FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: points.isEmpty
                ? const LatLng(36.8, 10.18)
                : points.first,
            initialZoom: points.isEmpty ? 12 : 16,
            onMapReady: widget.onMapReady,
            onTap: widget.isDrawing
                ? (tapPosition, point) => widget.zoneController.addPoint(point)
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: organisationMapTileUrlTemplate,
              userAgentPackageName: 'com.example.zone',
            ),
            if (points.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: points,
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.2),
                    borderColor: Theme.of(context).colorScheme.primary,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (var index = 0; index < points.length; index++)
                  Marker(
                    point: points[index],
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final point = _latLngAt(details.globalPosition);
                        if (point != null) {
                          widget.zoneController.movePoint(index, point);
                        }
                      },
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
