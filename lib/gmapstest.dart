import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' show cos, sqrt, pow, sin, atan2;
import 'package:just_audio/just_audio.dart';

class MapsApp extends StatefulWidget {
  const MapsApp({Key? key}) : super(key: key);

  @override
  State<MapsApp> createState() => _MapsAppState();
}

class _MapsAppState extends State<MapsApp> {
  final Location _location = Location();
  late GoogleMapController _mapController;
  final Set<Marker> markers = {};
  LatLng? _initialLocation;
  LocationData? _userLocation;
  StreamSubscription<LocationData>? _locationSubscription;
  AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    playSound();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    super.dispose();
    _locationSubscription?.cancel();
  }

  void _getUserLocation() async {
    var currentLocation = await _location.getLocation();
    setState(() {
      _initialLocation =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);
    });
  }

  void _startLocationUpdates() {
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData result) {
      setState(() {
        _userLocation = result;
      });
      _checkDistanceToMarker();
    });
  }

  void _checkDistanceToMarker() async {
    if (_initialLocation != null && _userLocation != null) {
      for (Marker marker in markers) {
        double distance = _calculateDistance(marker.position,
            LatLng(_userLocation!.latitude!, _userLocation!.longitude!));
        if (distance < 50) {
          // Alert user
          await playSound();
          _showAlert();
          break; // Alert only once when the user is close to any marker
        }
      }
    }
  }

  Future<void> playSound() async {
    AudioPlayer player = AudioPlayer();
    await player.setAsset('assets/stop.wav');
    player.play();
  }

  Future<void> _showAlert() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pothole Alert'),
          content: const Text(
              'You are less than 50 meters away from a Pothole. Please proceed with caution.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double pi = 3.1415926535897932;
    const double earthRadius = 6371000; // meters

    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;

    double dlon = lon2 - lon1;
    double dlat = lat2 - lat1;

    double a =
        pow(sin(dlat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _addMarker(LatLng position) async {
    final MarkerId markerId = MarkerId(position.toString());
    final Marker marker = Marker(
      markerId: markerId,
      position: position,
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: 200,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo),
                    title: const Text('Add an Image'),
                    onTap: () async {
                      final image = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);

                      Navigator.pop(context); // Close the bottom sheet
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Remove Marker'),
                    onTap: () {
                      // Remove the tapped marker
                      final Marker marker =
                          markers.firstWhere((m) => m.position == position);
                      markers.remove(marker);
                      setState(() {}); // Update the markers list
                      Navigator.pop(context); // Close the bottom sheet
                    },
                  ),
                  // Add more options if needed
                ],
              ),
            );
          },
        );
      },
    );

    setState(() {
      markers.add(marker);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialLocation ??
                  const LatLng(
                      0, 0), // Default to (0,0) if location not available yet
              zoom: 20,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onTap: _addMarker,
          ),
          Positioned(
            left: 16,
            bottom: 30,
            child: FloatingActionButton(
              onPressed: () {
                if (_initialLocation != null) {
                  _mapController.animateCamera(
                    CameraUpdate.newLatLng(_initialLocation!),
                  );
                }
              },
              child: Icon(Icons.my_location),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    home: MapsApp(),
  ));
}
