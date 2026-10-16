/// マップ1枚分のメタデータ。DB行と1対1に対応する。
///
/// [assetPath] は `assets/maps/xxx.png` 形式のFlutter asset path。
/// [resolution]・[originX]・[originY] はROS map.yamlと同一単位 [m]。
/// [imageWidth]・[imageHeight] はPNG画像の寸法 [px]。
class MapConfig {
  final int? id;
  final String name;
  final String assetPath;
  final double resolution;
  final double originX;
  final double originY;
  final double imageWidth;
  final double imageHeight;

  const MapConfig({
    this.id,
    required this.name,
    required this.assetPath,
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.imageWidth,
    required this.imageHeight,
  });

  double get widthMeters => imageWidth * resolution;
  double get heightMeters => imageHeight * resolution;
  double get aspectRatio => imageWidth / imageHeight;
  bool get isValid =>
      name.trim().isNotEmpty &&
      assetPath.trim().isNotEmpty &&
      resolution.isFinite &&
      resolution > 0 &&
      originX.isFinite &&
      originY.isFinite &&
      imageWidth.isFinite &&
      imageWidth > 0 &&
      imageHeight.isFinite &&
      imageHeight > 0;

  MapConfig copyWith({int? id}) => MapConfig(
    id: id ?? this.id,
    name: name,
    assetPath: assetPath,
    resolution: resolution,
    originX: originX,
    originY: originY,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'asset_path': assetPath,
    'resolution': resolution,
    'origin_x': originX,
    'origin_y': originY,
    'image_width': imageWidth,
    'image_height': imageHeight,
  };

  factory MapConfig.fromMap(Map<String, dynamic> map) => MapConfig(
    id: map['id'] as int?,
    name: map['name'] as String,
    assetPath: map['asset_path'] as String,
    resolution: (map['resolution'] as num).toDouble(),
    originX: (map['origin_x'] as num).toDouble(),
    originY: (map['origin_y'] as num).toDouble(),
    imageWidth: (map['image_width'] as num).toDouble(),
    imageHeight: (map['image_height'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is MapConfig &&
      other.id == id &&
      other.name == name &&
      other.assetPath == assetPath &&
      other.resolution == resolution &&
      other.originX == originX &&
      other.originY == originY &&
      other.imageWidth == imageWidth &&
      other.imageHeight == imageHeight;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    assetPath,
    resolution,
    originX,
    originY,
    imageWidth,
    imageHeight,
  );

  @override
  String toString() => 'MapConfig(id: $id, name: $name)';
}

/// アプリ同梱のデフォルトマップ定義。DB未登録時のシードデータ。
abstract final class BuiltinMaps {
  static const double gakuseigenkanResolution = 0.05;
  static const double gakuseigenkanOriginX = -66.619;
  static const double gakuseigenkanOriginY = -44.476;
  static const double gakuseigenkanImageWidth = 2857;
  static const double gakuseigenkanImageHeight = 1677;

  static const gakuseigenkan = MapConfig(
    name: '学生会館',
    assetPath: 'assets/maps/gakuseigenkan.png',
    resolution: gakuseigenkanResolution,
    originX: gakuseigenkanOriginX,
    originY: gakuseigenkanOriginY,
    imageWidth: gakuseigenkanImageWidth,
    imageHeight: gakuseigenkanImageHeight,
  );

  static const mirsMap = MapConfig(
    name: 'MIRS',
    assetPath: 'assets/maps/mirs_map.png',
    resolution: 0.05,
    originX: -3.238,
    originY: -4.542,
    imageWidth: 303,
    imageHeight: 225,
  );

  static const List<MapConfig> all = [gakuseigenkan, mirsMap];
}
