#!/usr/bin/env python3
"""Query Bambu A1 status over local MQTT (TLS, port 8883)."""
import json, ssl, sys, time
import paho.mqtt.client as mqtt

IP = "192.168.3.82"
SERIAL = "03900D691320718"
ACCESS = "24292210"

report = {}
done = False

def on_connect(c, u, f, rc, props=None):
    if rc != 0:
        print("connect rc", rc); sys.exit(1)
    c.subscribe(f"device/{SERIAL}/report")
    c.publish(f"device/{SERIAL}/request",
              json.dumps({"pushing": {"sequence_id": "1", "command": "pushall"}}))

def on_message(c, u, msg):
    global done
    try:
        d = json.loads(msg.payload)
    except Exception:
        return
    p = d.get("print", {})
    if "gcode_state" in p or "ams" in p:
        report.update(p)
    if "gcode_state" in report and "ams" in report:
        done = True

cli = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, protocol=mqtt.MQTTv311)
cli.username_pw_set("bblp", ACCESS)
cli.tls_set(cert_reqs=ssl.CERT_NONE)
cli.tls_insecure_set(True)
cli.on_connect = on_connect
cli.on_message = on_message
cli.connect(IP, 8883, 10)
t0 = time.time()
while not done and time.time() - t0 < 15:
    cli.loop(timeout=1)

keys = ["gcode_state","print_error","mc_percent","mc_remaining_time","layer_num",
        "total_layer_num","nozzle_temper","nozzle_target_temper","bed_temper",
        "bed_target_temper","wifi_signal","spd_lvl","gcode_file","subtask_name",
        "print_type","home_flag"]
out = {k: report.get(k) for k in keys if k in report}
ams = report.get("ams", {})
trays = []
for unit in ams.get("ams", []):
    for t in unit.get("tray", []):
        trays.append({k: t.get(k) for k in ("id","tray_type","tray_sub_brands","tray_color","remain")})
vt = report.get("vt_tray")
if vt:
    trays.append({"id":"ext(vt)","tray_type":vt.get("tray_type"),"tray_sub_brands":vt.get("tray_sub_brands"),"tray_color":vt.get("tray_color"),"remain":vt.get("remain")})
out["trays"] = trays
print(json.dumps(out, ensure_ascii=False, indent=1))
