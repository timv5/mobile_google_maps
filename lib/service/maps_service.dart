import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_google_maps/model/auto_complete_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class MapsService {

  final String API_KEY = 'YOUR_KEY';
  final String types = 'geocode';

  Future<List<AutoCompleteResult>> searchPlaces(String searchInput) async {
    String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$searchInput&types=$types&key=$API_KEY';
    var response = await http.get(Uri.parse(url));
    var json = convert.jsonDecode(response.body);
    var results = json['predictions'] as List;
    return results.map((e) => AutoCompleteResult.fromJson(e)).toList();
  }

  // get place by place id
  Future<Map<String, dynamic>> getPlace(String? input) async {
    final String url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$input&key=$API_KEY';
    var response = await http.get(Uri.parse(url));
    var json = convert.jsonDecode(response.body);
    var results = json['result'] as Map<String, dynamic>;
    return results;
  }

  // find all places around "coordinates" in radius "radius"
  Future<Map<String, dynamic>> getPlaceDetails(LatLng coordinates, int radius) async {
    double lat = coordinates.latitude;
    double lng = coordinates.longitude;
    final String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=$radius&key=$API_KEY';
    var response = await http.get(Uri.parse(url));
    var json = convert.jsonDecode(response.body);
    return json;
  }

  Future<dynamic> getMorePlaceDetails(String token) async {
    final String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?&pagetoken=$token&key=$API_KEY';
    var response = await http.get(Uri.parse(url));
    var json = convert.jsonDecode(response.body);
    return json;
  }

  // get directions from "origin" to "destination"
  Future<Map<String, dynamic>> getDirections(String origin, String destination) async {
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?destination=$destination&origin=$origin&key=$API_KEY';
    var response = await http.get(Uri.parse(url));
    var json = convert.jsonDecode(response.body);
    var result = {
      'bounds_ne': json['routes'][0]['bounds']['northeast'],
      'bounds_sw': json['routes'][0]['bounds']['southwest'],
      'start_location': json['routes'][0]['legs'][0]['start_location'],
      'end_location': json['routes'][0]['legs'][0]['end_location'],
      'polyline': json['routes'][0]['overview_polyline']['points'],
      'polyline_decoded': PolylinePoints().decodePolyline(json['routes'][0]['overview_polyline']['points']),
    };

    return result;
  }

}