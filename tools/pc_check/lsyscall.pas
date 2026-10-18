unit LSysCall; interface
{ Stand-in for the Lisa's SysCall unit.  Serial B is a TCP socket to a
  software FujiNet (or to a proxy / fake in front of it). }
type E_Name = string[32]; Pathname = string[255];
     p_env_blk = pointer; p_ex_data = pointer; t_ex_name = string[16];
     procinfoRec = record progpathname : Pathname end;
     mset = (DRead, DWrite, Append, Private_, Global_RefNum);
     accesses = set of mset;
     iomode = (absolute_, relative, sequential);
     DcType = record dcversion : integer; dccode : integer;
                dcdata : array [0..9] of longint end;
     timestmp_interval = record sec : longint; msec : 0..999 end;
     time_rec = record year : integer; day : 1..366; hour : -23..23;
                  minute : -59..59; second : 0..59; msec : 0..999 end;
var serOpen : boolean; serReads, serNapMs, serMaxHeld : longint; serBaud : longint;
    serQuiet : boolean;
function ord4(p : pointer) : PtrInt;
procedure Sched_Class(var e : integer; b : boolean);
function My_ID : longint;
procedure Info_Process(var err : integer; id : longint; var info : procinfoRec);
procedure Declare_Excep_Hdl(var err : integer; var nm : t_ex_name; p : pointer);
procedure MOUNT(var ec : integer; var vname : E_Name; var password : E_Name; var devname : E_Name);
procedure DEVICE_CONTROL(var ec : integer; var path : Pathname; var cparm : DcType);
procedure MAKE_FILE(var ec : integer; var path : Pathname; lab : integer);
procedure OPEN(var ec : integer; var path : Pathname; var refnum : integer; acc : accesses);
procedure READ_DATA(var ec : integer; refnum : integer; addr : PtrInt; count : longint; var actual : longint; mode : iomode; offset : longint);
procedure WRITE_DATA(var ec : integer; refnum : integer; addr : PtrInt; count : longint; var actual : longint; mode : iomode; offset : longint);
procedure TRUNCATE(var ec : integer; refnum : integer);
procedure CLOSE_OBJECT(var ec : integer; refnum : integer);
procedure DELAY_TIME(var e : integer; iv : timestmp_interval; ct : time_rec);
procedure GET_TIME(var errnum : integer; var gmt_time : time_rec);
{ REV C test switches (environment): LFJ_NAPX=n makes every nap n times as long as asked,
  like the Lisa FPGA (3); LFJ_NOCLOCK=1 makes GET_TIME fail, like a Lisa whose clock was never set. }
implementation
uses SimCfg, {$IFDEF WINDOWS} WinSock2, {$ELSE} BaseUnix, {$ENDIF} Sockets, SysUtils, DateUtils;
{$IFNDEF WINDOWS} const FIONREAD = $541B; {$ENDIF}
var sock : longint;

function ord4(p : pointer) : PtrInt; begin ord4 := PtrInt(p) end;
procedure Sched_Class(var e : integer; b : boolean); begin e := 0 end;
function My_ID : longint; begin My_ID := 1 end;
procedure Info_Process(var err : integer; id : longint; var info : procinfoRec);
begin err := 0; info.progpathname := '-#12-{T419312}Obj' end;
procedure Declare_Excep_Hdl(var err : integer; var nm : t_ex_name; p : pointer); begin err := 0 end;
procedure MOUNT(var ec : integer; var vname : E_Name; var password : E_Name; var devname : E_Name);
begin if cfOpenEc <> 0 then ec := 1051 else ec := 1052 end;

function Held : longint;
var n : longint;
begin
  n := 0; {$IFDEF WINDOWS} ioctlsocket(TSocket(sock), longint(FIONREAD), @n); {$ELSE} fpIOCtl(sock, FIONREAD, @n); {$ENDIF}
  if n > serMaxHeld then serMaxHeld := n;
  Held := n
end;

procedure DEVICE_CONTROL(var ec : integer; var path : Pathname; var cparm : DcType);
var n : longint; junk : array[0..2047] of byte;
begin
  ec := 0;
  if path <> '-RS232B' then begin writeln('!!! DEVICE_CONTROL path ', path); ec := 999 end;
  if cparm.dccode = 5 then serBaud := cparm.dcdata[0];
  if not serOpen then exit;
  if cparm.dccode = 19 then begin
    n := Held;
    if n > 1024 then writeln('!!! ', n, ' bytes held: a real Lisa keeps only 1024');
    cparm.dcdata[9] := n
  end
  else if (cparm.dccode = 9) and (cparm.dcdata[0] = -1) and (cparm.dcdata[1] = -2) then begin
    n := Held;
    while n > 0 do begin
      if n > 2048 then n := 2048;
      fpRecv(sock, @junk, n, 0);
      if not serQuiet then writeln('   [flush] dropped ', n, ' stale bytes');
      n := Held
    end
  end
end;

procedure MAKE_FILE(var ec : integer; var path : Pathname; lab : integer);
begin ec := 0 end;   { stand-in: the note file "exists"; OPEN decides what happens next }
procedure OPEN(var ec : integer; var path : Pathname; var refnum : integer; acc : accesses);
var a : TInetSockAddr;
begin
  if copy(path, 1, 7) <> '-RS232B' then begin ec := 948; exit end;
  if cfOpenEc <> 0 then begin ec := cfOpenEc; exit end;
  sock := fpSocket(AF_INET, SOCK_STREAM, 0);
  a.sin_family := AF_INET; a.sin_port := htons(cfPort); a.sin_addr.s_addr := htonl($7F000001);
  if fpConnect(sock, @a, sizeof(a)) <> 0 then begin writeln('!!! cannot connect to port ', cfPort); ec := 946; exit end;
  serOpen := true; refnum := 50; ec := 0;
  if not serQuiet then writeln('   [port] open at ', serBaud)
end;

procedure READ_DATA(var ec : integer; refnum : integer; addr : PtrInt; count : longint; var actual : longint; mode : iomode; offset : longint);
begin
  if (refnum <> 50) or not serOpen then begin ec := 1000; actual := 0; exit end;
  if count > 128 then writeln('!!! READ_DATA of ', count, ' (more than the proven 128)');
  if count > Held then writeln('!!! READ_DATA asks for more than is held: would block');
  actual := fpRecv(sock, pointer(addr), count, 0);
  if actual <= 0 then ec := 1001 else ec := 0
end;

procedure WRITE_DATA(var ec : integer; refnum : integer; addr : PtrInt; count : longint; var actual : longint; mode : iomode; offset : longint);
var i : longint; p : pbyte; s : string;
begin
  if (refnum <> 50) or not serOpen then begin ec := 1000; actual := 0; exit end;
  actual := fpSend(sock, pointer(addr), count, 0);
  if actual <> count then ec := 1002 else ec := 0;
  if (pbyte(addr)[2] = $52) and (pbyte(addr)[1] = $71) then serReads := serReads + 1;
  if not serQuiet then begin
    p := pbyte(addr); s := '';
    for i := 0 to count - 1 do if i < 34 then s := s + IntToHex(p[i], 2) + ' ';
    if count > 34 then s := s + '...';
    writeln('   [tx ', count, '] ', s)
  end
end;

procedure TRUNCATE(var ec : integer; refnum : integer);
begin ec := 0 end;
procedure CLOSE_OBJECT(var ec : integer; refnum : integer);
begin
  ec := 0;
  if (refnum = 50) and serOpen then begin
    fpShutdown(sock, 2); {$IFDEF WINDOWS} CloseSocket(sock); {$ELSE} fpClose(sock); {$ENDIF} serOpen := false;
    if not serQuiet then writeln('   [port] closed')
  end
end;

procedure DELAY_TIME(var e : integer; iv : timestmp_interval; ct : time_rec);
begin
  e := 0; serNapMs := serNapMs + iv.sec * 1000 + iv.msec;
  Sleep((iv.sec * 1000 + iv.msec) * StrToIntDef(GetEnvironmentVariable('LFJ_NAPX'), 1))
end;

procedure GET_TIME(var errnum : integer; var gmt_time : time_rec);
var t : TDateTime;
begin
  t := Now;
  if GetEnvironmentVariable('LFJ_NOCLOCK') = '1' then begin
    errnum := 609; gmt_time.year := 1980; gmt_time.day := 1; gmt_time.hour := 0;
    gmt_time.minute := 0; gmt_time.second := 0; gmt_time.msec := 0; exit
  end;
  errnum := 0;
  gmt_time.year := YearOf(t); gmt_time.day := DayOfTheYear(t); gmt_time.hour := HourOf(t);
  gmt_time.minute := MinuteOf(t); gmt_time.second := SecondOf(t); gmt_time.msec := 0
end;

begin
  serOpen := false; serReads := 0; serNapMs := 0; serMaxHeld := 0; serBaud := 0; serQuiet := false;
end.
