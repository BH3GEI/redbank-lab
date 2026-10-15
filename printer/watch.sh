#!/bin/bash
# 每小时记录一次 A1 状态 + 摄像头照片，打印结束（FINISH/FAILED）后再记一次就退出
cd /tmp/bambu2/watch
while true; do
  ts=$(date +%Y%m%d-%H%M)
  s=$(/tmp/bambu-venv/bin/python /tmp/bambu/mqtt_status.py 2>&1 | grep -E '"gcode_state"|print_error|mc_percent|layer_num"|bed_temper"|nozzle_temper"|mc_remaining|subtask_name' | tr -d '\n ')
  echo "$ts $s" >> log.txt
  /tmp/bambu-venv/bin/python /tmp/bambu/cam_snap.py "snap-$ts.jpg" >/dev/null 2>&1
  case "$s" in *'"gcode_state":"FINISH"'*|*'"gcode_state":"FAILED"'*|*'"gcode_state":"IDLE"'*) echo "$ts END" >> log.txt; exit 0;; esac
  sleep 3600
done
