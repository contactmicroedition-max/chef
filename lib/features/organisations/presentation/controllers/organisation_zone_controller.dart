import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

class OrganisationZoneController extends ChangeNotifier {
  OrganisationZoneController({List<LatLng> initialPoints = const []})
    : _points = List.of(initialPoints);

  final List<LatLng> _points;

  List<LatLng> get points => List.unmodifiable(_points);
  int get polygonCount => _points.length >= 3 ? 1 : 0;
  OrganisationZone get zone => OrganisationZone(points: points);
  String? get validationError => zone.validationError;
  bool get isValid => zone.isValid;

  void addPoint(LatLng point) {
    _points.add(point);
    notifyListeners();
  }

  void movePoint(int index, LatLng point) {
    _points[index] = point;
    notifyListeners();
  }

  void undo() {
    if (_points.isEmpty) return;
    _points.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_points.isEmpty) return;
    _points.clear();
    notifyListeners();
  }
}
