import 'package:flutter_base/features/groups/presentation/group_route_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(GroupRouteRegistry.clear);
  tearDown(GroupRouteRegistry.clear);

  test('tracks nested routes for the same group', () {
    GroupRouteRegistry.enter(1001);
    GroupRouteRegistry.enter(1001);
    expect(GroupRouteRegistry.isActive(1001), isTrue);

    GroupRouteRegistry.leave(1001);
    expect(GroupRouteRegistry.isActive(1001), isTrue);

    GroupRouteRegistry.leave(1001);
    expect(GroupRouteRegistry.isActive(1001), isFalse);
  });

  test('keeps different group routes isolated', () {
    GroupRouteRegistry.enter(1001);
    expect(GroupRouteRegistry.isActive(1001), isTrue);
    expect(GroupRouteRegistry.isActive(1002), isFalse);
  });
}
