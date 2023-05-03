import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../service/maps_service.dart';

class DirectionsWidget extends StatefulWidget {
  
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool getDirection;
  final Completer<GoogleMapController> controller;
  final int markerIdCounter;
  final int polylineIdCounter;
  final Function(int, int) onValuesCounterChanged;
  final Function(bool) onValueDirectionChanged;

  DirectionsWidget(
      this.markers,
      this.polylines,
      this.getDirection,
      this.controller,
      this.markerIdCounter,
      this.polylineIdCounter,
      this.onValuesCounterChanged,
      this.onValueDirectionChanged
  );

  @override
  State<DirectionsWidget> createState() => _DirectionsWidgetState();

}

class _DirectionsWidgetState extends State<DirectionsWidget> {

  // values passed from main widget and changed here
  late int _markerCounter;
  late int _polylineCounter;
  late Set<Marker> _markers;
  late Set<Polyline> _polylines;
  late bool _getDirections;
  
  // private variables
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _markerCounter = widget.markerIdCounter;
    _polylineCounter = widget.polylineIdCounter;
    _markers = widget.markers;
    _polylines = widget.polylines;
    _getDirections = widget.getDirection;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(15.0, 40.0, 15.0, 5),
      child: Column(
        children: [
          Container(
            height: 50.0,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0), color: Colors.white),
            child: TextFormField(
              controller: _originController,
              decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                  border: InputBorder.none,
                  hintText: 'Origin'
              ),
            ),
          ),
          SizedBox(height: 3.0,),
          Container(
            height: 50.0,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0), color: Colors.white),
            child: TextFormField(
              controller: _destinationController,
              decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                  border: InputBorder.none,
                  hintText: 'Destination',
                  suffixIcon: Container(
                    width: 96.0,
                    child: Row(
                      children: [
                        IconButton(onPressed: () async {
                          // get directions
                          var directions = await MapsService().getDirections(_originController.text, _destinationController.text);
                          _markers = {};
                          _polylines = {};
                          // navigate camera to origin
                          goToSearchedPlaceDirection(directions);
                          _setPolyline(directions['polyline_decoded']);
                          // close keyboard
                          FocusManager.instance.primaryFocus?.unfocus();
                        }, icon: Icon(Icons.search)),
                        IconButton(onPressed: () {
                          setState(() {
                            _getDirections = false;
                            widget.onValueDirectionChanged(_getDirections);
                            _originController.text = '';
                            _destinationController.text = '';
                            _markers = {};
                            _polylines = {};
                          });
                        }, icon: Icon(Icons.close))
                      ],
                    ),
                  )
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setPolyline(List<PointLatLng> points) {
    var counter = _polylineCounter++;
    final String polylineIdVal = 'polyline$counter';
    var polyline = Polyline(
        polylineId: PolylineId(polylineIdVal),
        width: 2,
        color: Colors.blue,
        points: points.map((e) => LatLng(e.latitude, e.longitude)).toList()
    );

    setState(() {
      widget.polylines.add(polyline);
      _polylineCounter = counter;
      widget.onValuesCounterChanged(_markerCounter, _polylineCounter);
    });
  }

  void _setMarker(point) {
    var counter = _markerCounter++;

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker
    );

    setState(() {
      widget.markers.add(marker);
      _markerCounter = counter;
      widget.onValuesCounterChanged(_markerCounter, _polylineCounter);
    });
  }

  Future<void> goToSearchedPlaceDirection(directions) async {
    double latOrigin = directions['start_location']['lat'];
    double lngOrigin = directions['start_location']['lng'];
    double latDestination = directions['end_location']['lat'];
    double lngDestination = directions['end_location']['lng'];
    Map<String, dynamic> boundsNe = directions['bounds_ne'];
    Map<String, dynamic> boundsSw = directions['bounds_sw'];

    final GoogleMapController controller = await widget.controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(boundsSw['lat'], boundsSw['lng']), northeast: LatLng(boundsNe['lat'], boundsNe['lng'])), 25)
    );

    _setMarker(LatLng(latOrigin, lngOrigin));
    _setMarker(LatLng(latDestination, lngDestination));
  }

}
