import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Location Tracker',
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const LocationTrackerScreen(),
    );
  }
}

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  State<LocationTrackerScreen> createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  GoogleMapController? _mapController;
  Timer? _locationTimer;


  final List<LatLng> _polylineCoordinates = [];


  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};


  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(23.7196, 90.4178),
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }


  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
      }
      return;
    }


    await _fetchAndUpdateLocation();

    // 2. Fetch the user's current location every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchAndUpdateLocation();
    });
  }


  Future<void> _fetchAndUpdateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {

        _polylineCoordinates.add(currentLatLng);


        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location_marker'),
            position: currentLatLng,
            infoWindow: InfoWindow(
              title: 'My current location',
              snippet: 'Lat: ${position.latitude}, Lng: ${position.longitude}',
            ),
            icon: BitmapDescriptor.defaultMarker,
          ),
        );


        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('tracking_polyline'),
            color: Colors.blue,
            width: 6,
            points: List.from(_polylineCoordinates),
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      });


      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng,
            zoom: 17.0,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Location Tracker'),
      ),
      body: GoogleMap(
        initialCameraPosition: _initialCameraPosition,
        mapType: MapType.normal,
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: false,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}