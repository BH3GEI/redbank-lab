#!/usr/bin/env python3
"""Start printing an uploaded 3mf on the A1 via local MQTT."""
import json, ssl, sys, time
import paho.mqtt.client as mqtt

IP = "192.168.3.82"
SERIAL = "03900D691320718"
ACCESS = "24292210"
FILE = "shell_front_v09_sliced.3mf"

state = {}
sent = False

def on_connect(c, u, f, rc, props=None):
    if rc != 0:
        print("connect rc", rc); sys.exit(1)
    c.subscribe(f"device/{SERIAL}/report")
    cmd = {
        "print": {
            "sequence_id": "100",
            "command": "project_file",
            "param": "Metadata/plate_1.gcode",
            "project_id": "0",
            "profile_id": "0",
            "task_id": "0",
            "subtask_id": "0",
            "subtask_name": "shell_front_v09",
            "url": f"file:///sdcard/{FILE}",
            "md5": "",
            "timelapse": False,
            "bed_type": "textured_plate",
            "bed_levelling": True,
            "flow_cali": False,
            "vibration_cali": False,
            "layer_inspect": False,
            "use_ams": False,
        }
    }
    c.publish(f"device/{SERIAL}/request", json.dumps(cmd))
    global sent; sent = True
    print("print command sent")

def on_message(c, u, msg):
    try:
        d = json.loads(msg.payload)
    except Exception:
        return
    p = d.get("print", {})
    if p.get("command") == "project_file":
        print("ACK:", json.dumps({k: p.get(k) for k in ("command","result","reason","errno")}))
    for k in ("gcode_state", "mc_percent", "subtask_name", "print_error"):
        if k in p:
            state[k] = p[k]

cli = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, protocol=mqtt.MQTTv311)
cli.username_pw_set("bblp", ACCESS)
cli.tls_set(cert_reqs=ssl.CERT_NONE)
cli.tls_insecure_set(True)
cli.on_connect = on_connect
cli.on_message = on_message
cli.connect(IP, 8883, 10)
t0 = time.time()
while time.time() - t0 < 25:
    cli.loop(timeout=1)
print("final state:", json.dumps(state, ensure_ascii=False))
