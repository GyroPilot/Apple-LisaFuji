{$V+}
program IssTest;
uses UnitStd, UnitHz, Storage, QuickDraw, LSysCall, LfjMap, LfjIss;
var f : text; s, cur, nm : Str255; c : char; i : integer; mode : string[8]; vol : E_Name;
    lines : array [1..24] of Str255; n : integer;
procedure Feed;
begin
  if IsKeep(cur) and (n < 24) then begin n := n + 1; lines[n] := cur end; cur := ''
end;
begin
  mode := paramstr(1);
  assign(f, paramstr(2)); reset(f);
  n := 0; cur := '';
  while not eof(f) do begin
    read(f, c);
    if (c = ',') or (c = chr(10)) then Feed
    else if c <> chr(13) then begin if length(cur) < 160 then cur := cur + c end
  end;
  if length(cur) > 0 then Feed;
  close(f);
  IsInit;
  if mode = 'geo' then begin
    IsQuery(paramstr(3), nm);
    writeln('query [', nm, '] qual [', igQual, '] lines ', n);
    for i := 1 to n do IsGeoLn(lines[i]);
    writeln('found ', IsGeoEnd, ' exact ', isExact, ' town [', isTown, '] ', isLat, ' ', isLon);
    vol := '';
    writeln('save ', IsSave(vol)); IsInit; writeln('load ', IsLoad(vol), ' [', isTown, '] ', isLat, ' ', isLon)
  end else begin
    if paramcount >= 4 then begin isHave := true; isTown := 'Test'; val(paramstr(3), isLat); val(paramstr(4), isLon) end;
    IsStaBeg; for i := 1 to n do IsStaLn(lines[i]);
    writeln('end ', IsStaEnd);
    for i := 1 to isRCnt do writeln(isRow[i]);
    IsTrkUrl(s); writeln(length(s), ' ', s);
    if paramcount >= 5 then begin
      assign(f, paramstr(5)); reset(f); n := 0; cur := ''; isKeepM := 1;
      while not eof(f) do begin read(f, c); if (c = ',') or (c = chr(10)) then Feed else if c <> chr(13) then begin if length(cur) < 160 then cur := cur + c end end;
      if length(cur) > 0 then Feed; close(f);
      IsTrkBeg; for i := 1 to n do IsTrkLn(lines[i]); IsTrkEnd; writeln('dots ', tdN); writeln('track points ', trN);
      for i := 1 to trN do writeln(trLat[i], ' ', trLon[i]);
      qdCalls := 0; IsPaint(44, 40); writeln('drawing calls ', qdCalls)
    end
  end
end.
