unit SimCfg; interface
{ lfj.cfg: line 1 key script, line 2 TCP port standing in for Serial B,
  line 3 OPEN ecode to fake (0 = port opens), line 4 abort a fetch after
  this many network reads (0 = never). }
var cfScript : string; cfPort, cfOpenEc, cfAbort : longint;
implementation
var f : text;
begin
  assign(f, 'lfj.cfg'); reset(f);
  readln(f, cfScript); readln(f, cfPort); readln(f, cfOpenEc); readln(f, cfAbort);
  close(f);
end.
