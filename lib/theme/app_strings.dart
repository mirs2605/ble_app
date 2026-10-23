import 'package:flutter/material.dart';

import '../models/app_notice.dart';
import '../services/ble_connection.dart';

/// 画面に表示する日本語文言の集約ポイント。
/// ControllerやWidgetに文字列リテラルを散らばらせないための疎結合層。
/// 文言を変えたい・多言語化したい場合はこのファイルだけを編集する。
abstract final class AppStrings {
  // --- 通知バー ---
  static const specifyRange = '範囲を指定してください';
  static const invalidRange = '清掃範囲が不正です';
  static const sendDone = '送信完了';
  static const sendFailed = '送信に失敗しました';
  static const autoConnectStarted = 'BLE 自動接続を開始';
  static const permissionMissing = 'パーミッション不足';
  static const settingsOpenFailed = 'アプリ設定を開けませんでした';
  static const encloseRange = '範囲を囲ってください';
  static const specifyPose = '開始点をタップし、離さずドラッグで向きを指定';
  static const poseSet = '開始地点を設定しました';
  static const invalidInitialPose = '開始地点の値が不正です';

  // --- ログ（Controller経由） ---
  static const autoConnectGuide = '📡 BLE サーバーに近づくと自動で接続します';
  static String permissionMissingDetails(List<String> deniedNames) =>
      '❌ パーミッション不足: ${deniedNames.join(', ')}';

  // --- 送信ボタン ---
  static const sending = '送信中';
  static const sent = '送信完了';
  static const sendTooltip = '送信';
  static const clearTooltip = '範囲を削除';
  static const clearPoseTooltip = '開始地点を削除';
  static const poseModeTooltip = '開始地点モード';
  static const poseModeExitTooltip = '範囲モードに戻る';
  static const mapsTitle = '地図管理';
  static const addMap = 'スマホから地図を追加';
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

  // --- タブ見出し ---
  static const cleaningAreaTitle = '清掃範囲 (map座標, m)';
  static const initialPoseTitle = '開始地点 (map座標, m)';
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
    AppNotice.autoConnectStarted => AppStrings.autoConnectStarted,
    AppNotice.permissionMissing => AppStrings.permissionMissing,
    AppNotice.settingsOpenFailed => AppStrings.settingsOpenFailed,
    AppNotice.encloseRange => AppStrings.encloseRange,
    AppNotice.specifyPose => AppStrings.specifyPose,
    AppNotice.invalidInitialPose => AppStrings.invalidInitialPose,
  };

  IconData get icon => switch (this) {
    AppNotice.specifyRange ||
    AppNotice.invalidRange ||
    AppNotice.invalidInitialPose => Icons.warning_amber_rounded,
    AppNotice.sendDone => Icons.check_circle,
    AppNotice.sendFailed || AppNotice.settingsOpenFailed => Icons.error_outline,
    AppNotice.autoConnectStarted => Icons.bluetooth_searching,
    AppNotice.permissionMissing => Icons.settings,
    AppNotice.encloseRange => Icons.draw_outlined,
    AppNotice.specifyPose => Icons.my_location,
  };
}
