/// Bluetoothステータスとは無関係な独立通知の種別。
///
/// UI文言・アイコン・色を持たない純粋なドメインコード。
/// 表示内容への解決はテーマ層 ([AppStrings] / [PillStyles]) が担い、
/// Controllerはこのenumだけを知っていればよい。
enum AppNotice {
  specifyRange,
  invalidRange,
  sendDone,
  sendFailed,
  autoConnectStarted,
  permissionMissing,
  settingsOpenFailed,
  encloseRange,
}
