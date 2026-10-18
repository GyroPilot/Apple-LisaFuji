# LisaFuji

A FujiNet client for the Apple Lisa Office System: the news, Wikipedia, where the International Space Station is (on a
world map, with how far it is from your town), who is aboard the space stations, the weather in your town (with a
little picture for each day), and the time from the network -- through a FujiNet for RS-232 on Serial B.

Tool number **419312** in the GyroPilot series. Written in Lisa Pascal with the Workshop 3.0 toolchain for Lisa Office
System 3.1.

## Status

- **1.0** -- tested on a Lisa 2/10 with a real FujiNet, 17 October 2026 (`releases/LISAFUJI_1_0.dc42`).
- **1.1** -- who is aboard (P), the weather in your town with pictures (O), the Weather menu. Built and tested in
  LisaEm; waiting for its check on the 2/10 (`releases/LISAFUJI_1_1_TEST.dc42`). The sources here are 1.1 (REV P).

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

Speed menu: 9600 (start here) or 19200; it must match the FujiNet's own setting.

**Hardware:** a FujiNet for RS-232 (FutureVision Research) on Serial B with a straight serial cable (the FujiNet is
wired like a modem: no null modem). No FujiNet? `tools/PCFuji.py` stands in for one on a PC with a USB-serial adapter
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
