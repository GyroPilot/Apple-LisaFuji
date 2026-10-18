#!/usr/bin/env python3
"""Fault-injecting stand-in for a FujiNet, for fntest.pas.  Each request the
Pascal unit sends is checked against the bytes it should be, then answered
in a deliberately awkward way."""
import socket, sys, time
from fujibus import raw_packet, slip, decode, hexs, checksum
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 1987
ACK, NAK = 0x06, 0x15
def frame(dev, cmd, payload=b"", params=()):
    return slip(raw_packet(dev, cmd, params, payload))
def H(s): return bytes.fromhex(s.replace(" ", ""))
adcfg = bytearray(140)
adcfg[0:5] = b"MyNet"; adcfg[33:40] = b"LISA-FN"; adcfg[97:101] = bytes([192,168,1,219])
adcfg[125:130] = b"1.6.0"
blob = bytes((i * 7 + 0xB9) & 0xFF for i in range(256))      # contains C0 and DB
assert 0xC0 in blob and 0xDB in blob
bad_chk = bytearray(raw_packet(0x71, ACK, (), bytes([1,0,0,1]))); bad_chk[4] ^= 0x55
bad_len = bytearray(raw_packet(0x71, ACK, (), bytes([1,0,0,1]))); bad_len[2] += 1
z = bytearray(bad_len); z[4] = 0; bad_len[4] = checksum(z)      # checksum right, length wrong
steps = [
 # (expected request hex or None, description, list of (delay, bytes) to send)
 ("C0 70 00 06 00 76 00 C0", "ready, junk text first", [(0, b"\r\nCONNECT 9600\r\n" + frame(0x70, ACK, b"A"*512))]),
 ("C0 70 E8 06 00 5F 00 C0", "adapter config in 5 pieces", "pieces"),
 ("C0 70 FA 06 00 71 00 C0", "wifi", [(0, frame(0x70, ACK, b"\x03"))]),
 ("C0 45 93 07 00 E0 01 00 C0", "clock", [(0, frame(0x45, ACK, bytes([10,10,26,17,43,5])))]),
 ("C0 71 4F 1F 00 06 02 04 00 4E 31 3A 48 54 54 50 3A 2F 2F 65 78 61 6D 70 6C 65 2E 63 6F 6D 2F 00 C0", "open", [(0, frame(0x71, ACK))]),
 ("C0 71 53 06 00 CA 00 C0", "status 300 waiting", [(0, frame(0x71, ACK, bytes([0x2C,1,0,1])))]),
 ("C0 71 52 08 00 D1 05 00 01 C0", "read 256", [(0, frame(0x71, ACK, blob))]),
 (hexs(frame(0x71, 0x52, params=[(2,44)])), "read 44", [(0, frame(0x71, ACK, blob[:44]))]),
 ("C0 71 53 06 00 CA 00 C0", "status, bad checksum", [(0, slip(bytes(bad_chk)))]),
 ("C0 71 53 06 00 CA 00 C0", "status, wrong length", [(0, slip(bytes(bad_len)))]),
 ("C0 71 53 06 00 CA 00 C0", "status, stops part-way", [(0, frame(0x71, ACK, bytes([1,0,0,1]))[:6])]),
 ("C0 71 53 06 00 CA 00 C0", "status, silence", []),
 ("C0 71 53 06 00 CA 00 C0", "status, NAK", [(0, frame(0x71, NAK))]),
 ("C0 71 53 06 00 CA 00 C0", "status, odd command byte", [(0, frame(0x71, 0x99, bytes([1,0,0,1])))]),
 ("C0 71 53 06 00 CA 00 C0", "status, empty frame first, 40000 waiting", [(0, b"\xC0\xC0" + frame(0x71, ACK, bytes([0x40,0x9C,1,1]))[1:])]),
 ("C0 71 53 06 00 CA 00 C0", "status, 700-byte frame", [(0, frame(0x71, ACK, b"x"*694))]),
 ("C0 71 53 06 00 CA 00 C0", "status, reply carries a parameter", [(0, frame(0x71, ACK, bytes([9,0,0,1]), params=[(2,0x1234)]))]),
 ("C0 71 53 06 00 CA 00 C0", "status, then a stale frame arrives late", [(0, frame(0x71, ACK, bytes([5,0,0,1]))), (0.3, frame(0x71, ACK, bytes([0xE7,3,0,1])))]),
 ("C0 71 53 06 00 CA 00 C0", "status after the stale frame", [(0, frame(0x71, ACK, bytes([7,0,0,1])))]),
 ("C0 71 53 06 00 CA 00 C0", "status behind stray bytes (C0 00 FF)", [(0, bytes([0xC0, 0x00, 0xFF]) + frame(0x71, ACK, bytes([8,0,0,1])))]),
 (hexs(frame(0x71, 0x57, b"HELLO", params=[(2,5)])), "write 5", [(0, frame(0x71, ACK))]),
 ("C0 71 43 06 00 BA 00 C0", "close answered NAK", [(0, frame(0x71, NAK))]),
 (hexs(frame(0x71, 0x4F, b"N1:TCP://h:1/\0", params=[(1,12),(1,0)])), "open again", [(0, frame(0x71, ACK))]),
 ("C0 71 53 06 00 CA 00 C0", "status", [(0, frame(0x71, ACK, bytes([0,0,1,1])))]),
 (hexs(frame(0x71, 0x57, bytes([0xC0,0xDB,0x41,0xC0]), params=[(2,4)])), "write with C0 and DB in it", [(0, frame(0x71, ACK))]),
 ("C0 71 43 06 00 BA 00 C0", "close", [(0, frame(0x71, ACK))]),
]
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", PORT)); srv.listen(1)
c, _ = srv.accept(); c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
def get_frame():
    buf = bytearray()
    while True:
        b = c.recv(1)
        if not b: return None
        if not buf and b[0] != 0xC0: continue
        buf += b
        if len(buf) > 1 and b[0] == 0xC0: return bytes(buf)
bad = 0
for n, (want, what, sends) in enumerate(steps):
    f = get_frame()
    if f is None: print("fake: connection closed early at step", n); bad += 1; break
    got = hexs(f)
    okay = (got == want)
    if okay: decode(f)          # also proves length and checksum
    print("fake %2d %-40s request %s" % (n, what, "as expected" if okay else "WRONG\n   got  %s\n   want %s" % (got, want)))
    bad += 0 if okay else 1
    if sends == "pieces":
        fr = frame(0x70, ACK, bytes(adcfg)); k = len(fr) // 5 + 1
        sends = [(0.2 if i else 0, fr[i:i+k]) for i in range(0, len(fr), k)]
    for delay, data in sends:
        time.sleep(delay); c.sendall(data)
extra = c.recv(100) if False else b""
c.settimeout(1.0)
try:
    more = c.recv(100)
    if more: print("fake: UNEXPECTED extra bytes:", hexs(more)); bad += 1
except socket.timeout: pass
print("fake: %d steps, %d wrong requests" % (len(steps), bad))
