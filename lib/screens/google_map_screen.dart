import 'dart:async';
import 'dart:typed_data';

import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_google_maps/widget/directions_widget.dart';
import 'package:mobile_google_maps/widget/dropdown_search_widget.dart';
import 'package:mobile_google_maps/widget/radius_slider_widget.dart';
import 'dart:ui' as ui;

import 'package:mobile_google_maps/widget/search_widget.dart';

class GoogleMapScreen extends ConsumerStatefulWidget {

  const GoogleMapScreen({Key? key}) : super(key: key);

  @override
  _GoogleMapScreenState createState() => _GoogleMapScreenState();

}

class _GoogleMapScreenState extends ConsumerState<GoogleMapScreen> {

  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Timer? _debounce;

  // ui manipulation
  bool searchToggle = false;
  bool radiusSlider = false;
  bool pressedNear = false;
  bool cardTapped = false;
  bool getDirection = false;

  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();

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

  void _handleSearchWidgetValuesChange(bool search, Set<Marker> marker, Timer timer) {
    setState(() {
      searchToggle = search;
      _markers = marker;
      _debounce = timer;
    });
  }

  void _handlerDropdownWidgetValueChanged(int markerCounter) {
    setState(() {
      markerIdCounter = markerCounter;
    });
  }

  void _handleDirectionsCounterWidgetChanged(int markerCounter, int polylineCounter) {
    setState(() {
      markerIdCounter = markerCounter;
      polylineIdCounter = polylineCounter;
    });
  }

  void _handleDirectionsWidgetChanged(bool getDirectionWidget) {
    setState(() {
      getDirection = getDirectionWidget;
    });
  }

  void _handleRadiusMarkerValuesChange(int markersCounter, Set<Marker> markers) {
    setState(() {
      markerIdCounter = markersCounter;
      _markers = markers;
    });
  }

  void _handleRadiusCircleValuesChange(Set<Circle> circles, bool directions, bool search, bool radius) {
    setState(() {
      _circles = circles;
      getDirection = directions;
      searchToggle = search;
      radiusSlider = radius;
    });
  }

  void _handleRadiusFavoritePlaces(List favoritePlaces) {
    setState(() {
      allFavoritePlaces = favoritePlaces;
    });
  }

  @override
  Widget build(BuildContext context) {

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.height;

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

    return Scaffold(
      body: Container(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  _getGoogleMapsWidget(context),
                  searchToggle ? SearchWidget(searchToggle, _markers, _handleSearchWidgetValuesChange) : Container(),
                  DropdownSearchWidget(screenWidth, _controller, markerIdCounter, _markers, searchToggle, _handlerDropdownWidgetValueChanged),
                  getDirection ? DirectionsWidget(_markers, _polylines, getDirection, _controller, markerIdCounter, polylineIdCounter, _handleDirectionsCounterWidgetChanged, _handleDirectionsWidgetChanged) : Container(),
                  radiusSlider ? RadiusSliderWidget(_controller, tappedPoint, _markers, _circles, markerIdCounter, _handleRadiusMarkerValuesChange, _handleRadiusCircleValuesChange, allFavoritePlaces, _handleRadiusFavoritePlaces) : Container(),
                ]
              )
            ],
          ),
        ),
      ),
      floatingActionButton: _getFloatingActionButtonWidget(context)
    );
  }

}
