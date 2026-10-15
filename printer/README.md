# Bambu A1 无 GUI 打印流水线

| 文件 | 作用 |
|---|---|
| `flatten.py` | **核心**：递归合并机器预设的 `include` 模板（不合并则喷头温度错） |
| `start_print.py` | FTPS 上传 gcode + MQTT 启动打印 |
| `mqtt_status.py` | 订阅 report，实时进度/层号 |
| `cam_snap.py` | 经 FTPS 拉热床照片 |
| `send_cmd.py` | 暂停/停止 |
| `watch.sh` | 每小时快照+日志 |
| `profiles/` | machine / process_A2(0.28快打) / filament80(PETG) 配置 |
| `start_variants/` | 按次改 FILE/subtask 的启动变体 |

详细流程与坑：`docs/bambu-cli-printing.md`
