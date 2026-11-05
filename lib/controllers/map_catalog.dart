import 'package:flutter/foundation.dart';

import '../models/map_config.dart';
import '../services/map_config_repository.dart';

/// 登録済み地図の一覧とアクティブな地図を保持する。
/// 永続化は [MapConfigRepository] に委ね、画面の選択状態など他の関心事は知らない。
class MapCatalog extends ChangeNotifier {
  MapCatalog({required MapConfigRepository repository})
    : _repository = repository; // ignore: prefer_initializing_formals

  final MapConfigRepository _repository;
  bool _disposed = false;

  /// DB読み込み完了までは組み込みのデフォルト地図。
  MapConfig _active = BuiltinMaps.gakuseigenkan;
  List<MapConfig> _all = [];

  MapConfig get active => _active;
  List<MapConfig> get all => List.unmodifiable(_all);

  /// DBからアクティブな地図と一覧を読み込む。
  Future<void> load() async {
    if (_disposed) return;
    final active = await _repository.activeMap();
    final all = await _repository.allMaps();
    if (_disposed) return;
    _active = active;
    _all = all;
    notifyListeners();
  }

  /// アクティブな地図を切り替える。切り替えたら true。
  Future<bool> switchTo(MapConfig config) async {
    if (_disposed) return false;
    final id = config.id;
    if (id == null) return false;
    await _repository.setActiveMap(id);
    if (_disposed) return false;
    _active = config;
    notifyListeners();
    return true;
  }

  /// 地図を追加してアクティブにする。追加できたら true。
  Future<bool> add(MapConfig config) async {
    if (_disposed) return false;
    final saved = await _repository.addMap(config);
    await _repository.setActiveMap(saved.id!);
    if (_disposed) return false;
    _active = saved;
    _all = await _repository.allMaps();
    if (_disposed) return false;
    notifyListeners();
    return true;
  }

  /// 地図を削除する。削除できなければ理由を返す（アクティブな地図は削除不可）。
  Future<String?> delete(MapConfig config) async {
    if (_disposed) return null;
    final id = config.id;
    if (id == null) return null;
    try {
      await _repository.deleteMap(id);
    } on StateError catch (e) {
      return e.message;
    }
    if (_disposed) return null;
    _all = await _repository.allMaps();
    if (_disposed) return null;
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
