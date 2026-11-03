LisaFuji 1.2, update 1 (3 November 2026, release build REV AC)      tool 419312
Same LisaFuji 1.2 program with these changes, tested on a Lisa 2/10 through an ESProFile running ESPFuji on 3
November 2026; the floppy LISAFUJI_1_2.dc42 replaces the earlier one of the same name:
- Test 2 through an ESProFile shows the network name, the address, the ESPFuji firmware and the WiFi signal
  (e.g. "strong (-35 dBm)").
- A failed connection through an ESProFile now shows the ESProFile's own reason ("the drive said: ...")
  instead of only "status 207".
- It looks for the mailbox as "ESPFuji Mailbox" first, then MAILBOX.DATA, so old setups keep working.
- A damaged TWINYEAR.DATA no longer stops it setting the clock: the note is remade, or kept in TWINYEAR2.DATA,
  and the newer good one is read (as LisaTwinClock).

--------------------------------------------------------------------------------------------------------------

LisaFuji 1.2 for the Apple Lisa Office System       30 October 2026 (release build REV Z)
News, Wikipedia, the space station, who is aboard, the weather, the network clock.  Tool 419312.

New in this build: works through an ESPFuji ESProFile (https://github.com/GyroPilot/ESPFuji) as well as an RS-232
FujiNet or a LisaNet: put LisaFuji on the ESProFile's volume and it finds the mailbox at launch, no serial adapter.
A failed fetch says why in words; P on page 1 steps back out.  Floppy image LISAFUJI_1_2.dc42 (replaces the 1.2 beta
of 23 October); the source zip has the Lisa Pascal sources and the exec files.  Built with the Lisa Workshop 3.0 in
LisaEm; the mailbox route tested on a Lisa 2/10 (28-29 Oct 2026), the last wording changes in LisaEm.
