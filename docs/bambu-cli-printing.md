# Bambu A1 无 GUI 打印全流程（及一个致命坑）

目标：完全脱离 Bambu Studio GUI，在命令行完成 切片 → 上传 → 启动 → 监控。

## 致命坑：机器模板 `include` 不合并 → 喷头温度错误

**现象**：用 BambuStudio CLI 切出的 gcode 直接打印，PETG 喷头只有 205°C（应 245°C），
首层粘不住，连续打废两次。

**根因**：Bambu 的机器/耗材预设是层层 `include` 引用的模板文件（`.json` 里带
`include` 字段）。`headless` CLI 路径**不会递归合并这些 include**，导致
machine start gcode（含 `M104/M109 S245`、调平 `G29` 等）缺失或用了默认值。

**解法**：[`printer/flatten.py`](../printer/flatten.py) 在切片前把预设模板全部递归
合并展开成一份"扁平"配置再喂给 CLI。合并后的 gcode 应包含：

```
M109 S245   （喷头到达温度，PETG）
M190 S80    （热床）
G29         （自动调平）
```

**每次打新材质前必须核对这三条存在。**

## 流程

1. **切片**

   ```bash
   /Applications/BambuStudio.app/Contents/MacOS/BambuStudio \
     --slice stl文件 \
     --curr-bed-type "Textured PEI Plate" \
     --load-机器/工艺/耗材.json ...
   ```

   本仓库 `printer/profiles/` 提供实测可用的组合：
   - `machine.json` —— A1 机器参数（展开后的扁平模板）
   - `process_A2.json` —— 0.28mm 层高快打：2 墙 10% 填充、外壁 100/内壁 160 mm/s、
     accel 3000、normal(auto) snug 支撑（40° 阈值 / 0.28mm 离层 / 0 界面层）、10mm 裙边
   - `filament80.json` —— PETG 热床 80°C

   v09 前壳 284g / 10.9h。

2. **上传**：FTPS（隐式 TLS）到打印机，用户 `bblp`，访问码见 `~/.bambu` 或机身屏幕
   （`printer/start_print.py` 内实现）。

3. **启动**：MQTT 发布 `device/{SN}/request` 的 `print.start`，带 filename/task 名
   （`start_print.py`；按次改文件名用 `start_variants/` 里的变体）。

4. **监控**：
   - `mqtt_status.py` —— 订阅 `device/{SN}/report`，进度/层号/错误
   - `cam_snap.py` —— via FTPS 拉取 `cam_*.jpg`（热床照片）
   - `watch.sh` —— 每小时快照 + 日志落盘

5. **紧急控制**：`send_cmd.py`（pause / stop）。

## 其他实测经验

- A1 支撑：normal(auto) snug + 40° + 0.28mm 离层 + 0 界面层 → 易拆不塌
- 悬空窗口（v09 屏仓减重窗）在 FDM 下必须填实（见 `cad/core_v09.scad` 的
  `fdm_fill_windows` 参数），否则支柱必倒
- 0.28mm 层高 + 100/160 mm/s 的组合在 A1 上质量可接受，比 0.2 精细档省约 40% 时间
- 小件（四角立柱 26×26×32）1.18h / 28g
