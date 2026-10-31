import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:zone/core/widgets/app_button.dart';
import 'package:zone/features/organisations/data/organisations_repository.dart';
import 'package:zone/features/organisations/domain/organisation.dart';
import 'package:zone/features/organisations/domain/organisation_draft.dart';
import 'package:zone/features/organisations/presentation/controllers/organisation_zone_controller.dart';
import 'package:zone/features/organisations/presentation/widgets/organisation_zone_map.dart';
import 'package:zone/providers/app_state.dart';

class OrganisationZoneScreen extends ConsumerStatefulWidget {
  const OrganisationZoneScreen({
    super.key,
    this.draft,
    this.organisationId,
    this.organisation,
    this.returnToHome = false,
  });

  final OrganisationDraft? draft;
  final String? organisationId;
  final Organisation? organisation;
  final bool returnToHome;

  @override
  ConsumerState<OrganisationZoneScreen> createState() =>
      _OrganisationZoneScreenState();
}

class _OrganisationZoneScreenState
    extends ConsumerState<OrganisationZoneScreen> {
  final _mapController = MapController();
  final _zoneController = OrganisationZoneController();
  final _mapSearchController = TextEditingController();
  final _mapKey = GlobalKey();
  Timer? _searchDebounce;
  List<_GeocodingResult> _searchResults = [];
  String? _errorMessage;
  String? _searchError;
  bool _isLoadingZone = false;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isDrawing = true;
  bool _mapReady = false;
  int _searchGeneration = 0;

  bool get _isEditing => widget.organisationId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadZone();
    }
    _mapSearchController.addListener(_scheduleSearch);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapSearchController
      ..removeListener(_scheduleSearch)
      ..dispose();
    _zoneController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadZone() async {
    setState(() => _isLoadingZone = true);
    try {
      final zone = await ref
          .read(organisationsRepositoryProvider)
          .getZone(widget.organisationId!);
      if (zone == null) return;
      for (final point in zone.points) {
        _zoneController.addPoint(point);
      }
      if (_mapReady && zone.points.isNotEmpty) {
        _mapController.move(zone.points.first, 16);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingZone = false);
    }
  }

  void _onMapReady() {
    _mapReady = true;
    final points = _zoneController.points;
    if (points.isNotEmpty) _mapController.move(points.first, 16);
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    final generation = ++_searchGeneration;
    final query = _mapSearchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchLocations(query, generation),
    );
  }

  Future<void> _searchLocations(String query, int generation) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '6',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'com.example.zone'},
      );
      if (response.statusCode != 200) {
        throw HttpException(
          'Location search returned status ${response.statusCode}.',
        );
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['features'] is! List) {
        throw const FormatException('Location search response is invalid.');
      }
      final results = (payload['features'] as List)
          .whereType<Map>()
          .map(_GeocodingResult.fromFeature)
          .whereType<_GeocodingResult>()
          .toList();
      if (mounted && generation == _searchGeneration) {
        setState(() => _searchResults = results);
      }
    } catch (error) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searchError = error.toString());
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _locateMe() async {
    setState(() => _errorMessage = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Enable location services to locate this device.');
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
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  void _selectSearchResult(_GeocodingResult result) {
    _mapSearchController.text = result.label;
    _searchDebounce?.cancel();
    setState(() => _searchResults = []);
    _mapController.move(result.point, 16);
  }

  Future<void> _save() async {
    if (!_zoneController.isValid || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      if (_isEditing) {
        await ref
            .read(organisationsRepositoryProvider)
            .updateZone(
              organisationId: widget.organisationId!,
              zone: _zoneController.zone,
            );
      } else {
        final draft = widget.draft;
        if (draft == null) {
          throw StateError('Organisation details are missing.');
        }
        await ref
            .read(appStateProvider.notifier)
            .createOrganisationWithZone(
              draft: draft,
              zone: _zoneController.zone,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Work zone updated.' : 'Organisation created.',
          ),
        ),
      );
      if (widget.returnToHome) {
        context.go('/home');
      } else {
        context.pop();
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _mapSearchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search for a place',
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_searchError != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _searchError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_searchResults.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final result in _searchResults)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(result.label),
                        onTap: () => _selectSearchResult(result),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorControls() {
    return AnimatedBuilder(
      animation: _zoneController,
      builder: (context, child) {
        final validationError = _zoneController.validationError;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      validationError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _zoneController.points.isEmpty
                          ? null
                          : () {
                              _zoneController.undo();
                              setState(() => _isDrawing = true);
                            },
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Undo'),
                    ),
                    TextButton.icon(
                      onPressed: _zoneController.points.isEmpty
                          ? null
                          : () {
                              _zoneController.clear();
                              setState(() => _isDrawing = true);
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Clear'),
                    ),
                    TextButton.icon(
                      onPressed: _zoneController.isValid
                          ? () => setState(() => _isDrawing = false)
                          : null,
                      icon: const Icon(Icons.done_rounded),
                      label: const Text('Finish'),
                    ),
                    IconButton(
                      tooltip: 'Locate me',
                      onPressed: _locateMe,
                      icon: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
                AppButton(
                  onPressed: _isLoadingZone || !_zoneController.isValid
                      ? null
                      : _save,
                  isLoading: _isSaving,
                  icon: const Icon(Icons.save_rounded),
                  child: Text(
                    _isEditing ? 'Save work zone' : 'Create organisation',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final organisationName =
        widget.organisation?.name ?? widget.draft?.name ?? 'organisation';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit work zone' : 'Set work zone'),
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: Stack(
              key: _mapKey,
              children: [
                OrganisationZoneMap(
                  mapController: _mapController,
                  zoneController: _zoneController,
                  isDrawing: _isDrawing,
                  onMapReady: _onMapReady,
                ),
                PositionedDirectional(
                  start: 16,
                  bottom: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _isDrawing
                            ? 'Tap the map to draw $organisationName\'s work zone.'
                            : 'Drag points to adjust the finished work zone.',
                      ),
                    ),
                  ),
                ),
                if (_isLoadingZone)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          _buildEditorControls(),
        ],
      ),
    );
  }
}

class _GeocodingResult {
  const _GeocodingResult({required this.label, required this.point});

  final String label;
  final LatLng point;

  static _GeocodingResult? fromFeature(Map feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map ||
        geometry is! Map ||
        geometry['coordinates'] is! List) {
      return null;
    }
    final coordinates = geometry['coordinates'] as List;
    if (coordinates.length < 2 ||
        coordinates[0] is! num ||
        coordinates[1] is! num) {
      return null;
    }
    final label = properties['name'] is String
        ? properties['name'] as String
        : properties['label'] is String
        ? properties['label'] as String
        : '';
    if (label.isEmpty) return null;
    return _GeocodingResult(
      label: label,
      point: LatLng(
        (coordinates[1] as num).toDouble(),
        (coordinates[0] as num).toDouble(),
      ),
    );
  }
}

class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}
