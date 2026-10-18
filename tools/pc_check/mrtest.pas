{$V+}
program MrTest;
{ PC test of LfjMore: feed a saved reply through the comma split the way  }
{ NwGet does, then print the page.  mrtest crew FILE | mrtest wx FILE |    }
{ mrtest url LAT LON (degrees times 10,000).                               }
uses UnitStd, UnitHz, Storage, QuickDraw, LfjMore;
var f    : file of char;
    c    : char;
    cur  : Str255;
    i    : integer;
    mode : string;
    ok   : boolean;
    url  : Str255;
    la, lo : longint;
    code : integer;

procedure Feed (var s : Str255);
begin
   if mode = 'crew' then CrLine(s) else WxLine(s)
end;

begin
   mode := ParamStr(1);
   MrInit;
   if mode = 'url' then begin
      val(ParamStr(2), la, code);
      val(ParamStr(3), lo, code);
      WxUrl(la, lo, url);
      writeln(length(url), ' ', url);
      halt
   end;
   if mode = 'crew' then CrBeg else WxBeg;
   assign(f, ParamStr(2));
   reset(f);
   cur := '';
   while not eof(f) do begin
      read(f, c);
      if (c = chr(10)) or (c = ',') then begin
         Feed(cur);
         cur := ''
      end
      else if (c <> chr(13)) and (length(cur) < 160) then begin
         if ord(c) >= 128 then c := '?';
         cur := concat(cur, c)
      end
   end;
   if length(cur) > 0 then Feed(cur);
   if mode = 'crew' then ok := CrEnd else ok := WxEnd;
   writeln('ok=', ok, ' seen=', mrSeen, ' rows=', mrRCnt);
   for i := 1 to mrRCnt do
      writeln('|', mrRow[i])
end.
