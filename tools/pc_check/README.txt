PC check harness for LisaFuji (not needed on the Lisa).
Free Pascal 3.2.2, mode MacPas (16-bit integers), Linux.  The .pas files
are stand-ins for the Lisa units (SysCall as LSysCall, Events, Menus ...).
The stand-in for Serial B is a TCP socket.

  sh prep.sh          makes test copies of ../sources_raw/LFJ-*.TEXT
                      (run as:  S=../sources_raw sh prep.sh)
  fpc -Mmacpas -Cr -Co -Sh- lisafuji.pas
  fpc -Mmacpas -Cr -Co -Sh- fntest.pas

  lfj.cfg = four lines: key script, TCP port, OPEN ecode to fake (0 = the
  port opens), stop a fetch after this many reads (0 = never).
  Script: letters and digits are keys, ~ RETURN, < Backspace, ^x Apple-x,
  @mi menu m item i, ! print the screen now.

  Unit test:      python3 fake.py 1987 &      then  ./fntest   (port 1987)
  Real firmware:  run fujinet-pc (RS232 build, BoIP port 1985), then
                  python3 line9600.py 1986 1985 &   (9600-baud pacing)
                  and run ./lisafuji with port 1986 in lfj.cfg.
  preflight.py <Lisa_Source folder or -> FILE.TEXT ...   the source checks.
