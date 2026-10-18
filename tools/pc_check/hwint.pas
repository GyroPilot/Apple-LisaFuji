unit HwInt; interface
{ Stand-in for the Lisa hardware library's clock calls (LisaFuji REV E harness).
  DateTime gives the PC's time until SetDateTime has been called; after that
  it gives back what was set, so TwSet's read-back matches, as on a Lisa. }
type DateArray = record year, day, hour, minute, second : integer end;
var simClock : DateArray; simSet : boolean;
procedure DateTime(var date : DateArray);
procedure SetDateTime(date : DateArray);
implementation
uses SysUtils, DateUtils;
procedure DateTime(var date : DateArray);
var y, m, d, h, mi, s, ms : word; n : TDateTime;
begin
  if simSet then begin date := simClock; exit end;
  n := Now;
  DecodeDate(n, y, m, d); DecodeTime(n, h, mi, s, ms);
  date.year := y; date.day := DayOfTheYear(n); date.hour := h; date.minute := mi; date.second := s
end;
procedure SetDateTime(date : DateArray);
begin
  simClock := date; simSet := true;
  writeln('   [clock set: year ', date.year, ' day ', date.day, ' ', date.hour, ':', date.minute, ':', date.second, ']')
end;
begin
  simSet := false
end.
