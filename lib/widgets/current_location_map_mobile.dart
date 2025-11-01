import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationMap extends StatefulWidget {
  final double height;
  const CurrentLocationMap({super.key, this.height = 260});

  @override
  State<CurrentLocationMap> createState() => _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<CurrentLocationMap> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  LatLng? _me;
  String? _error;

  static const LatLng _fallback = LatLng(4.7110, -74.0721); // Bogotá

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() => _error = 'Permiso de ubicación denegado');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _me = LatLng(pos.latitude, pos.longitude));
      final ctrl = await _mapCtrl.future;
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(_me!, 15));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo obtener la ubicación');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _me ?? _fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 12),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (c) => _mapCtrl.complete(c),
              markers: _me != null
                  ? {Marker(markerId: const MarkerId('me'), position: _me!)}
                  : {},
            ),
            if (_error != null)
              Positioned(
                left: 8, right: 8, bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

