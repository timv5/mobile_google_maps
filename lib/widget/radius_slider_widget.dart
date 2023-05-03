import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import '../service/maps_service.dart';

class RadiusSliderWidget extends StatefulWidget {

  final Completer<GoogleMapController> controller;
  final tappedPoint;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final int markerIdCounter;
  final Function(int, Set<Marker>) onMarkerValuesChanged;
  final Function(Set<Circle>, bool, bool, bool) onCircleValuesChanged;
  final List allFavoritePlaces;
  final Function(List) onFavoritePlacesChange;

  RadiusSliderWidget(
      this.controller,
      this.tappedPoint,
      this.markers,
      this.circles,
      this.markerIdCounter,
      this.onMarkerValuesChanged,
      this.onCircleValuesChanged,
      this.allFavoritePlaces,
      this.onFavoritePlacesChange
  );

  @override
  State<RadiusSliderWidget> createState() => _RadiusSliderWidgetState();
}

class _RadiusSliderWidgetState extends State<RadiusSliderWidget> {

  var radiusValue = 3000.0;

  // values passed from main widget and changed here
  Timer? _debounce;
  late int _markerCounter;
  late Set<Marker> _markers;
  late Set<Circle> _circle;
  late List _allFavoritePlaces;

  @override
  void initState() {
    super.initState();
    _markerCounter = widget.markerIdCounter;
    _markers = widget.markers;
    _circle = widget.circles;
    _allFavoritePlaces = widget.allFavoritePlaces;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 0.0),
      child: Container(
        height: 50.0,
        color: Colors.black.withOpacity(0.3),
        child: Row(
          children: [
            Expanded(
              child: Slider(
                  min: 1000.0,
                  max: 7000.0,
                  value: radiusValue,
                  onChanged: (newValue) {
                    radiusValue = newValue;
                    _setCircle(widget.tappedPoint);
                  }
              ),
            ),
            IconButton(icon: Icon(Icons.near_me, color: Colors.blue,),
                onPressed: () {
                  // every 2 seconds can this button be clicked to take affect
                  if (_debounce?.isActive ?? false) {
                    _debounce?.cancel();
                  }
                  _debounce = Timer(Duration(seconds: 2), () async {
                    // get places in radius
                    var placesResult = await MapsService().getPlaceDetails(widget.tappedPoint, radiusValue.toInt());
                    List<dynamic> placesWithin = placesResult['results'] as List;
                    _allFavoritePlaces = placesWithin;
                    widget.onFavoritePlacesChange(_allFavoritePlaces);
                    // todo
                    _markers = {};
                    widget.onMarkerValuesChanged(_markerCounter, _markers);
                    // set markers to places in radius
                    placesWithin.forEach((e) {
                      _setMarkerInRadius(
                          LatLng(e['geometry']['location']['lat'], e['geometry']['location']['lng']),
                          e['name'],
                          e['types'],
                          e['business_status'] ?? 'not available'
                      );
                    });
                  });
                }
            )
          ],
        ),
      ),
    );
  }

  void _setCircle(point) async {
    final GoogleMapController controller = await widget.controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 12)));
    setState(() {
      // we passed static id, so only one circle will be in this Set<Circle>
      _circle.add(Circle(
          circleId: CircleId('circle'),
          center: point,
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue,
          strokeWidth: 1,
          radius: radiusValue
      ));
      widget.onCircleValuesChanged(_circle, false, false, true);
    });
  }

  // creates a new marker, sets it a custom icon from assets and put in in _marker list
  // name = name of the point, types = tape of the point (like restaurant), business status (open, ...)
  void _setMarkerInRadius(LatLng point, String name, List types, var businessStatus) async {
    var counter = _markerCounter++;
    final Uint8List markerIcon;
    if (types.contains('restaurants')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/restaurants.png', 75);
    } else if (types.contains('food')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/food.png', 75);
    } else if (types.contains('school')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/schools.png', 75);
    } else if (types.contains('bar')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/bars.png', 75);
    } else if (types.contains('lodging')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/hotels.png', 75);
    } else if (types.contains('store')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/retail-stores.png', 75);
    } else if (types.contains('locality')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/local-services.png', 75);
    } else {
      markerIcon = await getBytesFromAsset('assets/mapicons/places.png', 75);
    }

    final Marker marker = Marker(
      markerId: MarkerId('marker_$counter'),
      position: point,
      icon: BitmapDescriptor.fromBytes(markerIcon),
      onTap: (){},
    );
    setState(() {
      _markers.add(marker);
      _markerCounter = counter;
      widget.onMarkerValuesChanged(_markerCounter, _markers);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

}
