import json, ssl, sys, time
import paho.mqtt.client as mqtt
SERIAL="03900D691320718"; ACCESS=open('/tmp/bambu/.code').read().strip()
cmd=json.loads(sys.argv[1])
acks=[]
def on_connect(c,u,f,rc,props=None):
    c.subscribe(f"device/{SERIAL}/report"); c.publish(f"device/{SERIAL}/request", json.dumps(cmd)); print("sent",cmd)
def on_message(c,u,msg):
    p=json.loads(msg.payload).get("print",{})
    if p.get("command")==cmd["print"]["command"]: print("ACK",{k:p.get(k) for k in("result","reason")})
    if "gcode_state" in p: acks.append(p["gcode_state"])
cli=mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, protocol=mqtt.MQTTv311)
cli.username_pw_set("bblp",ACCESS); cli.tls_set(cert_reqs=ssl.CERT_NONE); cli.tls_insecure_set(True)
cli.on_connect=on_connect; cli.on_message=on_message; cli.connect("192.168.3.82",8883,10)
t=time.time()
while time.time()-t<8: cli.loop(timeout=1)
print("states seen", acks[-3:])
