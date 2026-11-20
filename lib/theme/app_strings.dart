import 'package:flutter/material.dart';

import '../models/app_notice.dart';
import '../models/ble_status.dart';

/// 画面に表示する日本語文言の集約ポイント。
/// ControllerやWidgetに文字列リテラルを散らばらせないための疎結合層。
/// 文言を変えたい・多言語化したい場合はこのファイルだけを編集する。
abstract final class AppStrings {
  // --- 通知バー ---
  static const specifyRange = '範囲を指定してください';
  static const invalidRange = '清掃範囲が不正です';
  static const sendDone = '送信完了';
  static const sendFailed = '送信に失敗しました';
  static const invalidSchedule = '定時清掃の設定が不正です';
  static const scheduleSaved = '予定を保存しました（ロボットとは未同期）';
  static const scheduleSynced = 'ロボットと予定を同期しました';
  static const scheduleSyncFailed = '同期に失敗しました（予定は保存済み）';
  static const autoConnectStarted = 'BLE 自動接続を開始';
  static const permissionMissing = 'パーミッション不足';
  static const settingsOpenFailed = 'アプリ設定を開けませんでした';
  static const encloseRange = '範囲を囲ってください';

  // --- ログ（Controller経由） ---
  static const autoConnectGuide = '📡 BLE サーバーに近づくと自動で接続します';
  static String permissionMissingDetails(List<String> deniedNames) =>
      '❌ パーミッション不足: ${deniedNames.join(', ')}';
  static String shapeTemplatePlacedLog(String label) =>
      '⭐ 「$label」のひな形を配置しました';
  static String freehandSelectedLog(int count) => '🖐️ $count点の範囲を選択しました';

  // --- 範囲選択・ひな形 ---
  static const shapeTemplateTooltip = 'ひな形';
  static String shapeTemplateItem(String label, int vertexCount) =>
      '$label（$vertexCount点）';
  static String vertexCountLabel(int count) => '点数 $count';
  static const mapImageLoadError = '地図画像を読み込めません';
  static const openPermissionSettingsTooltip = '権限設定を開く';

  // --- 送信ボタン ---
  static const sending = '送信中';
  static const sent = '送信完了';
  static const sendTooltip = '送信';
  static const clearTooltip = '範囲を削除';
  static const scheduleTabTitle = '予定一覧';
  static const scheduleHelp =
      'ロボットが決まった時刻に清掃を始めます。予定はスマホとロボットの両方に保存され、接続すると自動で同期します。';
  static const scheduleEmpty = '予定はまだありません';
  static const scheduleAddTitle = '地図で囲んだ範囲を予定に追加';
  static const scheduleTimeLabel = '開始時刻';
  static const scheduleWeekdaysLabel = '曜日';
  static const scheduleAdd = '追加';
  static const scheduleSync = 'ロボットと同期';
  static const scheduleDeleteTooltip = '予定を削除';
  static const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];
  static const everyDay = '毎日';

  /// 曜日の集合の表示（全曜日なら「毎日」）。
  static String weekdaysText(Set<int> weekdays) {
    if (weekdays.length == 7) return everyDay;
    final days = weekdays.toList()..sort();
    return days.map((d) => weekdayLabels[d - 1]).join('・');
  }

  static String scheduleSyncLog(int stored, int pushed) =>
      '🔄 予定を同期しました（受信 $stored 件 / 送信 $pushed 件）';
  static const mapsTitle = '地図管理';
  static const addMap = 'スマホから地図を追加';
  static const receiveMap = 'ロボットから地図を受信';
  static const receiveMapNeedsConnection = 'ロボットに接続すると受信できます';
  static const mapReceived = '地図を受信しました';
  static const mapReceiveFailed = '地図を受信できませんでした（詳細はログ）';
  static String mapReceiveStart(String name, int size) =>
      '📥 地図「$name」を受信します ($size bytes)';
  static String mapReceiveDone(String name) => '✅ 地図「$name」を登録しました';
  static const mapDetailsTitle = '地図情報';
  static const mapName = '地図名';
  static const mapResolution = '解像度 (m/px)';
  static const mapResolutionHelp = '地図画像の対応する map.yaml の値';
  static const mapOriginX = '原点 X (m)';
  static const mapOriginY = '原点 Y (m)';
  static const requiredField = '入力してください';
  static const positiveNumberRequired = '0より大きい数値を入力してください';
  static const numberRequired = '有効な数値を入力してください';
  static const cancel = 'キャンセル';
  static const delete = '削除';
  static const close = '閉じる';
  static const deleteMapTitle = '地図を削除';
  static const detectedMapDimensionsLabel = '画像サイズ:';
  static const mapOperationFailedLabel = '地図を変更できませんでした:';

  static String detectedMapDimensions(int width, int height) =>
      '$detectedMapDimensionsLabel $width × $height px';
  static String deleteMapConfirm(String name) => '「$name」を削除しますか？';
  static String mapOperationFailed(String message) =>
      '$mapOperationFailedLabel $message';

  // --- Bluetoothステータス ---
  static const showBluetoothStatus = 'Bluetoothステータスを表示';

  // --- タブ見出し・ナビゲーション ---
  static const mapsTabLabel = '地図';
  static const mapTabLabel = 'マップ';
  static const scheduleTabLabel = '予定';
  static const logsTabLabel = 'ログ';
  static const logsTitle = 'ログ';

  /// 接続状態の表示ラベル。
  static String bleStatusLabel(BleStatus status) => switch (status) {
    BleStatus.idle => '未接続',
    BleStatus.scanning => '検索中',
    BleStatus.connecting => '接続中',
    BleStatus.connected || BleStatus.sending => '接続済み',
    BleStatus.disconnected => '切断',
    BleStatus.error => 'エラー',
  };
}

/// [AppNotice] から表示内容への解決。文言・アイコンを返す。
/// 通知バーの色は常にグレー（深刻度による色分けなし）。
extension AppNoticePresentation on AppNotice {
  String get message => switch (this) {
    AppNotice.specifyRange => AppStrings.specifyRange,
    AppNotice.invalidRange => AppStrings.invalidRange,
    AppNotice.sendDone => AppStrings.sendDone,
    AppNotice.sendFailed => AppStrings.sendFailed,
    AppNotice.invalidSchedule => AppStrings.invalidSchedule,
    AppNotice.scheduleSaved => AppStrings.scheduleSaved,
    AppNotice.scheduleSynced => AppStrings.scheduleSynced,
    AppNotice.scheduleSyncFailed => AppStrings.scheduleSyncFailed,
    AppNotice.autoConnectStarted => AppStrings.autoConnectStarted,
    AppNotice.permissionMissing => AppStrings.permissionMissing,
    AppNotice.settingsOpenFailed => AppStrings.settingsOpenFailed,
    AppNotice.encloseRange => AppStrings.encloseRange,
  };

  IconData get icon => switch (this) {
    AppNotice.specifyRange ||
    AppNotice.invalidRange ||
    AppNotice.invalidSchedule => Icons.warning_amber_rounded,
    AppNotice.sendDone ||
    AppNotice.scheduleSaved ||
    AppNotice.scheduleSynced => Icons.check_circle,
    AppNotice.sendFailed ||
    AppNotice.scheduleSyncFailed ||
    AppNotice.settingsOpenFailed => Icons.error_outline,
    AppNotice.autoConnectStarted => Icons.bluetooth_searching,
    AppNotice.permissionMissing => Icons.settings,
    AppNotice.encloseRange => Icons.draw_outlined,
  };
}
