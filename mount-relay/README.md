# 手机端赤道仪程序（Go, GOOS=android）

| 程序 | 功能 |
|---|---|
| `synrelayd/` | TCP 11881 收一行指令 → UDP 转发赤道仪 → 回传应答（mac/远端遥控用） |
| `synsurveyd/` | 全自动巡天：双轴同步、RA 90°/DEC 60° 蛇形、每点停 10s、结束回原点；`touch /data/local/tmp/survey.stop` 刹停 |
| `synpadd/` | 网页手柄（:8080）：按住即转/急停/三档速度/实时度数/DEC 限位；后续由 APK 版取代 |

构建：`./build-synrelayd.sh` 等（即 `GOOS=android GOARCH=arm64 go build`）。
部署：

```bash
adb push synsurveyd/synsurveyd /data/local/tmp/
adb shell "su -c 'chmod 755 /data/local/tmp/synsurveyd; setsid /data/local/tmp/synsurveyd &'"
```

协议细节：`docs/synscan-protocol.md`。**DEC 不可低于地平线**，自动化先设限位。
