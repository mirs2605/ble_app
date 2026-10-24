# スマホの清掃範囲をPCで表示する

## 構成

1. AndroidアプリがBLEで範囲を送信します。
2. BluetoothアダプターのあるロボットLinux上で `mirs2605/ble_server` を起動します。サーバーはROS 2の `/cleaning_zone` (`geometry_msgs/msg/PolygonStamped`) に範囲をpublishします。
3. PCのUbuntu WSLではこのワークスペースを起動します。OpenNav Coverage（Fields2Coverを使った経路計画）が範囲から経路を作り、RViz2に範囲と `/coverage/path` を表示します。

このPCのWSLにはROS 2 JazzyとRViz2が入っていますが、WSLからBluetoothアダプターは見えません。BLEサーバーはBluetoothを使えるロボット側で動かしてください。PC側の `mirs_pc_viewer` は経路を計算・表示するだけで、Nav2の走行アクションを送りません。

## PC (Ubuntu 24.04 / ROS 2 Jazzy) のセットアップ

このFlutterリポジトリをWSLから `/mnt/c/Users/kurea/project/ble_app` として開ける状態にします。

```bash
sudo apt update
sudo apt install -y python3-colcon-common-extensions python3-vcstool python3-rosdep \
  ros-jazzy-nav2-lifecycle-manager ros-jazzy-nav2-util ros-jazzy-nav2-msgs \
  ros-jazzy-nav2-common ros-jazzy-fields2cover
sudo rosdep init 2>/dev/null || true
rosdep update
mkdir -p ~/mirs_ros_ws/src
cd ~/mirs_ros_ws/src
vcs import . < /mnt/c/Users/kurea/project/ble_app/ros2_ws/opennav_coverage.repos
cp -r /mnt/c/Users/kurea/project/ble_app/ros2_ws/src/mirs_pc_viewer .
cd ~/mirs_ros_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src/mirs_pc_viewer \
  src/open-navigation/opennav_coverage/opennav_coverage \
  src/open-navigation/opennav_coverage/opennav_coverage_msgs \
  --ignore-src -r -y --skip-keys ament_python
colcon build --symlink-install --packages-up-to mirs_pc_viewer \
  --cmake-args -DBUILD_TESTING=OFF
```

`opennav_coverage.repos` はOpenNav CoverageのROS 2 Jazzy対応ソース一式を取得します。ビルド後、ロボットとPCで同じROS_DOMAIN_IDを設定し、ネットワーク経由でDDS通信できるようにします。WSL2のネットワーク設定やファイアウォールによっては、ROS 2のマルチキャスト通信が通らない場合があります。

`ble_server` もこのワークスペースにcloneされます。BLEアダプターを持つロボット側では、Ubuntu/ROS 2環境でこのパッケージをビルドし、BlueZとPython D-Bus依存関係を用意してから起動します（リポジトリREADMEの通り `ros2 run ble_server ble_receiver_node`）。実機側パッケージのインストール先はPCのWSLとは別です。

ロボット側にまだパッケージがない場合は、そのROS 2 Jazzy環境で `ble_server` リポジトリをcloneし、`colcon build --packages-select ble_server` でビルドしてください。実行は同じROS_DOMAIN_IDの環境で `ros2 run ble_server ble_receiver_node` です。BLE受信サーバーはロボットのBluetoothアダプターとBlueZ上で起動してください。

アプリが選ぶ座標とロボット側の地図で座標系・単位を一致させてください。経路幅の初期値は `config/coverage_server.yaml` の `robot_width` / `operation_width` です。実機に合わせて調整します。

## 起動

PC側のWSLで:

```bash
source /opt/ros/jazzy/setup.bash
source ~/mirs_ros_ws/install/setup.bash
export ROS_DOMAIN_ID=0
ros2 launch mirs_pc_viewer preview.launch.py
```

ロボット側でもROS 2のセットアップを読み込み、同じ `ROS_DOMAIN_ID=0` で `ble_server` を起動します。アプリから範囲を送ると、RVizに境界線（青）と計画経路（橙）が表示されます。ROSグラフを確認するコマンド:

```bash
ros2 topic echo /cleaning_zone
ros2 topic echo /coverage/state
ros2 topic echo /coverage/path
```

`mirs2605/coverage` の既定executorは経路作成後にNav2の走行アクションも送るため、このプレビュー構成では使いません。

## Phone + PC simulation over USB

This mode replaces the robot BLE receiver with an HTTP gateway on the PC. The Android app posts the selected polygon through an ADB reverse tunnel. The gateway publishes `/cleaning_zone`; OpenNav Coverage computes a path and RViz shows it. No robot or BLE server is needed in this mode.

1. In WSL, start the ROS 2 preview and leave it running:

   ```bash
   source /opt/ros/jazzy/setup.bash
   source ~/mirs_ros_ws/install/setup.bash
   export ROS_DOMAIN_ID=0
   ros2 launch mirs_pc_viewer preview.launch.py
   ```

   The launch log should say `Phone simulation gateway listening on 0.0.0.0:8765`.
2. On Windows PowerShell, with the phone connected and USB debugging authorized, create the tunnel (use the full adb path if `adb` is not on PATH):

   ```powershell
   adb reverse tcp:8765 tcp:8765
   adb reverse --list
   ```
3. From the Flutter project directory, run the app in simulation mode:

   ```powershell
   flutter run -d R5CW4094JYH --dart-define=SIMULATION_MODE=true
   ```
4. Draw a cleaning zone on the map and send it. The gateway log should report the received point count; RViz should show the zone and calculated path. `/coverage/state` reports planning progress.

To rebuild after changing the ROS package:

```bash
cd ~/mirs_ros_ws
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install --packages-up-to mirs_pc_viewer --cmake-args -DBUILD_TESTING=OFF
source install/setup.bash
```

When you use the app's start-pose mode, the simulation gateway publishes a
`geometry_msgs/msg/PoseWithCovarianceStamped` message to `/initialpose`, shown in
RViz. This is a visualization/simulation input and does not move a robot.
