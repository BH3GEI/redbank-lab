# 网络架构与踩坑记录

目标拓扑：Mac（室内局域网）── 无线 ── 手机（在赤道仪旁）── Wi-Fi ── 赤道仪。

## 实际可用路径（2026-10 状态）

```
手机 app / Go 守护 ──UDP──► 192.168.4.1:11880 (SynScan 热点网段)
     ▲
     └── adb over USB（调试/部署用）
```

控制端跑在手机上（APK 或 Go 守护），手机与赤道仪同处热点网段，**不跨网**。
手机再通过 USB adb 连任何一台电脑用于部署。

### 手机上部署 Go 程序

```bash
GOOS=android GOARCH=arm64 go build -o xxx main.go
adb push xxx /data/local/tmp/
adb shell "su -c 'chmod 755 /data/local/tmp/xxx; setsid /data/local/tmp/xxx &'"
```

`setsid` + 后台 = 拔 USB 不死。日志写 `/data/local/tmp/*.log`。

## 踩坑清单

1. **Android 16 无法用命令行开蓝牙网络共享**：
   `cmd connectivity startTethering` 不存在，`service call connectivity 50 ...`
   事务号猜不中。唯一可靠途径是设置界面点开关
   （移动网络 → 个人热点 → 更多热点设置 → 蓝牙网络共享）。
2. **macOS ↔ 安卓蓝牙 PAN**：安卓侧配对成功 ≠ macOS 侧配对成功；
   ssh 进 macOS 的进程**没有蓝牙 TCC 权限**，IOBluetooth 查询全是假结果
   （pairedDevices 返回空、isPaired false），别信，只信设置界面。
3. **Wi-Fi STA + SoftAP 并发**：红魔 NX809J (SD 8 Gen) 支持连 SynScan 热点的
   同时开个人热点，两者不互踢。
4. **在 macmini 上让 Wi-Fi 加入新网络会抢默认路由**：macOS 服务顺序里 Wi-Fi
   高于以太网时，加入一个无外网的热点（如 SynScan）会把默认路由黑洞化，
   frpc 等长连接全断 → ssh 失联。若必须双网，先
   `networksetup -ordernetworkservices "Ethernet,Wi-Fi,..."`
   并给热点网段加静态路由，再连接。
5. **adb 走 frp 隧道时**：macmini 的 ssh 是 `dmit1` (154.17.17.154) 上的
   frps 转发的（`macmini-1-ssh` 代理，远端 41701）。frpc 掉线 = ssh 断，
   先看 `journalctl -u frps`。
6. **carrier 会掐 4G 长连接**：frpc over 手机蜂窝 ~40s 即被运营商断流，
   不要指望 4G 上的长连接隧道做实时控制。
7. **安卓 toybox `nc`**：`-L` 服务模式可以带 COMMAND 参数，但对程序退出/
   回传语义很怪，写 Go 交叉编译程序更省事。
8. **root 手机跑 UDP**：无需 root 也能发 UDP 到热点网段，root 仅用于
   `setsid` 常驻与端口操作。
