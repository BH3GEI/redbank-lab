# redbank-lab

RedBank 望远镜项目（RB-EQ / v09）从 CAD 到电机上电的全套工程工具。

面向的硬件场景：

- **打印机**：Bambu Lab A1，全流程无 GUI（CLI 切片 + FTPS 上传 + MQTT 下发/监控）
- **赤道仪**：SynScan 协议的自制赤道仪（UDP 11880 → 192.168.4.1）
- **控制端**：Root 安卓手机（红魔 NX809J），手机与赤道仪同处其 Wi-Fi 热点

```
CAD (OpenSCAD) ──► STL ──► BambuStudio CLI 切片 ──► FTPS 上传 ──► MQTT 启动打印
                                                    │
赤道仪 ◄──UDP 11880── 手机 (Go 常驻 / 安卓 APK 手柄) ─┘ (打印与望远镜互不相干，仅共用无 GUI 思路)
```

## 目录

| 目录 | 内容 |
|---|---|
| [`printer/`](printer/) | Bambu A1 无 GUI 打印流水线：切片 gcode 模板合并、FTPS 上传、MQTT 状态/截图/控制、打印监控 |
| [`printer/profiles/`](printer/profiles/) | 机器/工艺/耗材 JSON 配置（0.28mm 快打档、80°C PETG 库存） |
| [`cad/`](cad/) | v09 核心 SCAD（含 `fdm_fill_windows` FDM 改型）、四角立柱 SCAD、STL、发布件（STL+预切片 3mf+STEP） |
| [`mount-relay/`](mount-relay/) | 手机端 Go 常驻程序：TCP→UDP 转发守护、全自动巡天扫描、网页手柄 |
| [`android-apk/`](android-apk/) | 安卓手柄 APK「镜控手柄」源码与无 Gradle 构建脚本（十字键按住即转 / 急停 / 三档速度 / 手动输入 RA-DEC 转到 / DEC 限位） |
| [`docs/`](docs/) | 协议与踩坑文档 |

## 快速上手

### 打印（Bambu A1，无 GUI）

```bash
# 1. 切片（必须用 flatten.py 合并机器模板，见 docs/bambu-cli-printing.md 的大坑）
python3 printer/flatten.py ...
# 2. 上传 + 启动 + 监控
python3 printer/start_print.py    # FTPS 上传并下发打印
python3 printer/mqtt_status.py    # 实时进度
python3 printer/cam_snap.py       # 拍摄热床
```

### 手机端手柄（APK）

```bash
cd android-apk && ./build.sh && adb install -r build/synpad.apk
```

### 手机端 Go 守护

```bash
cd mount-relay && ./build-synrelayd.sh   # 或 synsurveyd / synpadd
adb push synrelayd/synrelayd /data/local/tmp/
adb shell "su -c 'setsid /data/local/tmp/synrelayd &'"   # TCP 11881 → 赤道仪 UDP
```

## 文档

- [`docs/synscan-protocol.md`](docs/synscan-protocol.md) —— 实测验证过的 SynScan UDP 协议指令集
- [`docs/bambu-cli-printing.md`](docs/bambu-cli-printing.md) —— CLI 切片的致命坑（机器模板 include 不合并 → 喷头只有 205°C）与完整流程
- [`docs/network-notes.md`](docs/network-notes.md) —— 手机/赤道仪/macmini 网络架构与踩坑记录

## 姊妹仓库

- [BH3GEI/redbank-cad](https://github.com/BH3GEI/redbank-cad) —— CAD 模型在线预览站（RB-EQ / RB-1X / RB-FX 全节点）
