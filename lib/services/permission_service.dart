import 'package:permission_handler/permission_handler.dart';

class PermissionRequestResult {
  final bool isGranted;
  final bool permanentlyDenied;
  final List<String> deniedNames;

  const PermissionRequestResult({
    required this.isGranted,
    required this.permanentlyDenied,
    required this.deniedNames,
  });
}

class PermissionService {
  const PermissionService._();

  static Future<bool> openSettings() => openAppSettings();

  static Future<PermissionRequestResult> requestBlePermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    final statuses = await permissions.request();
    final denied = statuses.entries.where((entry) => !entry.value.isGranted);
    return PermissionRequestResult(
      isGranted: denied.isEmpty,
      permanentlyDenied: denied.any((entry) => entry.value.isPermanentlyDenied),
      deniedNames: denied.map((entry) => entry.key.toString()).toList(),
    );
  }
}
