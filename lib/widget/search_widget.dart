import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../model/auto_complete_result.dart';
import '../provider/search_places.dart';
import '../service/maps_service.dart';

class SearchWidget extends ConsumerStatefulWidget {

  final bool passedSearchToggle;
  final Set<Marker> passedMarkers;
  final Function(bool, Set<Marker>, Timer) onValuesChanged;

  SearchWidget(this.passedSearchToggle, this.passedMarkers, this.onValuesChanged);

  @override
  _SearchWidgetState createState() => _SearchWidgetState();

}

class _SearchWidgetState extends ConsumerState<SearchWidget> {

  // passed values from main widget
  late bool _searchToggle;
  late Set<Marker> _markers;
  Timer? _debounce;

  // private variables
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchToggle = widget.passedSearchToggle;
    _markers = widget.passedMarkers;
  }

  void onSearchValueChanged(bool search) {
    setState(() {
      _searchToggle = search;
    });
    widget.onValuesChanged(_searchToggle, _markers, _debounce!);
  }

  void onMarkersValueChanged(Set<Marker> marker) {
    setState(() {
      _markers = marker;
    });
    widget.onValuesChanged(_searchToggle, _markers, _debounce!);
  }

  @override
  Widget build(BuildContext context) {

    // providers
    final allSearchResults = ref.watch(placeResultsProvider);
    final searchFlag = ref.watch(searchToggleProvider);

    void _onSearch(String inputtedValue) {
      // if a user types too fast in the input field, we cannot make calls so fast
      // so we make calls every 0.7 seconds
      if(_debounce?.isActive ?? false) {
        _debounce?.cancel();
      }

      _debounce = Timer(Duration(milliseconds: 700), () async {
        // start searching
        if(inputtedValue.length > 2) {
          searchFlag.toggleSearch();
          onMarkersValueChanged({});
        }

        List<AutoCompleteResult> searchResult = await MapsService().searchPlaces(inputtedValue);
        if (searchResult.length != 0) {
          allSearchResults.setResults(searchResult);
        } else {
          List<AutoCompleteResult> searchResult = [];
          allSearchResults.setResults(searchResult);
        }
      });
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(15.5, 40.0, 15.0, 5.0),
      child: Column(
        children: [
          Container(
            height: 50.0,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.white
            ),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                border: InputBorder.none,
                hintText: 'Search',
                suffixIcon: IconButton(onPressed: () {
                  setState(() {
                    onSearchValueChanged(false);
                    _searchController.text = '';
                    onMarkersValueChanged({});
                    List<AutoCompleteResult> emptyPlaceResults = [];
                    allSearchResults.setResults(emptyPlaceResults);
                  });
                }, icon: Icon(Icons.close)),
              ),
              onChanged: (inputtedValue) => _onSearch(inputtedValue),
            ),
          )
        ],
      ),
    );
  }
}
