# LisaFuji

A FujiNet client for the Apple Lisa Office System: the news, Wikipedia, where the International Space Station is (on a
world map, with how far it is from your town), who is aboard the space stations, the weather in your town (with a
little picture for each day), and the time from the network -- through a FujiNet for RS-232 on Serial B.

Tool number **419312** in the GyroPilot series. Written in Lisa Pascal with the Workshop 3.0 toolchain for Lisa Office
System 3.1.

## Status

- **1.0** -- tested on a Lisa 2/10 with a real FujiNet, 17 October 2026 (`releases/LISAFUJI_1_0.dc42`).
- **1.1** -- who is aboard (P), the weather in your town with pictures (O), the Weather menu. Tested on the 2/10,
  19 October 2026 (`releases/LISAFUJI_1_1.dc42`).
- **1.2 beta** -- the Speed menu sets the FujiNet too: Use 19200 baud posts the new speed to the adapter's own web
  page through the FujiNet's network device, restarts it and follows it (no more editing the SD card). The choice,
  with the port (Serial A or Serial B, new as well), is kept in FNSPEED.DATA beside the tool. Tested on the 2/10 at
  19200 baud, 22 October 2026 (`releases/LISAFUJI_1_2.dc42`). The sources here are 1.2 beta (REV T: the launch-time speed probe, 23 October).

## Using it

Open LisaFuji; every key is on the start page:

| Key | What it does |
|---|---|
| N | the news: nine categories, headlines, articles page by page (fujinet.online) |
| S | search Wikipedia and read an article page by page |
| I | the space station on a world map: where it is, its path for the next 90 minutes, your town; height, speed, sunlight, distance and direction from you, above or below your horizon |
| P | who is aboard the space stations (the people-in-space list at corquaid.github.io) |
| O | the weather in your town: now, and three days of sky, high, low and chance of rain (open-meteo.com, no key) |
| T | set your town (looked up at open-meteo.com; kept in HOMETOWN.DATA beside the tool) |
| C | set the Lisa's clock from the network, the "twin year" way (2026 -> 1987: the same calendar) |
| A, 1-3 | the link tests: FujiNet ready, adapter and WiFi, network clock |
| F, B | fetch a web file; show the last bytes sent and received |

Speed menu: Use 9600 baud / Use 19200 baud sets BOTH ends: LisaFuji tells the FujiNet through its own web page (so
the adapter's WiFi must be up), restarts it and opens the port again at the new speed, about 20 seconds in all. Use
Serial A / Use Serial B picks the port. Both choices are kept in FNSPEED.DATA beside the tool. A new adapter runs at
whatever its fnconfig.ini says (9600 as shipped for the Lisa): start there and choose 19200 once.

**Hardware:** a FujiNet for RS-232 (FutureVision Research) on Serial B with a straight serial cable (the FujiNet is
wired like a modem: no null modem). No FujiNet? `tools/PCFuji.py` stands in for one on a Windows, macOS or Linux computer with a USB-serial adapter
(and for LisaEm over its TelnetD serial port), for everything but the board's WiFi.

**Installing:** open the floppy and the hard disk side by side, select LisaFuji, Duplicate, and drag the duplicate
to the hard disk straight away.

## Layout

See SOURCES.txt. `sources/` holds the Lisa Pascal units and the Workshop exec files (LFJ-MAKE builds everything,
then LFJ-INSTALL registers the tool); `tools/` the PC side: the world-map generator, the page formatter, PCFuji, and
the Free Pascal check harness with its stand-ins for the Lisa units.

## Credits

Tim O'Connor (bmwcyclist on LisaList2, GyroPilot on GitHub), with Claude (Anthropic). Lisa Pascal with the Lisa
Workshop 3.0 for Lisa Office System 3.1; built in LisaEm and proven on a Lisa 2/10 and a LisaFPGA with a FutureVision
Research FujiNet for RS-232.
