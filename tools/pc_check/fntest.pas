program FnTest;
{ Drives unit FnBus (the real Lisa source) against fake.py. }
uses UnitStd, LSysCall, FnBus, SysUtils;
var rc, st, i, d, mo, y, h, mi, s, fails : integer; t : Str255; nap0 : longint; ok : boolean;
    w0 : QWord; realMs : int64; noClock : boolean;
procedure Chk(what : string; cond : boolean);
begin
  if cond then writeln('ok    ', what) else begin writeln('FAIL  ', what, '   (rc ', rc, ', fnLen ', fnLen, ', fnPlLen ', fnPlLen, ', fnWait ', fnWait, ')'); fails := fails + 1 end
end;
begin
  fails := 0; serQuiet := true;
  noClock := GetEnvironmentVariable('LFJ_NOCLOCK') = '1';
  writeln('mode: naps x', StrToIntDef(GetEnvironmentVariable('LFJ_NAPX'), 1), ', clock ', not noClock);
  FnInit;
  rc := FnReady; Chk('before the port is up, a call is refused as a port error', rc = fnPortEr);
  Chk('port opens', FnPortUp(9600));
  Chk('speed asked of the driver is 9600', serBaud = 9600);
  rc := FnReady; Chk('ready: 512 A''s found after junk text', rc = fnOK);
  rc := FnAdCfg; Chk('adapter config in 5 slow pieces', (rc = fnOK) and (fnPlLen = 140));
  FnPlStr(0, 32, t); Chk('  network name MyNet', t = 'MyNet');
  FnPlStr(33, 63, t); Chk('  host name LISA-FN', t = 'LISA-FN');
  FnPlStr(125, 15, t); Chk('  version 1.6.0', t = '1.6.0');
  Chk('  address 192.168.1.219 (C0 and DB un-escaped)', (FnPlB(97) = 192) and (FnPlB(98) = 168) and (FnPlB(99) = 1) and (FnPlB(100) = 219));
  Chk('  byte outside the data is -1', (FnPlB(140) = -1) and (FnPlB(-1) = -1));
  rc := FnWifi(st); Chk('wifi status 3', (rc = fnOK) and (st = 3));
  rc := FnClock(d, mo, y, h, mi, s); Chk('clock 2026-10-10 17:43:05', (rc = fnOK) and (y = 2026) and (mo = 10) and (d = 10) and (h = 17) and (mi = 43) and (s = 5));
  rc := FnNRead(10); Chk('read before open is refused', rc = fnBadArg);
  t := 'N1:HTTP://example.com/';
  rc := FnNOpen(t, 4, 0); Chk('open + status: 300 waiting, status 1', (rc = fnOK) and fnIsOpen and (fnWait = 300) and (fnStat = 1) and (fnConn = 0));
  rc := FnNRead(257); Chk('read of 257 is refused', rc = fnBadArg);
  rc := FnNRead(0); Chk('read of 0 is refused', rc = fnBadArg);
  rc := FnNRead(256); ok := (rc = fnOK) and (fnPlLen = 256) and (fnWait = 44);
  for i := 0 to 255 do if FnPlB(i) <> ((i * 7 + 185) mod 256) then ok := false;
  Chk('read 256: every byte right, 44 left waiting', ok);
  rc := FnNRead(100); Chk('read of more than is waiting is refused', rc = fnBadArg);
  rc := FnNRead(44); Chk('read 44', (rc = fnOK) and (fnPlLen = 44) and (fnWait = 0));
  rc := FnNRead(1); Chk('read with nothing waiting is refused', rc = fnBadArg);
  rc := FnNStat; Chk('bad checksum is caught', rc = fnBadFr);
  rc := FnNStat; Chk('wrong length is caught', rc = fnBadFr);
  nap0 := serNapMs; w0 := GetTickCount64; rc := FnNStat; realMs := GetTickCount64 - w0; Chk('reply that stops part-way: stall', rc = fnStall);
  writeln('      naps ', serNapMs - nap0, ' ms, real ', realMs, ' ms (fnGap is ', fnGap, ')');
  if noClock then Chk('  no clock: ends by nap count, about 2 s of naps', (serNapMs - nap0 >= 1900) and (serNapMs - nap0 <= 2200))
  else Chk('  ends after 2 to 3 s of REAL time', (realMs >= 1900) and (realMs <= 3200));
  nap0 := serNapMs; w0 := GetTickCount64; rc := FnNStat; realMs := GetTickCount64 - w0; Chk('silence: no reply', rc = fnNoRep);
  writeln('      naps ', serNapMs - nap0, ' ms, real ', realMs, ' ms (fnTmo is ', fnTmo, ')');
  if noClock then Chk('  no clock: ends at exactly 5000 ms of naps', serNapMs - nap0 = 5000)
  else Chk('  ends after 5 to 6 s of REAL time', (realMs >= 4900) and (realMs <= 6200));
  rc := FnNStat; Chk('NAK is reported as NAK', rc = fnNakd);
  rc := FnNStat; Chk('odd command byte is a bad frame', rc = fnBadFr);
  rc := FnNStat; Chk('empty frame before the reply; 40000 waiting fits', (rc = fnOK) and (fnWait = 40000) and (fnConn = 1));
  rc := FnNStat; Chk('700-byte frame is refused, nothing overwritten', rc = fnBadFr);
  rc := FnNStat; Chk('reply with a parameter: data found after it', (rc = fnOK) and (fnOff = 8) and (fnWait = 9) and (fnStat = 1));
  rc := FnNStat; Chk('status 5 waiting', (rc = fnOK) and (fnWait = 5));
  FnNap(600);
  rc := FnNStat; Chk('stale late frame is flushed: fresh answer 7, not 999', (rc = fnOK) and (fnWait = 7));
  rc := FnNStat; Chk('stray C0 00 FF before the reply are ignored (REV F)', (rc = fnOK) and (fnWait = 8));
  fnOut[0] := 72; fnOut[1] := 69; fnOut[2] := 76; fnOut[3] := 76; fnOut[4] := 79;
  rc := FnNWrit(5); Chk('write HELLO', rc = fnOK);
  rc := FnNWrit(257); Chk('write of 257 is refused', rc = fnBadArg);
  rc := FnNClos; Chk('close answered NAK still counts as closed', (rc = fnOK) and not fnIsOpen);
  rc := FnNRead(10); Chk('read after close is refused', rc = fnBadArg);
  rc := FnNWrit(5); Chk('write after close is refused', rc = fnBadArg);
  rc := FnSend(113, 83, 3, 0, 0, 0); Chk('unknown descriptor is refused', rc = fnBadArg);
  rc := FnSend(113, 83, 0, 0, 0, 300); Chk('payload over 256 is refused', rc = fnBadArg);
  t := ''; rc := FnNOpen(t, 4, 0); Chk('empty address is refused', rc = fnBadArg);
  t := 'N1:TCP://h:1/';
  rc := FnNOpen(t, 12, 0); Chk('open again', (rc = fnOK) and (fnConn = 1));
  fnOut[0] := -64; fnOut[1] := -37; fnOut[2] := 65; fnOut[3] := -64;
  rc := FnNWrit(4); Chk('write of C0 DB 41 C0 (escaped on the wire)', (rc = fnOK) and (fnTxLen = 17));
  rc := FnNClos; Chk('close', rc = fnOK);
  FnHex(192, t); Chk('FnHex 192 = C0', t = 'C0'); FnHex(7, t); Chk('FnHex 7 = 07', t = '07');
  FnNum(-946, t); Chk('FnNum -946', t = '-946'); FnNum(40000, t); Chk('FnNum 40000', t = '40000');
  FnPortDn; Chk('port closed', not fnUp);
  writeln; writeln(fails, ' failure(s); ', fnCalls, ' commands sent; most bytes ever held by the driver stand-in: ', serMaxHeld);
end.
