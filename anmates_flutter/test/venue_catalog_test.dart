import 'package:flutter_test/flutter_test.dart';

import 'package:anmates/services/venue_catalog_service.dart';
import 'package:anmates/views/v2/v2_venue_mapper.dart';

/// A real row shape from `GET /api/v1/venues` (Bánh Mì Huỳnh Hoa, seed source).
Map<String, dynamic> _row({
  String name = 'Lẩu Trứ Danh Sài Gòn',
  List<String> cuisine = const ['lau', 'vietnamese'],
  int? priceMin = 65000,
  int? priceMax,
  double? rating,
  String? district = 'Q1',
  String? address = '1 Nguyễn Huệ, P.Bến Nghé',
  int? distanceM = 420,
  int wantCount = 0,
  int photoCount = 0,
}) => {
      'id': 'f8d90d1f-ab3f-4861-985e-0e4653ced42e',
      'name': name,
      'address': address,
      'district': district,
      'lat': 10.773125,
      'lng': 106.700606,
      'cuisine_tags': cuisine,
      'price_min': ?priceMin,
      'price_max': ?priceMax,
      'rating': ?rating,
      // The API never sends a photo URL, only how many stored photos exist —
      // CatalogVenue builds the URLs itself. See venue_photos /
      // db/migrations/014_venue_photo_blobs.sql.
      'photo_count': photoCount,
      'source': 'pipeline',
      'distance_m': ?distanceM,
      'want_count': wantCount,
    };

void main() {
  group('CatalogVenue.fromJson', () {
    test('parses a full row', () {
      final v = CatalogVenue.fromJson(_row(rating: 4.5, priceMax: 120000));
      expect(v.name, 'Lẩu Trứ Danh Sài Gòn');
      expect(v.district, 'Q1');
      expect(v.cuisineTags, ['lau', 'vietnamese']);
      expect(v.priceMin, 65000);
      expect(v.priceMax, 120000);
      expect(v.rating, 4.5);
      expect(v.distanceM, 420);
      expect(v.source, 'pipeline');
    });

    test('builds one photo URL per photo_count slot, in order', () {
      final v = CatalogVenue.fromJson(_row(photoCount: 3));
      expect(v.photoUrls, [
        'http://localhost:8080/api/v1/venues/f8d90d1f-ab3f-4861-985e-0e4653ced42e/photos/0',
        'http://localhost:8080/api/v1/venues/f8d90d1f-ab3f-4861-985e-0e4653ced42e/photos/1',
        'http://localhost:8080/api/v1/venues/f8d90d1f-ab3f-4861-985e-0e4653ced42e/photos/2',
      ]);
    });

    test('photo_count 0 means no photo on file, not a fetch failure', () {
      final v = CatalogVenue.fromJson(_row(photoCount: 0));
      expect(v.photoUrls, isEmpty);
    });

    test('nullable columns stay null rather than becoming zeros', () {
      final v = CatalogVenue.fromJson(
        _row(priceMin: null, rating: null, district: null, address: null, distanceM: null),
      );
      expect(v.priceMin, isNull);
      expect(v.priceMax, isNull);
      expect(v.rating, isNull);
      expect(v.district, isNull);
      expect(v.address, isNull);
      expect(v.distanceM, isNull);
      expect(v.wantCount, 0);
    });
  });

  group('districtLabel', () {
    test('expands the DB short codes', () {
      expect(districtLabel('Q1'), 'Quận 1');
      expect(districtLabel('TD'), 'Thủ Đức');
      expect(districtLabel('PN'), 'Phú Nhuận');
    });

    test('passes through an already-spelled district', () {
      expect(districtLabel('Thuận An'), 'Thuận An');
    });

    test('says it does not know instead of guessing TP.HCM', () {
      // Dữ liệu có quán ở Hà Nội, Bình Dương, Đà Lạt; đoán thành TP.HCM là
      // hiện sai thành phố cho người dùng.
      expect(districtLabel(null), 'Chưa rõ');
      expect(districtLabel('  '), 'Chưa rõ');
    });

    test('shows merged districts under their current unit', () {
      expect(districtLabel('Q2'), 'Thủ Đức');
      expect(districtLabel('Q9'), 'Thủ Đức');
    });
  });

  group('priceLabel', () {
    test('renders a band, an open-ended min, and a missing price', () {
      expect(priceLabel(180000, 260000), '180–260k');
      expect(priceLabel(69000, null), 'từ 69k');
      expect(priceLabel(69000, null, en: true), 'from 69k');
      expect(priceLabel(null, null), '—');
    });
  });

  group('distanceLabel', () {
    test('metres under 1 km, Vietnamese decimal comma above', () {
      expect(distanceLabel(800), '800 m');
      expect(distanceLabel(2400), '2,4 km');
    });

    test('is empty when the listing carried no location', () {
      expect(distanceLabel(null), '');
    });
  });

  group('artForCuisine', () {
    test('maps cuisine tags onto the six shipped renders', () {
      expect(artForCuisine(['lau', 'vietnamese']), endsWith('hotpot.png'));
      expect(artForCuisine(['bbq', 'korean']), endsWith('bbq.png'));
      expect(artForCuisine(['pho']), endsWith('ramen.png'));
      expect(artForCuisine(['cafe']), endsWith('coffee.png'));
      expect(artForCuisine(['oc', 'seafood']), endsWith('beer.png'));
    });

    test('falls back for an untagged venue', () {
      expect(artForCuisine([]), endsWith('burger.png'));
    });
  });

  group('venueFromCatalog', () {
    test('carries the DB values onto the feed tile', () {
      final v = venueFromCatalog(CatalogVenue.fromJson(_row(rating: 4.5, priceMax: 120000)));
      expect(v.name, 'Lẩu Trứ Danh Sài Gòn');
      expect(v.area, 'Quận 1');
      expect(v.rating, '4.5');
      expect(v.price, '65–120k');
      expect(v.tileMeta, '420 m · 65–120k');
      expect(v.cardWhere, 'Quận 1 · 420 m');
    });

    test('a venue with no rating shows a dash, never an invented score', () {
      final v = venueFromCatalog(CatalogVenue.fromJson(_row(rating: null)));
      expect(v.rating, '—');
    });

    test('omits the distance segment when the listing had no location', () {
      final v = venueFromCatalog(CatalogVenue.fromJson(_row(distanceM: null, priceMax: 120000)));
      expect(v.dist, '');
      expect(v.tileMeta, '65–120k');
      expect(v.cardWhere, 'Quận 1');
    });

    test('carries the first stored photo as the tile image', () {
      final v = venueFromCatalog(CatalogVenue.fromJson(_row(photoCount: 2)));
      expect(v.photoUrl, endsWith('/photos/0'));
    });

    test('no stored photo means null, so the UI falls back to art', () {
      final v = venueFromCatalog(CatalogVenue.fromJson(_row(photoCount: 0)));
      expect(v.photoUrl, isNull);
    });
  });

  group('placeFromCatalog', () {
    test('builds summary lines out of real columns only', () {
      final p = placeFromCatalog(CatalogVenue.fromJson(_row(rating: 4.5, priceMax: 120000)));
      final keys = p.lines.map((l) => l.key.vi).toList();
      expect(keys, ['Món chính', 'Địa chỉ', 'Khu vực', 'Khoảng giá', 'Đánh giá']);
      expect(p.lines[1].value.vi, '1 Nguyễn Huệ, P.Bến Nghé');
      expect(p.meta.vi, 'Quận 1 · lau · vietnamese · 65–120k/người');
    });

    test('drops the lines whose columns are null', () {
      final p = placeFromCatalog(CatalogVenue.fromJson(_row(rating: null, address: null)));
      final keys = p.lines.map((l) => l.key.vi).toList();
      expect(keys, isNot(contains('Đánh giá')));
      expect(keys, isNot(contains('Địa chỉ')));
      expect(p.reviews.vi, 'chưa có đánh giá');
    });

    test('want_count flows through as the demand figure', () {
      final p = placeFromCatalog(CatalogVenue.fromJson(_row(wantCount: 3)));
      expect(p.wanting, 3);
    });

    test('carries the first stored photo as the hero image', () {
      final p = placeFromCatalog(CatalogVenue.fromJson(_row(photoCount: 1)));
      expect(p.photoUrl, endsWith('/photos/0'));
    });

    test('no stored photo means null, so the hero falls back to art', () {
      final p = placeFromCatalog(CatalogVenue.fromJson(_row(photoCount: 0)));
      expect(p.photoUrl, isNull);
    });
  });
}
