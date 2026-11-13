import 'package:flutter_test/flutter_test.dart';
import 'package:mirs_ble_app/models/cleaning_zone.dart';
import 'package:mirs_ble_app/models/map_config.dart';
import 'package:mirs_ble_app/models/map_geometry.dart';
import 'package:mirs_ble_app/models/shape_template.dart';

void main() {
  for (final template in ShapeTemplate.all) {
    group(template.label, () {
      test('頂点数が上限以内で、送信検証を通る', () {
        expect(
          template.vertexCount,
          lessThanOrEqualTo(MapGeometry.maxFreehandVertexCount),
        );
        final mission = CleaningZoneMission(polygon: template.placeOn());
        expect(mission.isValid, isTrue);
      });

      test('配置した頂点が地図の範囲内に収まる', () {
        const config = BuiltinMaps.gakuseigenkan;
        for (final p in template.placeOn(config)) {
          expect(
            p.x,
            inInclusiveRange(
              config.originX,
              config.originX + config.widthMeters,
            ),
          );
          expect(
            p.y,
            inInclusiveRange(
              config.originY,
              config.originY + config.heightMeters,
            ),
          );
        }
      });
    });
  }
}
