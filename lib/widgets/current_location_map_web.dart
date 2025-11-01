// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// Provides platformViewRegistry for Flutter web builds
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

class CurrentLocationMap extends StatefulWidget {
  final double height;
  const CurrentLocationMap({super.key, this.height = 260});

  @override
  State<CurrentLocationMap> createState() => _CurrentLocationMapState();
}

class _CurrentLocationMapState extends State<CurrentLocationMap> {
  html.IFrameElement? _iframe;
  String _viewType = 'web-simple-map-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    // Genera un iframe a Google Maps con la geolocación del navegador.
    // No requiere API key.
    _iframe = html.IFrameElement()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      // Evita que el iframe intercepte clics superpuestos en Web
      ..style.pointerEvents = 'none';

    // Intentar geolocalizar con la API del navegador.
    try {
      html.window.navigator.geolocation?.getCurrentPosition().then((pos) {
        final lat = pos.coords?.latitude ?? 4.7110;
        final lng = pos.coords?.longitude ?? -74.0721;
        _iframe!.src = 'https://www.google.com/maps?q='
            '$lat,$lng&z=15&output=embed';
        setState(() {});
      }).catchError((_) {
        _iframe!.src = 'https://www.google.com/maps?q=4.7110,-74.0721&z=12&output=embed';
        setState(() {});
      });
    } catch (_) {
      _iframe!.src = 'https://www.google.com/maps?q=4.7110,-74.0721&z=12&output=embed';
    }

    // Registra el view factory en Web
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
