import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/models/saved_location.dart';

void main() {
  const home = SavedLocation(
    id: 'home',
    kind: SavedLocation.home,
    location: GeoPoint(24.7136, 46.6753),
  );
  const gym = SavedLocation(
    id: 'abc',
    kind: SavedLocation.other,
    name: 'النادي',
    location: GeoPoint(24.8, 46.7),
  );

  group('SavedLocation', () {
    test('home and work use their fixed labels', () {
      expect(SavedLocation.labelOf(SavedLocation.home), 'المنزل');
      expect(SavedLocation.labelOf(SavedLocation.work), 'العمل');
      expect(home.label, 'المنزل');
    });

    test('another place shows the name the customer chose', () {
      expect(gym.label, 'النادي');
    });

    test('the same place, give or take a few metres, counts as saved', () {
      expect(home.isSameAs(const GeoPoint(24.7136, 46.6753)), isTrue);
      expect(home.isSameAs(const GeoPoint(24.71365, 46.67535)), isTrue);
    });

    test('a different place or no place is not the saved one', () {
      expect(home.isSameAs(const GeoPoint(24.7200, 46.6753)), isFalse);
      expect(home.isSameAs(null), isFalse);
    });

    test('fromMap reads home and work only under their own id', () {
      final work = SavedLocation.fromMap('work', {
        'kind': 'work',
        'location': const GeoPoint(24.5, 46.5),
      });
      expect(work?.kind, SavedLocation.work);
      expect(
        SavedLocation.fromMap('xyz', {
          'kind': 'work',
          'location': const GeoPoint(24.5, 46.5),
        }),
        isNull,
      );
    });

    test('fromMap reads a named place and needs its name', () {
      final place = SavedLocation.fromMap('abc', {
        'kind': 'other',
        'name': '  النادي ',
        'location': const GeoPoint(24.8, 46.7),
      });
      expect(place?.name, 'النادي');
      expect(
        SavedLocation.fromMap('abc', {
          'kind': 'other',
          'location': const GeoPoint(24.8, 46.7),
        }),
        isNull,
      );
    });

    test('fromMap ignores a bad kind or a missing location', () {
      expect(SavedLocation.fromMap('gym', {'location': const GeoPoint(1, 1)}),
          isNull);
      expect(SavedLocation.fromMap('home', {'kind': 'home', 'location': 'x'}),
          isNull);
      expect(SavedLocation.fromMap('home', {}), isNull);
    });

    test('places sort home, work, then the named ones', () {
      const work = SavedLocation(
        id: 'work',
        kind: SavedLocation.work,
        location: GeoPoint(1, 1),
      );
      final list = [gym, work, home]..sort(SavedLocation.compare);
      expect(list.map((p) => p.id), ['home', 'work', 'abc']);
    });
  });
}
