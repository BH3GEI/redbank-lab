# 镜控手柄 APK

安卓端赤道仪手柄（UDP 直连 192.168.4.1:11880，无服务器）。

功能：
- 十字四向：按住转、松手停（RA=◀▶，DEC=▲▼）
- ■停：双轴急停
- 慢/中/快三档速度（:I 分频 600000 / 200000 / 60000）
- 手动输入：RA°/DEC° 绝对度数 + 「转到」，两轴同时启动，到位提示；「填入当前位置」一键带入
- DEC 软限位：「DEC下限/上限」记录当前度数为边界，越界拒绝

构建（无 Gradle，需 SDK build-tools 35 + platform 35 + JDK17+）：

```bash
./build.sh          # => build/synpad.apk
adb install -r build/synpad.apk
```
