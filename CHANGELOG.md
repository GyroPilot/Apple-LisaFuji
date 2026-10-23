# LisaFuji changelog

## 1.2 beta REV T -- 23 Oct 2026 -- the 1.2 beta release floppy (tested on the 2/10, 23 Oct)
- The launch-time probe: at the first port open LisaFuji tries the saved speed, then the other of 9600/19200, with a
  short wait for the ready reply, keeps what answers and saves it; so it follows an adapter another tool changed.
  FnBus: fnFound, FnFind, FnSpdMsg (shared with TwinClock, Checkers, Salvo and the Browser). On the 2/10: opened
  with no saved speed, found the adapter at 19200 and drew the station map.
## 1.2 beta REV S -- 22 Oct 2026 -- tested on the Lisa 2/10 at 19200 baud (22 Oct)
- The Speed menu sets the FujiNet too: a form POST of serial_baud= to the adapter's own web page through its N:
  device (the RS-232 FujiNet has no speed command), then its Reset button, then the port again at the new speed and
  the ready test. The choice and the port are kept in FNSPEED.DATA beside the tool. An adapter that does not answer
  at the old speed is taken to be at the new one already. FnBus: FnPost, FnSetBd, FnCfgSv, FnCfgLd.
- PCFuji REV D: HTTP POST/PUT on the N: unit and a stand-in for the adapter's /config page (serial_baud= stored,
  resetfuji= makes it silent for 3 s and reopens a real serial line at the new speed).
## 1.2 beta REV R -- 19 Oct 2026
- The FujiNet on Serial A or Serial B (Speed menu: Use Serial A / Use Serial B).
## 1.2 beta REV Q -- 19 Oct 2026
- The world map drawn in bands (Z times it).
## 1.1 REV P -- 17-19 Oct 2026 -- RELEASE, tested on the Lisa 2/10 (19 Oct)
- The weather page draws a picture for each day and a big one for now (sun, moon, clouds, rain, snow, storm, fog),
  with QuickDraw shapes only.
## 1.1 REV O -- 17 Oct 2026
- P: who is aboard the space stations. O: the weather in your town. A Weather menu. The pane can line up columns
  (tab stops). The main program's code is split into three segments to make room.
## 1.0 REV N / REV M -- 17 Oct 2026 -- RELEASE 1.0
- The version shown as 1.0; the map page's spare line points to the crew. Tested on the 2/10 with a real FujiNet.
## 0.6 REV J-L -- 16-17 Oct 2026
- The space station page (I) and your town (T), then the world map with the station's path for the next 90 minutes.
## 0.5 REV E-I -- 14-16 Oct 2026
- C sets the Lisa's clock from the network (the twin year). Reliability on the real FujiNet: frame resync, CLOSE
  before and after every OPEN, a 25-second wait for the first STATUS after an OPEN (the board fetches then).
## 0.4 REV D -- 14 Oct 2026
- Wikipedia: search and read, page by page. Accented letters folded to plain ones.
## 0.2-0.3 REV B-C -- 12-13 Oct 2026
- The news reader. Timeouts measured by the real clock.
## REV A -- 10 Oct 2026
- First build: the FujiNet test tool (link tests, fetch a web file, show the last bytes).
