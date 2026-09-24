import 'permission_service.dart';

/// 権限要求の抽象。staticな[PermissionService]を直接呼ばず、
/// この型経由で利用することでControllerの単体テストが可能になる。
abstract class PermissionGateway {
  Future<PermissionRequestResult> requestBlePermissions();

  Future<bool> openSettings();
}

/// 本番実装。既存のstatic APIへの委譲に徹する。
class DefaultPermissionGateway implements PermissionGateway {
  const DefaultPermissionGateway();

  @override
  Future<PermissionRequestResult> requestBlePermissions() =>
      PermissionService.requestBlePermissions();

  @override
  Future<bool> openSettings() => PermissionService.openSettings();
}
