import 'package:flutter_base/core/permissions/initial_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('requests configured permissions once and records completion', () async {
    var requested = false;
    var marked = false;
    final batches = <List<Permission>>[];
    final service = InitialPermissionService(
      hasRequested: () => requested,
      markRequested: () async {
        requested = true;
        marked = true;
      },
      permissionProvider: () => const [
        Permission.notification,
        Permission.microphone,
      ],
      requester: (permissions) async => batches.add(permissions),
    );

    await service.requestOnFirstLaunch();
    await service.requestOnFirstLaunch();

    expect(batches, hasLength(1));
    expect(batches.single, [Permission.notification, Permission.microphone]);
    expect(marked, isTrue);
  });
}
