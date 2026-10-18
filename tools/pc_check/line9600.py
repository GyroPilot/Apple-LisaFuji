#!/usr/bin/env python3
"""A pretend serial line between the test build and the software FujiNet.
Bytes from the FujiNet are let through at 9600 baud pace (960 a second,
a few at a time), the way a real Lisa would see them.  The FujiNet side
stays connected while the 'Lisa' opens and closes its port, as a cable
would.  Usage: line9600.py listen_port fujinet_port [bytes_per_second]"""
import socket, sys, threading, time
LP, UP = int(sys.argv[1]), int(sys.argv[2])
RATE = float(sys.argv[3]) if len(sys.argv) > 3 else 960.0
up = socket.create_connection(("127.0.0.1", UP)); up.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", LP)); srv.listen(1)
cli = None; lock = threading.Lock(); maxq = 0
def downstream():
    global cli
    due = time.time()
    while True:
        data = up.recv(4096)
        if not data: return
        for i in range(0, len(data), 8):
            chunk = data[i:i+8]
            due = max(due, time.time()) + len(chunk) / RATE
            time.sleep(max(0, due - time.time()))
            with lock:
                c = cli
            if c:
                try: c.sendall(chunk)
                except OSError: pass
threading.Thread(target=downstream, daemon=True).start()
while True:
    c, _ = srv.accept(); c.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    with lock: cli = c
    while True:
        try: d = c.recv(4096)
        except OSError: d = b""
        if not d: break
        up.sendall(d)
    with lock: cli = None
    c.close()
