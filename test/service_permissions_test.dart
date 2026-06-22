import 'package:flutter_test/flutter_test.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';

void main() {
  group('Service permissions', () {
    test('Service appears between Sales and CRM with all submodules', () {
      expect(
        permissionModuleOrder,
        containsAllInOrder([
          PermissionModules.sales,
          PermissionModules.service,
          PermissionModules.crm,
        ]),
      );

      expect(permissionSubmoduleMap[PermissionModules.service], [
        ServiceSubmodules.serviceCalls,
        ServiceSubmodules.serviceVisits,
        ServiceSubmodules.serviceTechnicians,
        ServiceSubmodules.complaints,
        ServiceSubmodules.amc,
        ServiceSubmodules.installation,
        ServiceSubmodules.serviceReports,
      ]);
    });

    test('Service exposes 12 visible actions', () {
      final serviceSubmodules =
          permissionSubmoduleMap[PermissionModules.service]!;
      final totalActions = serviceSubmodules.fold<int>(
        0,
        (total, submodule) =>
            total + permissionActionsBySubmodule[submodule]!.length,
      );

      expect(totalActions, 12);
    });

    test('Service role defaults select 5 of 12 actions', () {
      final defaults = getDefaultPermissions(UserRoles.service);
      final service = Map<String, dynamic>.from(
        defaults[PermissionModules.service] as Map,
      );
      final selected = service.values.whereType<Map>().fold<int>(
        0,
        (total, actions) =>
            total + actions.values.where((value) => value == true).length,
      );

      expect(selected, 5);
    });

    test('manager and full-access role templates include Service', () {
      final manager = getDefaultPermissions(UserRoles.manager);
      final admin = getDefaultPermissions(UserRoles.admin);

      expect(hasModuleAccess(manager, PermissionModules.service), isTrue);
      expect(hasModuleAccess(admin, PermissionModules.service), isTrue);
    });

    test('legacy Service permissions load without losing hidden keys', () {
      final normalized = mergePermissionsWithCanonicalShape({
        PermissionModules.service: {
          'serviceCalls': {
            PermissionActions.view: true,
            PermissionActions.create: true,
            PermissionActions.delete: true,
          },
          'installation': true,
          'workOrders': {PermissionActions.view: true},
        },
      });
      final service = Map<String, dynamic>.from(
        normalized[PermissionModules.service] as Map,
      );
      final serviceCalls = Map<String, dynamic>.from(
        service[ServiceSubmodules.serviceCalls] as Map,
      );
      final installation = Map<String, dynamic>.from(
        service[ServiceSubmodules.installation] as Map,
      );

      expect(serviceCalls[PermissionActions.view], isTrue);
      expect(serviceCalls[PermissionActions.create], isTrue);
      expect(serviceCalls[PermissionActions.delete], isTrue);
      expect(installation[PermissionActions.view], isTrue);
      expect(service.containsKey('serviceCalls'), isFalse);
      expect(service.containsKey('installation'), isFalse);
      expect(service['workOrders'], isA<Map>());
      expect((service['workOrders'] as Map)[PermissionActions.view], isTrue);
    });
  });
}
