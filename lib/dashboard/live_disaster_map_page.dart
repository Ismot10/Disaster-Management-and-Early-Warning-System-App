import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

const String MAPTILER_KEY = "LvYR3jp1KitFbknow9TR";

// 🔴 Fixed Disaster Location (Dhaka)
const LatLng disasterLocation = LatLng(23.8103, 90.4125);

class LiveDisasterMapPage extends StatefulWidget {
  const LiveDisasterMapPage({super.key});

  @override
  State<LiveDisasterMapPage> createState() => _LiveDisasterMapPageState();
}

class _LiveDisasterMapPageState extends State<LiveDisasterMapPage> with TickerProviderStateMixin {  // Use TickerProviderStateMixin here
  final MapController _mapController = MapController();
  late AnimationController _outerRingController;
  late AnimationController _innerRingController;
  late AnimationController _rotationController;
  late Animation<double> _outerRingAnimation;
  late Animation<double> _innerRingAnimation;

  LatLng? _userLocation;
  double? _distanceKm;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _initAnimations();
  }

  // ✅ Initialize Animations
  void _initAnimations() {
    // Outer pulsing ring (slow)
    _outerRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);  // Slow pulsing effect
    _outerRingAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _outerRingController, curve: Curves.easeInOut),
    );

    // Inner pulsing ring (fast)
    _innerRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);  // Fast pulsing effect
    _innerRingAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _innerRingController, curve: Curves.easeInOut),
    );

    // Rotation for the disaster icon
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();  // Continuous rotation
  }

  // ✅ Request permission & start GPS
  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final userLatLng = LatLng(position.latitude, position.longitude);

      final distance = const Distance().as(
        LengthUnit.Kilometer,
        userLatLng,
        disasterLocation,
      );

      setState(() {
        _userLocation = userLatLng;
        _distanceKm = distance;
      });

      _autoZoom();
    });
  }

  // ✅ Auto zoom to fit both markers
  void _autoZoom() {
    if (_userLocation == null) return;

    final bounds = LatLngBounds.fromPoints([
      _userLocation!,
      disasterLocation,
    ]);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _outerRingController.dispose();
    _innerRingController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> markers = [];

    // 🔵 User Marker
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 35,
          ),
        ),
      );
    }

    // 🔴 Disaster Marker with Pulsating Rings and Rotating Icon
    markers.add(
      Marker(
        point: disasterLocation,
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Slow Pulsing Ring
            AnimatedBuilder(
              animation: _outerRingAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * pi,  // Rotate the ring
                  child: Container(
                    width: 70 + (_outerRingAnimation.value * 30), // Pulsing effect (size increases)
                    height: 70 + (_outerRingAnimation.value * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red,
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Inner Fast Pulsing Ring
            AnimatedBuilder(
              animation: _innerRingAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * pi,  // Rotate the ring
                  child: Container(
                    width: 50 + (_innerRingAnimation.value * 20), // Pulsing effect (size increases)
                    height: 50 + (_innerRingAnimation.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red,
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Rotating Warning Icon (Disaster Marker)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * pi, // Rotate the warning icon
                  child: const Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: 35,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Disaster Map"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          if (_distanceKm != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              width: double.infinity,
              child: Text(
                "Distance to Disaster: ${_distanceKm!.toStringAsFixed(2)} KM",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: disasterLocation,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=$MAPTILER_KEY",
                  userAgentPackageName: 'com.example.app',
                ),

                // ➖ Polyline between user & disaster
                if (_userLocation != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_userLocation!, disasterLocation],
                        strokeWidth: 4,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),

                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}