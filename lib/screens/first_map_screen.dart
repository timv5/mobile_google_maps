import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_google_maps/service/location_service.dart';

class FirstMapScreen extends StatefulWidget {

  static const routeName = '/firstMap';

  const FirstMapScreen({Key? key}) : super(key: key);

  @override
  State<FirstMapScreen> createState() => _FirstMapScreenState();
}

class _FirstMapScreenState extends State<FirstMapScreen> {

  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();

  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  int polylineIdCounter = 1;

  static const CameraPosition _initialMarkerPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _setMarker(_initialMarkerPosition.target);
  }

  void _setMarker(LatLng point) {
    setState(() {
      _markers.add(Marker(markerId: MarkerId('markerId'), position: point));
    });
  }

  void _setPolyline(List<PointLatLng> points) {
    final String polylineIdVal = 'poly_$polylineIdCounter';
    polylineIdCounter++;

    _polylines.add(
        Polyline(
            polylineId: PolylineId(polylineIdVal),
            width: 2,
            color: Colors.blue,
            points: points.map(
                  (point) => LatLng(point.latitude, point.longitude),
            ).toList()
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _originController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(hintText: 'Origin'),
                        onChanged: (value) {
                          print(value);
                        },
                      ),
                      TextFormField(
                        controller: _destinationController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(hintText: 'Destination'),
                        onChanged: (value) {
                          print(value);
                        },
                      ),
                    ],
                  )
              ),
              IconButton(
                  onPressed: () async {
                    // var place = await LocationService().getPlace(_searchController.text);
                    // _goToSearchedPlace(place);
                    var directions = await LocationService().getDirectionsDrivingMode(_originController.text, _destinationController.text);
                    _findDirections(
                      directions['start_location']['lat'],
                      directions['start_location']['lng'],
                      directions['bounds_ne'],
                      directions['bounds_sw'],
                    );
                    _setPolyline(directions['polyline_decoded']);
                  },
                  icon: Icon(Icons.search)
              ),
            ],
          ),
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              markers: _markers,
              polylines: _polylines,
              initialCameraPosition: _initialMarkerPosition,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _findDirections(double lat, double lng, Map<String, dynamic> boundsNe, Map<String, dynamic> boundsSw) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(boundsSw['lat'], boundsSw['lng']),
            northeast: LatLng(boundsNe['lat'], boundsNe['lng'])
        ), 25
    ));

    _setMarker(LatLng(lat, lng));
  }

  Future<void> _goToSearchedPlace(Map<String, dynamic> place) async {
    // extract lat&lng from place
    double lat = place['geometry']['location']['lat'];
    double lng = place['geometry']['location']['lng'];
    CameraPosition newCameraPosition = CameraPosition(
        target: LatLng(lat, lng),
        zoom: 12
    );
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(newCameraPosition));

    _setMarker(LatLng(lat, lng));
  }

}
