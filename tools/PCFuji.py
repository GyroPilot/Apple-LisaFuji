#!/usr/bin/env python3
# PCFuji.py  REV C  22-Oct-2026  (REV B 13-Oct, REV A 10-Oct-2026)
# REV C runs the same on Windows, macOS and Linux: the port names and the
# install hints follow the system; nothing else changed.
# REV B adds --lisaem: answer a Lisa running in the LisaEm emulator, whose
# serial port is set to TelnetD.
# A stand-in for the RS-232 FujiNet, for testing LisaFuji before the board
# arrives.  The PC listens on a serial port (the FTDI adapter) and answers
# the FujiBus commands LisaFuji 0.1 sends, the way firmware 1.6 does:
#
#   FujiNet ready     512 letter A's
#   adapter config    "PC-STAND-IN", this PC's name and address
#   web page /config  (REV D) serial_baud= is stored, resetfuji= restarts: what
#                     LisaFuji's Speed menu posts.  Other POSTs go out for real.
#   WiFi status       connected
#   clock             this PC's date and time
#   network unit N1   OPEN really fetches the web address (HTTP or HTTPS)
#                     through this PC; STATUS, READ and CLOSE hand it over
#
# It is NOT a FujiNet: it proves the Lisa's side (port, framing, checksum,
# timeouts, the fetch loop).  The real board still has to be tested.
#
# CABLE: a PC is wired like the Lisa, not like a modem, so this needs the
# NULL-MODEM adapter in line -- the same cabling as LISACom to the PC.
# (The real FujiNet is the opposite: NO null modem.)
#
# Needs Python 3 and the pyserial package:
#   Windows   py -m pip install pyserial
#   macOS     python3 -m pip install pyserial   (a USB-serial adapter needs no driver on 10.15 or later)
#   Linux     python3 -m pip install pyserial   and your user in the dialout group (or run with sudo once)
# Run:   python3 PCFuji.py                 picks the USB-serial adapter, 9600 baud
#        python3 PCFuji.py COM5            a named port (Windows)
#        python3 PCFuji.py /dev/tty.usbserial-A1B2C3   (macOS)
#        python3 PCFuji.py /dev/ttyUSB0 19200           (Linux, and a speed)
#        python3 PCFuji.py --tcp 1990      a network socket instead; for testing
#        python3 PCFuji.py --lisaem        LisaEm, Serial B set to TelnetD (port 9300)
#        python3 PCFuji.py --lisaem 9301   LisaEm, Serial A set to TelnetD
# Stop:  Ctrl-C.
import sys, time, socket, datetime, urllib.request, urllib.error, urllib.parse, re

VERSION = "PCFuji REV D"
END, ESC, ESC_END, ESC_ESC = 0xC0, 0xDB, 0xDC, 0xDD
ACK, NAK = 0x06, 0x15
FIELD_BYTES = [0, 1, 2, 3, 4, 2, 4, 4]      # parameter bytes for descriptor 0..7
OPEN_TIMEOUT = 12                            # seconds; the Lisa waits 15


def checksum(buf):
    c = 0
    for b in buf:
        c += b
        c = (c >> 8) + (c & 0xFF)
    return c & 0xFF


def make_reply(dev, cmd, payload=b""):
    n = 6 + len(payload)
    pkt = bytearray([dev, cmd, n & 0xFF, n >> 8, 0, 0]) + payload
    pkt[4] = checksum(pkt)
    out = bytearray([END])
    for b in pkt:
        if b == END:
            out += bytes([ESC, ESC_END])
        elif b == ESC:
            out += bytes([ESC, ESC_ESC])
        else:
            out.append(b)
    out.append(END)
    return bytes(out)


def hexs(b, limit=24):
    s = " ".join("%02X" % x for x in b[:limit])
    return s + (" ... (%d bytes)" % len(b) if len(b) > limit else "")


def say(msg):
    print(time.strftime("%H:%M:%S ") + msg, flush=True)


# --------------------------------------------------------------------------
# The two kinds of line: a serial port, or a TCP socket for testing.
# --------------------------------------------------------------------------
class SerialLine:
    def __init__(self, port, baud):
        import serial
        self.s = serial.Serial(port, baud, bytesize=8, parity="N", stopbits=1,
                               timeout=0.1, xonxoff=False, rtscts=False, dsrdtr=False)
        try:                      # raise DTR and RTS; harmless if the port cannot
            self.s.dtr = True
            self.s.rts = True
        except Exception:
            pass

    def read(self):
        return self.s.read(256)

    def write(self, data):
        self.s.write(data)
        self.s.flush()

    def reopen(self, baud):
        self.s.baudrate = baud


class TcpLine:
    def __init__(self, port):
        self.srv = socket.socket()
        self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind(("127.0.0.1", port))
        self.srv.listen(1)
        self.c = None

    def read(self):
        if self.c is None:
            self.c, _ = self.srv.accept()
            self.c.settimeout(0.1)
        try:
            d = self.c.recv(256)
        except socket.timeout:
            return b""
        except OSError:
            d = b""
        if not d:
            self.c.close()
            self.c = None
        return d

    def write(self, data):
        if self.c:
            self.c.sendall(data)


class LisaEmLine:
    """LisaEm's TelnetD serial option listens on 127.0.0.1 (9300 for Serial B,
    9301 for Serial A) and speaks a little telnet: when it accepts, it sends
    nine negotiation bytes, and it reads an incoming FF as the start of a
    telnet command (FF FF means one FF).  What the Lisa sends comes through
    raw.  So: connect (again and again until LisaEm is up), drop the nine
    bytes, and double every FF going to the Lisa."""
    HELLO = bytes([0xFF, 0xFB, 0x01, 0xFF, 0xFB, 0x03, 0xFF, 0xFD, 0xF3])

    def __init__(self, port):
        self.port = port
        self.c = None
        self.skip = b""
        self.waiting_said = False

    def connect(self):
        try:
            c = socket.create_connection(("127.0.0.1", self.port), timeout=1)
        except OSError:
            if not self.waiting_said:
                say("waiting for LisaEm on 127.0.0.1:%d (set its serial port to TelnetD) ..." % self.port)
                self.waiting_said = True
            time.sleep(1)
            return
        c.settimeout(0.1)
        self.c, self.skip, self.waiting_said = c, self.HELLO, False
        say("connected to LisaEm on port %d" % self.port)

    def read(self):
        if self.c is None:
            self.connect()
            return b""
        try:
            d = self.c.recv(256)
        except socket.timeout:
            return b""
        except OSError:
            d = b""
        if not d:
            say("LisaEm closed the connection")
            self.c.close()
            self.c = None
            return b""
        while self.skip and d and d[0] == self.skip[0]:
            d, self.skip = d[1:], self.skip[1:]
        self.skip = b"" if d else self.skip
        return d

    def write(self, data):
        if self.c:
            self.c.sendall(data.replace(bytes([0xFF]), bytes([0xFF, 0xFF])))


def pick_port():
    """The FTDI adapter if there is exactly one; otherwise ask."""
    from serial.tools import list_ports
    ports = list(list_ports.comports())
    if not ports:
        hint = "" if sys.platform == "win32" else "  (Linux: is your user in the dialout group?)"
        sys.exit("No serial ports found.  Is the USB-serial adapter plugged in?" + hint)
    ftdi = [p for p in ports if p.vid == 0x0403 or "FTDI" in (p.manufacturer or "").upper()]
    if len(ftdi) == 1:
        return ftdi[0].device
    if len(ports) == 1:
        return ports[0].device
    print("Serial ports on this computer:")
    for i, p in enumerate(ports, 1):
        print("  %d  %s  %s" % (i, p.device, p.description))
    while True:
        a = input("Which number? ").strip()
        if a.isdigit() and 1 <= int(a) <= len(ports):
            return ports[int(a) - 1].device


# --------------------------------------------------------------------------
# The pretend FujiNet.
# --------------------------------------------------------------------------
class Fuji:
    def __init__(self):
        self.is_open = False
        self.data = b""
        self.pos = 0
        self.status = 0
        self.failed = False
        self.method = "GET"          # REV D: a POST or PUT waits for the first STATUS in body mode
        self.chan = 0                # SET_HTTP_MODE: 0 body, 4 post data
        self.post = b""
        self.spec = ""
        self.pending = False
        self.dead_until = 0.0        # restarting: no answer until then
        self.baud = 9600             # the stored speed, as fnconfig.ini holds it
        self.restart = False         # main loop: reopen a serial line at self.baud

    def my_address(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("192.0.2.1", 9))
            ip = s.getsockname()[0]
            s.close()
            return bytes(int(x) for x in ip.split("."))
        except OSError:
            return bytes([127, 0, 0, 1])

    def adapter_config(self):
        cfg = bytearray(140)
        def put(off, size, text):
            t = text.encode("ascii", "replace")[:size - 1]
            cfg[off:off + len(t)] = t
        put(0, 33, "PC-STAND-IN")
        put(33, 64, socket.gethostname())
        ip = self.my_address()
        cfg[97:101] = ip
        cfg[101:105] = ip[:3] + bytes([1])
        cfg[105:109] = bytes([255, 255, 255, 0])
        cfg[109:113] = ip[:3] + bytes([1])
        put(125, 15, "PCFuji B")
        return bytes(cfg)

    def fetch(self, spec):
        """spec is the Lisa's device spec, e.g. N1:HTTP://host/path."""
        url = re.sub(r"^[Nn]\d?:", "", spec.strip())
        m = re.match(r"^([A-Za-z]+)(://.*)$", url)
        if not m or m.group(1).lower() not in ("http", "https"):
            say("   only HTTP and HTTPS are handled here; answering status 207")
            return b"", 207
        url = m.group(1).lower() + m.group(2)
        req = urllib.request.Request(url, headers={"User-Agent": "PCFuji/A (LisaFuji test)"})
        try:
            with urllib.request.urlopen(req, timeout=OPEN_TIMEOUT) as r:
                return r.read(), 1
        except urllib.error.HTTPError as e:
            body = e.read() if e.fp else b""
            say("   the server answered HTTP %d" % e.code)
            return body, 170
        except Exception as e:
            say("   could not reach the server: %s" % e)
            return b"", 207

    def web_config(self, body):
        """The FujiNet's /config form, the two fields LisaFuji uses: serial_baud= is stored (it takes
        effect at the next start, as on the real one); resetfuji= restarts: silent for 3 seconds, then
        back at the stored speed."""
        fields = urllib.parse.parse_qs(body)
        if "serial_baud" in fields:
            self.baud = int(fields["serial_baud"][0])
            say("   web page /config: serial_baud=%d saved (used from the next restart)" % self.baud)
        if "resetfuji" in fields:
            say("   web page /config: Reset FujiNet -> silent for 3 s, then back at %d baud" % self.baud)
            self.dead_until = time.time() + 3
            self.restart = True
        if not fields:
            say("   web page /config: empty form")

    def transact(self):
        """The first STATUS in body mode sends a POST or PUT: to this PC's own web page when the
        address is ours (the FujiNet's /config form), otherwise for real."""
        self.pending = False
        url = re.sub(r"^[Nn]\d?:", "", self.spec.strip())
        m = re.match(r"^([A-Za-z]+)://([^/]*)(/.*)?$", url)
        if not m or m.group(1).lower() not in ("http", "https"):
            say("   only HTTP and HTTPS are handled here; answering status 207")
            self.data, self.status, self.failed, self.pos = b"", 207, True, 0
            return
        host, path = m.group(2), m.group(3) or "/"
        mine = ".".join(str(x) for x in self.my_address())
        if host.split(":")[0] in (mine, "127.0.0.1", "localhost") and path == "/config":
            self.web_config(self.post.decode("latin1"))
            self.data, self.status, self.failed, self.pos = b"", 1, False, 0
            return
        req = urllib.request.Request(m.group(1).lower() + "://" + host + path, data=self.post,
                                     method=self.method,
                                     headers={"User-Agent": "PCFuji/D (LisaFuji test)",
                                              "Content-Type": "application/x-www-form-urlencoded"})
        say("   %s %s, %d bytes of data" % (self.method, host + path, len(self.post)))
        try:
            with urllib.request.urlopen(req, timeout=OPEN_TIMEOUT) as r:
                self.data, self.status = r.read(), 1
        except urllib.error.HTTPError as e:
            self.data, self.status = (e.read() if e.fp else b""), 170
            say("   the server answered HTTP %d" % e.code)
        except Exception as e:
            self.data, self.status = b"", 207
            say("   could not reach the server: %s" % e)
        self.failed = self.status != 1
        self.pos = 0

    def handle(self, pkt):
        """One request packet in, one reply frame out (or None = stay silent)."""
        if time.time() < self.dead_until:
            say("   (restarting: no answer, as the real one)")
            return None
        if len(pkt) < 6:
            say("?? %d-byte packet, too short: no reply (as the FujiNet does)" % len(pkt))
            return None
        dev, cmd, length, chk, desc = pkt[0], pkt[1], pkt[2] | pkt[3] << 8, pkt[4], pkt[5]
        z = bytearray(pkt)
        z[4] = 0
        if length != len(pkt) or checksum(z) != chk:
            say("?? BAD FRAME from the Lisa (length says %d, got %d; checksum %s): no reply"
                % (length, len(pkt), "ok" if checksum(z) == chk else "WRONG"))
            return None
        npar = FIELD_BYTES[desc & 7]
        params, payload = pkt[6:6 + npar], pkt[6 + npar:]

        if dev == 0x70:                                   # FujiNet control
            if cmd == 0x00:
                say("<- FujiNet ready?            -> 512 letter A's")
                return make_reply(dev, ACK, b"A" * 512)
            if cmd == 0xE8:
                say("<- adapter config?           -> name, address, version")
                return make_reply(dev, ACK, self.adapter_config())
            if cmd == 0xFA:
                say("<- WiFi status?              -> 3 (connected)")
                return make_reply(dev, ACK, b"\x03")
        elif dev == 0x45:                                 # clock
            if npar < 1:
                say("?? clock command with NO parameter byte: a real FujiNet would restart")
                return None
            now = datetime.datetime.now()
            if cmd == 0x93:
                say("<- clock?                    -> %s" % now.strftime("%Y-%m-%d %H:%M:%S"))
                return make_reply(dev, ACK, bytes([now.day, now.month, now.year - 2000,
                                                   now.hour, now.minute, now.second]))
            if cmd == 0x49:
                txt = now.astimezone().strftime("%Y-%m-%dT%H:%M:%S%z").encode() + b"\0"
                say("<- clock as text?            -> %s" % txt[:-1].decode())
                return make_reply(dev, ACK, txt)
        elif dev == 0x71:                                 # network unit N1
            if cmd == 0x4F:
                if npar < 2:
                    say("?? OPEN without its two parameters: a real FujiNet would restart")
                    return None
                spec = payload.split(b"\0")[0].decode("latin1")
                mode = params[0]
                if mode in (8, 12, 13, 14):               # REV D: write, both, POST, PUT with headers
                    self.method = "POST" if mode in (13, 14) else "PUT"
                    self.spec, self.pending, self.chan, self.post = spec, True, 0, b""
                    self.data, self.status, self.pos, self.is_open, self.failed = b"", 1, 0, True, False
                    say("<- OPEN mode %d (%s) %s" % (mode, self.method, spec))
                    say("   -> ACK; the request goes out on the first STATUS in body mode")
                    return make_reply(dev, ACK)
                say("<- OPEN %s" % spec)
                self.data, self.status = self.fetch(spec)
                self.pos, self.is_open = 0, True
                self.failed = self.status != 1
                say("   -> ACK; status %d, %d bytes waiting, check %d"
                    % (self.status, len(self.data), sum(self.data) % 65536))
                return make_reply(dev, ACK)
            if cmd == 0x53:
                if self.pending and self.chan == 0:
                    self.transact()
                left = len(self.data) - self.pos
                st = self.status
                if self.is_open and left == 0 and st == 1:
                    st = 136                              # end of data
                say("<- STATUS?                   -> %d waiting, status %d" % (left, st))
                w = min(left, 65535)
                return make_reply(dev, ACK, bytes([w & 0xFF, w >> 8, 0, st]))
            if cmd == 0x52:
                if npar < 2:
                    say("?? READ without its count: a real FujiNet would restart")
                    return None
                n = params[0] | params[1] << 8
                left = len(self.data) - self.pos
                if not self.is_open:
                    say("?? READ of a unit that is not open (this crashes a real FujiNet) -> NAK")
                    return make_reply(dev, NAK)
                if n > left or n == 0:
                    say("?? READ %d but only %d waiting -> NAK" % (n, left))
                    return make_reply(dev, NAK)
                chunk = self.data[self.pos:self.pos + n]
                self.pos += n
                say("<- READ %-3d                  -> %d bytes (%d left)" % (n, len(chunk), left - n))
                return make_reply(dev, ACK, chunk)
            if cmd == 0x57:
                if self.is_open and (self.chan == 4 or (self.chan == 0 and self.pending and self.method == "PUT")):
                    self.post += payload
                    say("<- WRITE %d bytes            -> ACK (post data, %d so far)" % (len(payload), len(self.post)))
                    return make_reply(dev, ACK)
                say("<- WRITE %d bytes            -> ACK (thrown away here)" % len(payload))
                return make_reply(dev, ACK)
            if cmd == 0x4D:
                if npar < 2:
                    say("?? SET_HTTP_MODE without its two parameters -> NAK")
                    return make_reply(dev, NAK)
                if not self.is_open:
                    say("<- SET_HTTP_MODE %d on a closed unit -> NAK" % params[1])
                    return make_reply(dev, NAK)
                self.chan = params[1]
                names = {0: "body", 1: "collect headers", 2: "read headers", 3: "write headers", 4: "write post data"}
                say("<- SET_HTTP_MODE %d            -> ACK (%s)" % (self.chan, names.get(self.chan, "?")))
                return make_reply(dev, ACK)
            if cmd == 0x43:
                was_failed = self.failed
                self.is_open, self.data, self.pos, self.status, self.failed = False, b"", 0, 0, False
                self.pending, self.chan, self.post, self.method = False, 0, b"", "GET"
                say("<- CLOSE                     -> %s" % ("NAK (as the FujiNet does after a failure)"
                                                            if was_failed else "ACK"))
                return make_reply(dev, NAK if was_failed else ACK)
        else:
            say("<- unknown device %02X         -> NAK" % dev)
            return make_reply(0x00, NAK)
        say("<- device %02X command %02X not handled here -> NAK" % (dev, cmd))
        return make_reply(dev, NAK)


def main():
    args = sys.argv[1:]
    if args and args[0] == "--tcp":
        line = TcpLine(int(args[1]))
        where = "TCP port %s" % args[1]
    elif args and args[0] == "--lisaem":
        n = int(args[1]) if len(args) > 1 else 9300
        line = LisaEmLine(n)
        where = "LisaEm's TelnetD port %d (Serial %s)" % (n, "B" if n == 9300 else "A" if n == 9301 else "?")
    else:
        try:
            import serial  # noqa: F401
        except ImportError:
            pip = "py -m pip install pyserial" if sys.platform == "win32" else "python3 -m pip install pyserial"
            sys.exit("This needs the pyserial package.  Run:   " + pip)
        port = args[0] if args else pick_port()
        baud = int(args[1]) if len(args) > 1 else 9600
        try:
            line = SerialLine(port, baud)
        except Exception as e:
            sys.exit("Could not open %s: %s\n(Is another program, such as a terminal, using it?)" % (port, e))
        where = "%s at %d baud, 8 data bits, no parity, no handshake" % (port, baud)
    print("%s -- a stand-in FujiNet for testing LisaFuji." % VERSION)
    print("Listening on %s." % where)
    if isinstance(line, LisaEmLine):
        print("LisaEm: Preferences > Ports, Serial B = TelnetD, port 9300 (Serial A: 9301).")
    else:
        print("Cable: Lisa Serial B, WITH the null-modem adapter, to this PC.")
    print("On the Lisa: open LisaFuji and press A.  Ctrl-C here to stop.\n")
    fuji = Fuji()
    if isinstance(line, SerialLine):
        fuji.baud = line.s.baudrate
    buf, in_frame, esc, stray = bytearray(), False, False, 0
    try:
        while True:
            data = line.read()
            for b in data:
                if b == END:
                    if in_frame and buf:
                        say("   bytes from the Lisa: C0 %s C0" % hexs(bytes(buf)))
                        reply = fuji.handle(bytes(buf))
                        if reply:
                            line.write(reply)
                        if fuji.restart:                  # REV D: the pretend restart
                            fuji.restart = False
                            if isinstance(line, SerialLine):
                                line.reopen(fuji.baud)
                                say("   serial line now at %d baud" % fuji.baud)
                        buf, in_frame, esc = bytearray(), False, False
                    else:
                        in_frame, esc, buf = True, False, bytearray()
                elif in_frame:
                    if esc:
                        buf.append(END if b == ESC_END else ESC if b == ESC_ESC else b)
                        esc = False
                    elif b == ESC:
                        esc = True
                    else:
                        buf.append(b)
                else:
                    stray += 1
            if stray and not data:
                say("?? %d stray byte(s) outside any frame (wrong speed, or a terminal typing?)" % stray)
                stray = 0
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
