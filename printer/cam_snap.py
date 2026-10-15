import socket, ssl, struct, sys, re
code = re.search(r'"03900D691320718"\s*:\s*"([^"]+)"', open('/Users/yao/Library/Application Support/BambuStudio/BambuStudio.conf').read()).group(1)
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
s = ctx.wrap_socket(socket.create_connection(("192.168.3.82", 6000), timeout=10))
s.sendall(struct.pack('<IIII', 0x40, 0x3000, 0, 0) + b'bblp'.ljust(32, b'\0') + code.encode().ljust(32, b'\0'))
def rd(n):
    b=b''
    while len(b)<n:
        c=s.recv(n-len(b))
        if not c: raise SystemExit('closed')
        b+=c
    return b
for i in range(2):
    hdr = rd(16); size = struct.unpack('<I', hdr[:4])[0]
    img = rd(size)
open(sys.argv[1] if len(sys.argv)>1 else 'snap.jpg','wb').write(img); print(len(img))
