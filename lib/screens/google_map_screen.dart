import 'dart:async';
import 'dart:typed_data';

import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_google_maps/model/auto_complete_result.dart';
import 'package:mobile_google_maps/provider/search_places.dart';
import 'package:mobile_google_maps/service/maps_service.dart';
import 'dart:ui' as ui;

class GoogleMapScreen extends ConsumerStatefulWidget {

  const GoogleMapScreen({Key? key}) : super(key: key);

  @override
  _GoogleMapScreenState createState() => _GoogleMapScreenState();

}

class _GoogleMapScreenState extends ConsumerState<GoogleMapScreen> {

  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  TextEditingController _searchController = TextEditingController();
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  Timer? _debounce;

  // ui manipulation
  bool searchToggle = false;
  bool radiusSlider = false;
  bool pressedNear = false;
  bool cardTapped = false;
  bool getDirection = false;

  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  Set<Marker> _markersDuplicate = Set<Marker>();

  // this serves as a unique key so we can add multiple markers in a Set<Marker>
  int markerIdCounter = 1;
  int polylineIdCounter = 1;

  var radiusValue = 3000.0;
  Set<Circle> _circles = Set<Circle>();
  var tappedPoint;

  List allFavoritePlaces = [];
  String tokenKey = '';

  // reviews and place image related variables
  late PageController _pageController;
  int prevPage = 0;
  var tappedPlaceDetail;
  String placeImg = '';
  final String API_KEY = 'YOUR_KEY';
  var selectedPlaceDetails;
  var photoGalleryIndex = 0;
  bool showBlankCard = false;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 12,
  );

  @override
  void initState() {
    _pageController = PageController(initialPage: 1, viewportFraction: 0.85)..addListener(_onScroll);
    super.initState();
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  // creates a new marker, sets it a custom icon from assets and put in in _marker list
  // name = name of the point, types = tape of the point (like restaurant), business status (open, ...)
  void _setMarkerInRadius(LatLng point, String name, List types, var businessStatus) async {
    var counter = markerIdCounter++;
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
    });
  }

  Future<void> goToTappedPlace() async {
    final GoogleMapController controller = await _controller.future;
    _markers = {};
    var selectedPlace = allFavoritePlaces[_pageController.page!.toInt()];
    double lat = selectedPlace['geometry']['location']['lat'];
    double lng = selectedPlace['geometry']['location']['lng'];
    _setMarkerInRadius(
        LatLng(lat, lng),
        selectedPlace['name'] ?? 'no name',
        selectedPlace['types'],
        selectedPlace['business_status'] ?? 'none'
    );

    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 14.0, bearing: 45.0, tilt: 45.0),
    ));
  }

  void _onScroll() {
    if (_pageController.page!.toInt() != prevPage) {
      prevPage = _pageController.page!.toInt();
      cardTapped = false;
      photoGalleryIndex = 1;
      showBlankCard = false;
      goToTappedPlace();
      fetchImage();
    }
  }

  void fetchImage() async {
    if (_pageController.page != null) {
      if (allFavoritePlaces[_pageController.page!.toInt()]['photos'] != null) {
        setState(() {
          placeImg = allFavoritePlaces[_pageController.page!.toInt()]['photos'][0]['photo_reference'];
        });
      } else {
        placeImg = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.height;

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
          _markers = {};
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

    void _setCircle(point) async {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: point, zoom: 12)));
      setState(() {
        // we passed static id, so only one circle will be in this Set<Circle>
        _circles.add(Circle(
          circleId: CircleId('circle'),
          center: point,
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue,
          strokeWidth: 1,
          radius: radiusValue
        ));
        getDirection = false;
        searchToggle = false;
        radiusSlider = true;
      });
    }

    Widget _getGoogleMapsWidget(BuildContext context) {
      return Container(
        height: screenHeight,
        width: screenWidth,
        child: GoogleMap(
          circles: _circles,
          mapType: MapType.normal,
          markers: _markers,
          polylines: _polylines,
          initialCameraPosition: _kGooglePlex,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          onTap: (point) {
            tappedPoint = point;
            _setCircle(point);
          },
        ),
      );
    }

    Widget _getInputSearchWidget(BuildContext context) {
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
                      searchToggle = false;
                      _searchController.text = '';
                      _markers = {};
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

    Widget _getFloatingActionButtonWidget(BuildContext context) {
      return FabCircularMenu(
        alignment: Alignment.bottomLeft,
        fabColor: Colors.blue.shade50,
        fabOpenColor: Colors.red.shade100,
        ringDiameter: 250.0,
        ringWidth: 60.0,
        ringColor: Colors.blue.shade50,
        fabSize: 60.0,
        children: [
          IconButton(onPressed: () {
            setState(() {
              searchToggle = true;
              radiusSlider = false;
              pressedNear = false;
              cardTapped = false;
              getDirection = false;
            });
          }, icon: Icon(Icons.search)),
          IconButton(onPressed: (){
            setState(() {
              searchToggle = false;
              radiusSlider = false;
              pressedNear = false;
              cardTapped = false;
              getDirection = true;
            });
          }, icon: Icon(Icons.navigation)),
        ],
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

    // holds search results
    Widget _getSearchResultsWidget(BuildContext context) {
      return Positioned(
          top: 100.0,
          left: 15.0,
          child: Container(
            height: 200.0,
            width: screenWidth - 30.0,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0), color: Colors.white.withOpacity(0.7),),
            child: ListView(
              children: [
                ...allSearchResults.allReturnedResults.map((e) => _buildListItem(e))
              ],
            ),
          )
      );
    }

    // holds empty search results
    Widget _getSearchResultsEmptyWidget(BuildContext context) {
      return Positioned(
          top: 100.0,
          left: 15.0,
          child: Container(
            height: 200.0,
            width: screenWidth - 30.0,
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

    Widget _getDirectionWidget() {
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
                            getDirection = false;
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

    Widget _getRadiusSliderOnTap() {
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
                    pressedNear = false;
                    _setCircle(tappedPoint);
                  }
                ),
              ),
              !pressedNear ?
              IconButton(icon: Icon(Icons.near_me, color: Colors.blue,),
                onPressed: () {
                  // every 2 seconds can this button be clicked to take affect
                  if (_debounce?.isActive ?? false) {
                    _debounce?.cancel();
                  }
                  _debounce = Timer(Duration(seconds: 2), () async {
                    // get places in radius
                    var placesResult = await MapsService().getPlaceDetails(tappedPoint, radiusValue.toInt());
                    List<dynamic> placesWithin = placesResult['results'] as List;
                    allFavoritePlaces = placesWithin;
                    tokenKey = placesResult['next_place_token'] ?? 'none';
                    _markers = {};
                    // set markers to places in radius
                    placesWithin.forEach((e) {
                      _setMarkerInRadius(
                        LatLng(e['geometry']['location']['lat'], e['geometry']['location']['lng']),
                          e['name'],
                          e['types'],
                          e['business_status'] ?? 'not available'
                      );
                    });
                    _markersDuplicate = _markers;
                    pressedNear = true;
                  });
                }
              ) : IconButton(
                    onPressed: () {
                      if(_debounce?.isActive ?? false) {
                        _debounce?.cancel();
                      }

                      _debounce = Timer(Duration(seconds: 2), () async {
                        if (tokenKey != 'none') {
                          var placeResult = await MapsService().getMorePlaceDetails(tokenKey);
                          List<dynamic> placesWithin = placeResult['results'] as List;
                          allFavoritePlaces.addAll(placesWithin);
                          tokenKey = placeResult['next_page_token'] ?? 'none';

                          // set markers to places in radius
                          placesWithin.forEach((e) {
                            _setMarkerInRadius(
                                LatLng(e['geometry']['location']['lat'], e['geometry']['location']['lng']),
                                e['name'],
                                e['types'],
                                e['business_status'] ?? 'not available'
                            );
                          });
                        } else {
                          print('Finished');
                        }
                      });
                    },
                    icon: Icon(Icons.mobile_friendly, color: Colors.white,)
                  ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  _getGoogleMapsWidget(context),
                  searchToggle ? _getInputSearchWidget(context) : Container(),
                  (searchFlag.searchToggle && searchToggle) ? allSearchResults.allReturnedResults.length != 0 ? _getSearchResultsWidget(context) : _getSearchResultsEmptyWidget(context) : Container(),
                  getDirection ? _getDirectionWidget() : Container(),
                  radiusSlider ? _getRadiusSliderOnTap() : Container(),
                  // pressedNear ? _getPlaceDetailsAndReviews() : Container(),
                ]
              )
            ],
          ),
        ),
      ),
      floatingActionButton: _getFloatingActionButtonWidget(context)
    );
  }

  void _setPolyline(List<PointLatLng> points) {
    final String polylineIdVal = 'polyline$polylineIdCounter';
    polylineIdCounter++;
    _polylines.add(Polyline(
      polylineId: PolylineId(polylineIdVal),
      width: 2,
      color: Colors.blue,
      points: points.map((e) => LatLng(e.latitude, e.longitude)).toList()
    ));
  }

  void _setMarker(point) {
    var counter = markerIdCounter++;

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }

  Future<void> goToSearchedPlace(double lat, double lng) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 12)));
    _setMarker(LatLng(lat, lng));
  }

  Future<void> goToSearchedPlaceDirection(directions) async {
    double latOrigin = directions['start_location']['lat'];
    double lngOrigin = directions['start_location']['lng'];
    double latDestination = directions['end_location']['lat'];
    double lngDestination = directions['end_location']['lng'];
    Map<String, dynamic> boundsNe = directions['bounds_ne'];
    Map<String, dynamic> boundsSw = directions['bounds_sw'];

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(boundsSw['lat'], boundsSw['lng']), northeast: LatLng(boundsNe['lat'], boundsNe['lng'])), 25)
    );

    _setMarker(LatLng(latOrigin, lngOrigin));
    _setMarker(LatLng(latDestination, lngDestination));
  }

}
