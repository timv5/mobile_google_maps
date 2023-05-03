import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../model/auto_complete_result.dart';
import '../provider/search_places.dart';
import '../service/maps_service.dart';

class DropdownSearchWidget extends ConsumerStatefulWidget {

  final double screenWidth;
  final Completer<GoogleMapController> controller;
  final int markerIdCounter;
  final Set<Marker> markers;
  final bool searchToggle;
  final Function(int) onValuesChanged;

  DropdownSearchWidget(
      this.screenWidth,
      this.controller,
      this.markerIdCounter,
      this.markers,
      this.searchToggle,
      this.onValuesChanged
      );

  @override
  _DropdownSearchWidgetState createState() => _DropdownSearchWidgetState();
}

class _DropdownSearchWidgetState extends ConsumerState<DropdownSearchWidget> {

  late int _counter;

  @override
  void initState() {
    super.initState();
    _counter = widget.markerIdCounter;
  }

  @override
  Widget build(BuildContext context) {

    // providers
    final searchFlag = ref.watch(searchToggleProvider);
    final allSearchResults = ref.watch(placeResultsProvider);

    Widget _getSearchResultsEmptyWidget(BuildContext context) {
      return Positioned(
          top: 100.0,
          left: 15.0,
          child: Container(
            height: 200.0,
            width: widget.screenWidth - 30.0,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0), color: Colors.white.withOpacity(0.7),),
            child: Center(
              child: Column(children: [
                Text('No results to show', style: TextStyle(fontFamily: 'WorkSans', fontWeight: FontWeight.w400)),
                SizedBox(height: 5.0),
                Container(
                  width: 125.0,
                  child: ElevatedButton(
                    onPressed: () {
                      searchFlag.toggleSearch();
                    },
                    child: Center(child: Text('Close this', style: TextStyle(color: Colors.white, fontFamily: 'WorkSans', fontWeight: FontWeight.w300),),),
                  ),
                )
              ]),
            ),
          )
      );
    }

    Widget _buildListItem(AutoCompleteResult placeItem) {
      return Padding(
        padding: EdgeInsets.all(5.0),
        child: GestureDetector(
          onTapDown: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          onTap: () async {
            var place = await MapsService().getPlace(placeItem.placeId);
            goToSearchedPlace(place['geometry']['location']['lat'], place['geometry']['location']['lng']);
            searchFlag.toggleSearch();
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: Colors.green, size: 25.0,),
              SizedBox(width: 4.0,),
              Container(
                height: 40.0,
                width: MediaQuery.of(context).size.width - 75.0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(placeItem.description ?? ''),
                ),
              )
            ],
          ),
        ),
      );
    }

    Widget _getSearchResultsWidget(BuildContext context) {
      return Positioned(
          top: 100.0,
          left: 15.0,
          child: Container(
            height: 200.0,
            width: widget.screenWidth - 30.0,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0), color: Colors.white.withOpacity(0.7),),
            child: ListView(
              children: [
                ...allSearchResults.allReturnedResults.map((e) => _buildListItem(e))
              ],
            ),
          )
      );
    }

    return (searchFlag.searchToggle && widget.searchToggle)
        ? allSearchResults.allReturnedResults.length != 0
        ? _getSearchResultsWidget(context)
        : _getSearchResultsEmptyWidget(context)
        : Container();
  }

  Future<void> goToSearchedPlace(double lat, double lng) async {
    final GoogleMapController controller = await widget.controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 12)));
    _setMarker(LatLng(lat, lng));
  }

  void _setMarker(point) {
    var counter = _counter++;

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      widget.markers.add(marker);
      _counter = counter;
      widget.onValuesChanged(_counter);
    });
  }

}
