import 'package:smartwork_cli/src/commands/project_type.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectType', () {
    test('has exactly the eight expected values', () {
      expect(ProjectType.values, hasLength(8));
      expect(
        ProjectType.values,
        containsAll([
          ProjectType.eCommerce,
          ProjectType.foodDelivery,
          ProjectType.booking,
          ProjectType.social,
          ProjectType.dashboard,
          ProjectType.eBook,
          ProjectType.finance,
          ProjectType.custom,
        ]),
      );
    });

    test('custom is the final value', () {
      expect(ProjectType.values.last, equals(ProjectType.custom));
    });

    test('display names are correct', () {
      expect(ProjectType.eCommerce.displayName, equals('E-Commerce'));
      expect(ProjectType.foodDelivery.displayName, equals('Food Delivery'));
      expect(ProjectType.booking.displayName, equals('Booking'));
      expect(ProjectType.social.displayName, equals('Social'));
      expect(ProjectType.dashboard.displayName, equals('Dashboard'));
      expect(ProjectType.eBook.displayName, equals('E-Book'));
      expect(ProjectType.finance.displayName, equals('Finance'));
      expect(ProjectType.custom.displayName, equals('Custom'));
    });
  });
}
