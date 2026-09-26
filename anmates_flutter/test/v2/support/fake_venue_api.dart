import 'dart:convert';

import 'package:anmates/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Doubles for the two external edges of the home feed: the AnMates API and
/// the device's location plugin. Everything between them — V2State,
/// VenueCatalogService, ApiClient — stays real.

/// A made-up point far from every venue, standing in for the device in the
/// 2026-09-26 production report (83.6 km from the nearest one).
const farLat = 10.0;
const farLng = 105.5;

/// Answers `GET /api/v1/venues` from [catalogue] the way the real handler
/// filters it: with `radius_m`, only rows whose `distance_m` is inside it;
/// without, every row. Returns the list each request's query parameters are
/// appended to, in order.
///
/// A request whose `radius_m` is a key of [hold] is answered only once that
/// future completes, so a test can keep it in flight.
List<Map<String, String>> serveCatalogue(
  List<Map<String, dynamic>> catalogue, {
  Map<String, Future<void>> hold = const {},
}) {
  final requests = <Map<String, String>>[];
  ApiClient().httpClient = MockClient((req) async {
    expect(req.url.path, '/api/v1/venues');
    final query = req.url.queryParameters;
    requests.add(query);
    await hold[query['radius_m']];

    final radius = int.tryParse(query['radius_m'] ?? '');
    final rows = [
      for (final r in catalogue)
        if (radius == null || (r['distance_m'] as int) <= radius) r,
    ];
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {'venues': rows, 'count': rows.length, 'total': rows.length, 'has_more': false},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return requests;
}

/// The location plugin, answering with one fixed fix.
class FixedLocation extends GeolocatorPlatform {
  FixedLocation(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime(2026, 9, 26),
        accuracy: 500,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

/// The location plugin on a device with location services switched off.
class NoLocation extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

// Rows as production returned them for that report (distance_m as served,
// photo_versions cut to two slots).

const ocHem = <String, dynamic>{
  'id': 'f526fabe-aee9-4231-b3a7-fb69acfb2c5a',
  'name': 'Ốc Hẻm 239/29A Seafood Restaurant',
  'address': '239/29A Bà Hom, Phú Lâm, Hồ Chí Minh, Vietnam',
  'district': 'Q6',
  'lat': 10.7546455,
  'lng': 106.6261487,
  'cuisine_tags': ['pho', 'bbq', 'oc', 'seafood', 'trang_mieng', 'vietnamese'],
  'price_min': 45000,
  'price_max': 130000,
  'photo_count': 2,
  'photo_versions': ['56608482e12b', '87067b018c36'],
  'source': 'pipeline',
  'distance_m': 83627,
  'want_count': 0,
};

const khoaiXien = <String, dynamic>{
  'id': '52fbf04b-b045-49ad-b42d-4a8bd3085d11',
  'name': 'Khoai Xiên Nướng',
  'address': 'Y1B Hồng Lĩnh, Cư Xá Bắc Hải, Quận 10',
  'district': 'Q10',
  'lat': 10.7798826,
  'lng': 106.663325,
  'cuisine_tags': ['banh_mi', 'pho', 'bbq', 'vietnamese'],
  'price_min': 8000,
  'price_max': 140000,
  'photo_count': 2,
  'photo_versions': ['c4f19b57d528', '8db648ea40b5'],
  'source': 'pipeline',
  'distance_m': 88548,
  'want_count': 0,
};

const baBat = <String, dynamic>{
  'id': 'c3646d19-b2c3-4555-ad2d-0802693963df',
  'name': 'Ba-Bát - Vietnamese Traditional Cuisine',
  'address': '19 Ngô Văn Sở, Cửa Nam, Hà Nội',
  'district': 'Hà Nội',
  'lat': 21.0207215,
  'lng': 105.8488649,
  'cuisine_tags': ['bun', 'com', 'lau', 'oc', 'seafood', 'vietnamese'],
  'price_min': 45000,
  'photo_count': 2,
  'photo_versions': ['37a111828ec5', '6b9a3714d18a'],
  'source': 'pipeline',
  'distance_m': 1183450,
  'want_count': 0,
};

/// Made up: a venue 1.2 km from the device, for the case the radius finds.
const nearby = <String, dynamic>{
  'id': '0b5f3c1e-7d2a-4e8b-9f61-2c4d8a1e5b70',
  'name': 'Lẩu Mắm Đầu Hẻm',
  'address': '12 Quốc lộ 1A',
  'district': 'Châu Thành',
  'lat': 10.0108,
  'lng': 105.5012,
  'cuisine_tags': ['lau'],
  'price_min': 60000,
  'price_max': 150000,
  'photo_count': 0,
  'photo_versions': <String>[],
  'source': 'pipeline',
  'distance_m': 1200,
  'want_count': 0,
};
