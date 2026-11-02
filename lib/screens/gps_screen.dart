import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';

class DemoPlace {
  const DemoPlace(this.name, this.subtitle, this.position);
  final String name;
  final String subtitle;
  final LatLng position;
}

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  State<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Timer? _locationTimer;
  Timer? _navigationTimer;
  Position? _position;
  DemoPlace? _destination;
  MapType _mapType = MapType.normal;
  bool _loading = true;
  bool _tracking = true;
  bool _navigating = false;
  String? _error;
  int _navStep = 0;
  List<LatLng> _route = [];

  static const LatLng _fallback = LatLng(37.421998, -122.084000);
  static const List<DemoPlace> _places = [
    DemoPlace('Googleplex', '1600 Amphitheatre Pkwy', LatLng(37.4220, -122.0841)),
    DemoPlace('Computer History Museum', 'Mountain View, California', LatLng(37.4143, -122.0774)),
    DemoPlace('Shoreline Amphitheatre', 'Mountain View, California', LatLng(37.4260, -122.0800)),
    DemoPlace('Stanford University', 'Palo Alto, California', LatLng(37.4275, -122.1697)),
    DemoPlace('Dhaka University', 'Shahbag, Dhaka', LatLng(23.7339, 90.3929)),
    DemoPlace('Lalbagh Fort', 'Lalbagh, Dhaka', LatLng(23.7188, 90.3880)),
    DemoPlace('Ahsan Manzil', 'Old Dhaka', LatLng(23.7089, 90.4065)),
    DemoPlace('National Parliament House', 'Sher-e-Bangla Nagar, Dhaka', LatLng(23.7625, 90.3785)),
    DemoPlace('Ramna Park', 'Ramna, Dhaka', LatLng(23.7382, 90.4060)),
  ];

  LatLng get _currentLatLng => _position == null
      ? _fallback
      : LatLng(_position!.latitude, _position!.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _navigationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tracking) {
      _loadLocation();
      _startLocationTimer();
    } else if (state != AppLifecycleState.resumed) {
      _locationTimer?.cancel();
    }
  }

  Future<void> _loadLocation() async {
    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _position = result;
        _loading = false;
        _error = null;
      });
      _refreshRoute();
      if (_destination == null) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng, 15));
      }
      _startLocationTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is LocationServicesDisabledFailure) return 'Location service is turned off';
    if (error is LocationPermissionDeniedFailure) return 'Location permission was denied';
    if (error is LocationPermissionPermanentlyDeniedFailure) return 'Enable location permission in Settings';
    return 'Could not get GPS location. Check emulator location settings.';
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();
    if (!_tracking) return;
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final result = await _locationService.getCurrentLocation();
        if (!mounted) return;
        setState(() => _position = result);
        _refreshRoute();
      } catch (_) {

      }
    });
  }

  void _refreshRoute() {
    if (_destination == null) return;
    final start = _currentLatLng;
    final end = _destination!.position;
    final points = <LatLng>[start];
    // Demo route: interpolated line. Real road routing requires Routes API.
    for (var i = 1; i < 8; i++) {
      final t = i / 8;
      points.add(LatLng(start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t));
    }
    points.add(end);
    setState(() => _route = points);
  }

  Set<Marker> get _markers {
    final result = <Marker>{
      Marker(
        markerId: const MarkerId('current'),
        position: (_navigating && _route.isNotEmpty) ? _route[_navStep.clamp(0, _route.length - 1).toInt()] : _currentLatLng,
        infoWindow: InfoWindow(
          title: _navigating ? 'Your location' : 'Current GPS location',
          snippet: '${_currentLatLng.latitude.toStringAsFixed(5)}, ${_currentLatLng.longitude.toStringAsFixed(5)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
    if (_destination != null) {
      result.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destination!.position,
        infoWindow: InfoWindow(title: _destination!.name, snippet: _destination!.subtitle),
      ));
    }
    return result;
  }

  Set<Polyline> get _polylines => _route.isEmpty
      ? {}
      : {Polyline(polylineId: const PolylineId('demo-route'), points: _route,
          color: const Color(0xFF2878F0), width: 6, geodesic: true)};

  double get _distanceKm => _destination == null
      ? 0
      : Geolocator.distanceBetween(_currentLatLng.latitude, _currentLatLng.longitude,
          _destination!.position.latitude, _destination!.position.longitude) / 1000;

  String get _eta {
    final minutes = (_distanceKm / 30 * 60).ceil();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  void _selectPlace(DemoPlace place) {
    FocusScope.of(context).unfocus();
    _searchController.text = place.name;
    setState(() {
      _destination = place;
      _navigating = false;
      _route = [];
    });
    _refreshRoute();
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(math.min(_currentLatLng.latitude, place.position.latitude) - .01,
          math.min(_currentLatLng.longitude, place.position.longitude) - .01),
        northeast: LatLng(math.max(_currentLatLng.latitude, place.position.latitude) + .01,
          math.max(_currentLatLng.longitude, place.position.longitude) + .01)), 70));
  }

  void _startNavigation() {
    if (_destination == null) return;
    setState(() => _navigating = true);
    _navigationTimer?.cancel();
    _navStep = 0;
    _navigationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || _navStep >= _route.length - 1) {
        timer.cancel();
        if (mounted) setState(() => _navigating = false);
        return;
      }
      setState(() => _navStep++);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_route[_navStep], 16));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo navigation started. This is a simulated route.')),
    );
  }

  void _stopNavigation() {
    _navigationTimer?.cancel();
    setState(() => _navigating = false);
  }

  void _clearDestination() {
    _navigationTimer?.cancel();
    setState(() {
      _destination = null;
      _route = [];
      _navigating = false;
      _searchController.clear();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng, 15));
  }

  @override
  Widget build(BuildContext context) {
    final matches = _searchController.text.trim().isEmpty
        ? <DemoPlace>[]
        : _places.where((p) => ('${p.name} ${p.subtitle}').toLowerCase()
            .contains(_searchController.text.toLowerCase())).toList();

    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: _fallback, zoom: 15),
          onMapCreated: (controller) {
            _mapController = controller;
            if (_position != null) {
              controller.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng, 15));
            }
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: true,
          compassEnabled: true,
          mapType: _mapType,
          markers: _markers,
          polylines: _polylines,
          padding: const EdgeInsets.only(top: 100, bottom: 245),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) { if (matches.isNotEmpty) _selectPlace(matches.first); },
                  decoration: InputDecoration(
                    hintText: 'Search places',
                    prefixIcon: const Icon(Icons.menu, color: Color(0xFF5F6368)),
                    suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () {
                      if (matches.isNotEmpty) _selectPlace(matches.first);
                    }),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
            if (matches.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                constraints: const BoxConstraints(maxHeight: 230),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
                child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: matches.map((p) =>
                  ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(p.name),
                    subtitle: Text(p.subtitle), onTap: () => _selectPlace(p))).toList()),
              ),
            const Spacer(),
            Align(alignment: Alignment.centerRight, child: Padding(
              padding: const EdgeInsets.only(right: 14, bottom: 12),
              child: Column(children: [
                _roundButton(Icons.layers_outlined, 'Map type', _showMapTypes),
                const SizedBox(height: 10),
                _roundButton(Icons.my_location, 'My location', _goToCurrentLocation),
                const SizedBox(height: 10),
                _roundButton(Icons.add, 'Zoom in', () => _mapController?.animateCamera(CameraUpdate.zoomIn())),
                const SizedBox(height: 10),
                _roundButton(Icons.remove, 'Zoom out', () => _mapController?.animateCamera(CameraUpdate.zoomOut())),
              ]),
            )),
          ]),
        ),
        if (_error != null)
          Positioned(top: 112, left: 16, right: 16, child: Card(
            color: Colors.white, child: ListTile(leading: const Icon(Icons.location_disabled, color: Colors.red),
              title: Text(_error!), trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLocation)))),
        if (_loading)
          const Positioned(top: 110, left: 0, right: 0, child: Center(child: Card(
            child: Padding(padding: EdgeInsets.all(12), child: Row(mainAxisSize: MainAxisSize.min,
              children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10), Text('Getting your location...')]))))),
        _bottomPanel(),
      ]),
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) =>
      Material(elevation: 4, color: Colors.white, shape: const CircleBorder(), child: IconButton(
        tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: const Color(0xFF2878F0))));

  Widget _bottomPanel() => Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(
    top: false, child: Material(elevation: 8, color: Colors.white,
      borderRadius: BorderRadius.circular(20), child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.near_me, color: Color(0xFF2878F0)), const SizedBox(width: 8),
              Expanded(child: Text(_destination?.name ?? 'Your current location',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              if (_destination != null) IconButton(onPressed: _clearDestination,
                icon: const Icon(Icons.close), visualDensity: VisualDensity.compact),
            ]),
            if (_destination == null) ...[
              Text(_error == null ? 'GPS ${_tracking ? 'tracking active' : 'paused'}' : 'GPS unavailable',
                style: TextStyle(color: _error == null ? Colors.green : Colors.red, fontSize: 12)),
              const SizedBox(height: 8),
              Text('Lat ${_currentLatLng.latitude.toStringAsFixed(6)}  •  Lng ${_currentLatLng.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _showPlaces(), icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore demo places'))),
            ] else ...[
              Text(_destination!.subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                _stat(Icons.route, '${_distanceKm.toStringAsFixed(1)} km', 'Distance'),
                _stat(Icons.schedule, _eta, 'Estimated time'),
                _stat(Icons.location_on, '${_route.length}', 'Route points'),
              ]),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _navigating ? _stopNavigation : _startNavigation,
                icon: Icon(_navigating ? Icons.stop : Icons.navigation),
                label: Text(_navigating ? 'Stop demo navigation' : 'Start navigation'))),
              const Padding(padding: EdgeInsets.only(top: 6), child: Text(
                'Demo route is a straight line, not turn-by-turn road directions.',
                style: TextStyle(fontSize: 10, color: Colors.black45))),
            ],
          ])))));

  Widget _stat(IconData icon, String value, String label) => Expanded(child: Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF2878F0)), const SizedBox(width: 5),
    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10), overflow: TextOverflow.ellipsis),
    ])),
  ]));

  void _goToCurrentLocation() {
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: _currentLatLng, zoom: 16)));
    if (_position == null) _loadLocation();
  }

  void _showMapTypes() {
    showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: Wrap(children: [
      const ListTile(title: Text('Map type', style: TextStyle(fontWeight: FontWeight.bold))),
      _mapTypeTile('Default', MapType.normal),
      _mapTypeTile('Satellite', MapType.satellite),
      _mapTypeTile('Terrain', MapType.terrain),
      _mapTypeTile('Hybrid', MapType.hybrid),
    ])));
  }

  Widget _mapTypeTile(String title, MapType type) => ListTile(
    leading: Icon(_mapType == type ? Icons.radio_button_checked : Icons.radio_button_off,
      color: const Color(0xFF2878F0)), title: Text(title), onTap: () {
        setState(() => _mapType = type);
        Navigator.pop(context);
      });

  void _showPlaces() {
    showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (context) => SafeArea(child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Explore demo places', style: TextStyle(fontWeight: FontWeight.bold))),
        ..._places.map((p) => ListTile(leading: const Icon(Icons.place_outlined), title: Text(p.name),
          subtitle: Text(p.subtitle), onTap: () { Navigator.pop(context); _selectPlace(p); })),
      ])));
  }
}
