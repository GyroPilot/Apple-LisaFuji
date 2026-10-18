unit AlertMgr; interface
uses UnitStd, UnitHz, Menus;
type TAlertFile = integer; TParamAlert = string[255];
procedure InitMP(hz : THz; var prefix : TParamAlert; failProc : pointer; ver : integer;
                 menus : pointer; var af : TAlertFile; var err : integer);
procedure NoteAlert(af : TAlertFile; n : integer);
implementation
procedure InitMP(hz : THz; var prefix : TParamAlert; failProc : pointer; ver : integer;
                 menus : pointer; var af : TAlertFile; var err : integer);
begin err := 0; writeln('   [am] InitMP prefix "', prefix, '"') end;
procedure NoteAlert(af : TAlertFile; n : integer); begin writeln('   [am] NOTE alert ', n) end;
end.
