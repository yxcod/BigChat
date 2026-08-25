import 'package:flutter/material.dart';
import 'package:flutter_base/features/location/domain/nearby_place.dart';
import 'package:flutter_base/features/moments/presentation/moment_location_picker_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('picker lists current city then nearby exact place names', (
    tester,
  ) async {
    String? selected;
    Future<NearbyPlacesResult> loader() async => const NearbyPlacesResult(
      currentCity: '南京市',
      places: [
        NearbyPlace(
          name: '南京博物院',
          address: '江苏省南京市玄武区中山东路321号',
          distanceMeters: 260,
        ),
        NearbyPlace(name: '中山东路', distanceMeters: 320),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => MomentLocationPickerPage(loader: loader),
                ),
              );
            },
            child: const Text('选择位置'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选择位置'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('current_city_location')), findsOneWidget);
    expect(find.text('南京市'), findsOneWidget);
    expect(find.text('南京博物院'), findsOneWidget);
    expect(find.text('中山东路'), findsOneWidget);
    await tester.tap(find.text('南京博物院'));
    await tester.pumpAndSettle();

    expect(selected, '南京博物院');
  });

  testWidgets('picker filters nearby places by name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MomentLocationPickerPage(
          loader: () async => const NearbyPlacesResult(
            currentCity: '南京市',
            places: [
              NearbyPlace(name: '南京博物院'),
              NearbyPlace(name: '中山东路'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moment_location_search_field')),
      '博物院',
    );
    await tester.pump();

    expect(find.text('南京博物院'), findsOneWidget);
    expect(find.text('中山东路'), findsNothing);
  });
}
