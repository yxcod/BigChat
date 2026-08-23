import 'package:flutter_base/features/location/data/app_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distance is displayed in exact meters below one kilometer', () {
    expect(formatDistance(0), '0米');
    expect(formatDistance(328), '328米');
    expect(formatDistance(999), '999米');
  });

  test('longer distances use readable kilometer units', () {
    expect(formatDistance(1250), '1.3公里');
    expect(formatDistance(12500), '13公里');
  });
}
