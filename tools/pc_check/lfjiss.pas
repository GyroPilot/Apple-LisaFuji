{$V+}
unit LfjIss;

{ REV O  17-Oct-2026  IsKeep modes 2 and 3 hand the crew and weather    }
{                      replies to LfjMore piece by piece.               }

{ REV K  17-Oct-2026  The station on a world map (LfjMap), its path for }
{                      the next 90 minutes (the positions request), and }
{                      your town; the words under the map are shorter.  }
{ REV J  16-Oct-2026  LisaFuji 0.6: the space station page.  New unit.  }
{                      NOT yet compiled on a Lisa.                       }

{ LFJ-ISS.TEXT -- where the International Space Station is, and how far }
{ it is from your town.  LisaFuji's main program fetches the replies     }
{ through the FujiNet (NwGet, with the comma split on, so every JSON     }
{ field arrives as its own line) and hands the lines to this unit, one  }
{ by one.  This unit reads the numbers, does the arithmetic and writes   }
{ the page as lines of text; it never touches the screen or the port.   }
{                                                                        }
{ THE STATION.  https://api.wheretheiss.at/v1/satellites/25544 answers  }
{ one line of JSON: latitude, longitude, altitude (km), velocity (km/h), }
{ visibility (daylight or eclipsed) and timestamp (Unix seconds, UTC).   }
{                                                                        }
{ YOUR TOWN.  https://geocoding-api.open-meteo.com/v1/search?name=...   }
{ answers up to four places with that name.  What was typed after the   }
{ comma picks one: its state or region (admin1), its country, or its    }
{ two-letter country code (UK and USA are understood too).  The town is }
{ kept in HOMETOWN.DATA beside the tool, one line:                       }
{    HT1|latitude|longitude|name <CR>                                    }
{ with the degrees times 10,000 as whole numbers, north and east plus.  }
{                                                                        }
{ THE ARITHMETIC.  Real numbers (IOSFPLIB).  The distance is the great  }
{ circle along the ground (haversine); the height above your horizon is }
{ arctan((cos c - R/(R+h)) / sin c) for the angle c between you and the }
{ point under the station, R the Earth's radius and h the station's     }
{ height; the direction is the starting bearing of that great circle.   }

INTERFACE

uses    UnitStd,
         UnitHz,
        Storage,
      QuickDraw,
        LSysCall,
        LfjMap,
       LfjMore;

const
   isTrMax  = 9;              { points of the path: every 10 minutes for 90 }
   isSub    = 8;              { dots between two of them, along the great circle }
   isDotMax = 80;             { (isTrMax + 1) * isSub }
   isRowMax = 10;             { lines of the page this unit writes }
   isCand   = 4;              { places a town search keeps }
   isBufLen = 128;            { bytes of HOMETOWN.DATA }
   isNoLat  = 9999999;        { no latitude seen yet }

type
   IsByte   = -128..127;
   IsRowStr = string[80];
   IsNmStr  = string[40];

var
   isRow   : array [1..isRowMax] of IsRowStr;   { the page, ready to show }
   isRCnt  : integer;
   isTown  : string[60];      { your town, as the page names it }
   isLat   : longint;         { its latitude, degrees times 10,000, north + }
   isLon   : longint;         { its longitude, east + }
   isHave  : boolean;         { a town is set }
   isExact : boolean;         { the last search matched the words after the comma }
   isEcode : integer;         { OS ecode of the last note-file failure }
   isBuf   : array [0..isBufLen] of IsByte;

   { a town search, being read }
   igN     : integer;
   igSkip  : boolean;
   igQual  : IsNmStr;         { what was typed after the comma, in capitals }
   igNm    : array [1..isCand] of IsNmStr;
   igA1    : array [1..isCand] of IsNmStr;
   igCo    : array [1..isCand] of IsNmStr;
   igCc    : array [1..isCand] of string[4];
   igLat   : array [1..isCand] of longint;
   igLon   : array [1..isCand] of longint;

   { the station, being read }
   ssLat   : longint;
   ssLon   : longint;
   ssAlt   : longint;
   ssVel   : longint;
   ssTs    : longint;
   ssVis   : IsNmStr;
   ssGot   : integer;         { 1 latitude, 2 longitude, 4 altitude, 8 speed, 16 time }

   { the path and the map (REV K) }
   trN     : integer;
   trLat   : array [1..isTrMax] of longint;
   trLon   : array [1..isTrMax] of longint;
   isKeepM : integer;         { IsKeep: 0 = every field the pages use, 1 = positions only, }
                              { 2 = the crew to CrLine, 3 = the weather to WxLine (REV O) }
   isMapOn : boolean;         { the map page is on screen: DrawShow paints it }
   tdN     : integer;         { the path as dots, map pixels from its corner }
   tdX     : array [1..isDotMax] of integer;
   tdY     : array [1..isDotMax] of integer;

procedure IsInit;
function  IsKeep   (s : Str255) : boolean;
procedure IsQuery  (typed : Str255; var nm : Str255);
procedure IsGeoLn  (s : Str255);
function  IsGeoEnd : boolean;
procedure IsStaBeg;
procedure IsStaLn  (s : Str255);
function  IsStaEnd : boolean;
procedure IsNum    (n : longint; sep : boolean; var txt : Str255);
function  IsSave   (var vol : E_Name) : boolean;
function  IsLoad   (var vol : E_Name) : boolean;
procedure IsTrkUrl (var url : Str255);
procedure IsTrkBeg;
procedure IsTrkLn  (s : Str255);
procedure IsTrkEnd;
procedure IsPaint  (left, top : integer);


IMPLEMENTATION

{ This unit's code goes in its own segment, LFJIss: LisaFuji's main     }
{ segment is close to the 32K limit.                                     }
{$S LFJIss}

const
   isPi  = 3.14159265;
   isRad = 6371.0;            { the Earth's radius, km }

procedure IsInit;
begin
   isRCnt  := 0;
   isTown  := '';
   isLat   := 0;
   isLon   := 0;
   isHave  := false;
   isExact := false;
   isEcode := 0;
   igN     := 0;
   igSkip  := false;
   igQual  := '';
   ssGot   := 0;
   ssVis   := '';
   trN     := 0;
   tdN     := 0;
   isKeepM := 0;
   isMapOn := false
end;

procedure IsUp (var s : Str255);
{ s in capitals. }
var i : integer;
begin
   for i := 1 to length(s) do
      if (s[i] >= 'a') and (s[i] <= 'z') then
         s[i] := chr(ord(s[i]) - 32)
end;

procedure IsTrim (var s : Str255);
{ s without spaces at either end. }
var go : boolean;
begin
   go := true;
   while go do
      if length(s) = 0 then
         go := false
      else if s[1] = ' ' then
         delete(s, 1, 1)
      else
         go := false;
   go := true;
   while go do
      if length(s) = 0 then
         go := false
      else if s[length(s)] = ' ' then
         s[0] := chr(length(s) - 1)
      else
         go := false
end;

procedure IsCut (var s : Str255; n : integer);
{ s at most n characters long. }
begin
   if length(s) > n then
      s[0] := chr(n)
end;

procedure IsSplit (var s : Str255; var key, val : Str255);
{ One JSON field, "key":value, as key and value.  The value loses its   }
{ quotes, braces and brackets.  No key: both empty.                     }
var p, q, i : integer;
    t       : Str255;
    one     : string[1];
    c       : char;
begin
   key := '';
   val := '';
   p := pos('"', s);
   if (p = 0) or (p >= length(s)) then
      exit(IsSplit);
   t := copy(s, p + 1, length(s) - p);
   q := pos('"', t);
   if q < 2 then
      exit(IsSplit);
   key := copy(t, 1, q - 1);
   p := pos(':', t);
   if (p = 0) or (p < q) then
      exit(IsSplit);
   one := ' ';
   for i := p + 1 to length(t) do begin
      c := t[i];
      if (c <> '"') and (c <> '{') and (c <> '}') and (c <> '[') and (c <> ']') then
         if (c <> ' ') or (length(val) > 0) then begin
            one[1] := c;
            val := concat(val, one)
         end
   end;
   IsTrim(val)
end;

function IsKeep (s : Str255) : boolean;
{ The fields worth keeping from either reply.  NwGet asks for each line }
{ while the comma split is on, so the postcodes and the rest never take }
{ up one of its lines.                                                   }
var key, val : Str255;
begin
   if isKeepM >= 2 then begin           { REV O: LfjMore reads it as it comes }
      if isKeepM = 2 then
         CrLine(s)
      else
         WxLine(s);
      IsKeep := mrSeen = 1;             { NwGet keeps the first piece only }
      exit(IsKeep)
   end;
   IsSplit(s, key, val);
   if isKeepM = 1 then
      IsKeep := (key = 'latitude') or (key = 'longitude')
   else
   IsKeep := (key = 'name') or (key = 'latitude') or (key = 'longitude')
             or (key = 'admin1') or (key = 'country') or (key = 'country_code')
             or (key = 'altitude') or (key = 'velocity') or (key = 'visibility')
             or (key = 'timestamp')
end;

function IsVal (var v : Str255; frac : boolean) : longint;
{ The number at the start of v.  frac: times 10,000, so four decimals   }
{ survive (39.12711 gives 391271).  Not frac: whole numbers only.       }
var i, d     : integer;
    n        : longint;
    neg, dot : boolean;
    go       : boolean;
begin
   n := 0;
   d := 0;
   i := 1;
   neg := false;
   dot := false;
   go := true;
   if length(v) > 0 then
      if v[1] = '-' then begin
         neg := true;
         i := 2
      end;
   while go and (i <= length(v)) do begin
      if (v[i] >= '0') and (v[i] <= '9') then begin
         if not dot then begin
            if n < 200000000 then
               n := n * 10 + (ord(v[i]) - 48)
         end
         else if d < 4 then begin
            n := n * 10 + (ord(v[i]) - 48);
            d := d + 1
         end
      end
      else if (v[i] = '.') and frac and (not dot) then
         dot := true
      else
         go := false;
      i := i + 1
   end;
   if frac then
      while d < 4 do begin
         n := n * 10;
         d := d + 1
      end;
   if neg then n := -n;
   IsVal := n
end;

procedure IsNum (n : longint; sep : boolean; var txt : Str255);
{ Decimal text of n; sep puts commas between the thousands. }
var one  : string[1];
    d, k : integer;
    neg  : boolean;
begin
   neg := n < 0;
   if neg then n := -n;
   txt := '';
   one := ' ';
   k := 0;
   repeat
      if sep and (k > 0) and (k mod 3 = 0) then
         txt := concat(',', txt);
      d := n mod 10;
      one[1] := chr(48 + d);
      txt := concat(one, txt);
      n := n div 10;
      k := k + 1
   until n = 0;
   if neg then txt := concat('-', txt)
end;

procedure IsDeg (v : longint; posCh, negCh : char; var txt : Str255);
{ Degrees times 10,000 as 39.13 N. }
var h    : longint;
    w, f : integer;
    part : Str255;
    one  : string[1];
begin
   one := ' ';
   if v < 0 then begin
      one[1] := negCh;
      v := -v
   end
   else
      one[1] := posCh;
   h := (v + 50) div 100;             { hundredths }
   w := h div 100;
   f := h mod 100;
   IsNum(w, false, txt);
   IsNum(f, false, part);
   if f < 10 then part := concat('0', part);
   txt := concat(txt, concat('.', concat(part, concat(' ', one))))
end;

function IsAt2 (y, x : real) : real;
{ The angle of the point (x, y), -pi to pi. }
var r : real;
begin
   if x > 0 then
      r := arctan(y / x)
   else if x < 0 then begin
      if y >= 0 then
         r := arctan(y / x) + isPi
      else
         r := arctan(y / x) - isPi
   end
   else if y > 0 then
      r := isPi / 2
   else if y < 0 then
      r := -isPi / 2
   else
      r := 0;
   IsAt2 := r
end;

{------------------------------------------------------------------------}
{ Your town.                                                             }
{------------------------------------------------------------------------}

procedure IsQuery (typed : Str255; var nm : Str255);
{ Start a town search.  nm = what to ask for (the part before the       }
{ first comma); the rest, in capitals, picks among the answers.          }
var p : integer;
    q : Str255;
begin
   p := pos(',', typed);
   if p = 0 then begin
      nm := typed;
      q := ''
   end
   else begin
      if p > 1 then
         nm := copy(typed, 1, p - 1)
      else
         nm := '';
      if p < length(typed) then
         q := copy(typed, p + 1, length(typed) - p)
      else
         q := ''
   end;
   IsTrim(nm);
   IsTrim(q);
   IsUp(q);
   IsCut(q, 40);
   igQual := q;
   igN := 0;
   igSkip := false
end;

procedure IsGeoLn (s : Str255);
{ One kept line of the open-meteo reply.  Every place starts with name. }
var key, val : Str255;
begin
   IsSplit(s, key, val);
   IsCut(val, 40);
   if key = 'name' then begin
      if igN < isCand then begin
         igN := igN + 1;
         igNm[igN] := val;
         igA1[igN] := '';
         igCo[igN] := '';
         igCc[igN] := '';
         igLat[igN] := isNoLat;
         igLon[igN] := 0
      end
      else
         igSkip := true
   end
   else if (igN > 0) and (not igSkip) then begin
      if key = 'latitude' then
         igLat[igN] := IsVal(val, true)
      else if key = 'longitude' then
         igLon[igN] := IsVal(val, true)
      else if key = 'admin1' then
         igA1[igN] := val
      else if key = 'country' then
         igCo[igN] := val
      else if key = 'country_code' then begin
         IsCut(val, 4);
         igCc[igN] := val
      end
   end
end;

function IsMatch (i : integer) : boolean;
{ Place i fits what was typed after the comma. }
var a1, co, cc, q : Str255;
    ok            : boolean;
begin
   q := igQual;
   a1 := igA1[i];
   co := igCo[i];
   cc := igCc[i];
   IsUp(a1);
   IsUp(co);
   IsUp(cc);
   ok := (q = '') or (q = cc);
   if (q = 'UK') and (cc = 'GB') then ok := true;
   if ((q = 'USA') or (q = 'U.S.A.') or (q = 'U.S.')) and (cc = 'US') then ok := true;
   if (length(q) >= 2) and (length(a1) > 0) then
      if pos(q, a1) = 1 then ok := true;
   if (length(q) >= 2) and (length(co) > 0) then
      if pos(q, co) = 1 then ok := true;
   IsMatch := ok
end;

function IsGeoEnd : boolean;
{ Pick the place: the first that fits what was typed after the comma,  }
{ or the first of all.  It becomes your town (isTown, isLat, isLon).    }
var i, pick : integer;
    big     : Str255;
begin
   IsGeoEnd := false;
   pick := 0;
   isExact := false;
   for i := igN downto 1 do
      if igLat[i] <> isNoLat then
         if IsMatch(i) then
            pick := i;
   if pick > 0 then
      isExact := true
   else
      for i := igN downto 1 do
         if igLat[i] <> isNoLat then
            pick := i;
   if pick = 0 then
      exit(IsGeoEnd);
   big := igNm[pick];
   if (igA1[pick] <> '') and (igA1[pick] <> igNm[pick]) then
      big := concat(big, concat(', ', igA1[pick]));
   if igCo[pick] <> '' then
      big := concat(big, concat(', ', igCo[pick]))
   else if igCc[pick] <> '' then
      big := concat(big, concat(' ', igCc[pick]));
   IsCut(big, 60);
   isTown := big;
   isLat := igLat[pick];
   isLon := igLon[pick];
   isHave := true;
   IsGeoEnd := true
end;

{------------------------------------------------------------------------}
{ The station.                                                           }
{------------------------------------------------------------------------}

procedure IsStaBeg;
begin
   ssGot := 0;
   ssVis := '';
   ssLat := 0;
   ssLon := 0;
   ssAlt := 0;
   ssVel := 0;
   ssTs  := 0
end;

procedure IsStaLn (s : Str255);
{ One kept line of the wheretheiss.at reply. }
var key, val : Str255;
begin
   IsSplit(s, key, val);
   if key = 'latitude' then begin
      ssLat := IsVal(val, true);
      ssGot := ssGot + 1
   end
   else if key = 'longitude' then begin
      ssLon := IsVal(val, true);
      ssGot := ssGot + 2
   end
   else if key = 'altitude' then begin
      ssAlt := IsVal(val, true);
      ssGot := ssGot + 4
   end
   else if key = 'velocity' then begin
      ssVel := IsVal(val, true);
      ssGot := ssGot + 8
   end
   else if key = 'timestamp' then begin
      ssTs := IsVal(val, false);
      ssGot := ssGot + 16
   end
   else if key = 'visibility' then begin
      IsCut(val, 40);
      ssVis := val
   end
end;

function IsStaEnd : boolean;
{ The words under the map, as isRow[1..isRCnt] (five lines at most).    }
{ FALSE: the reply had no position.                                      }
var s1, s2   : Str255;
    big      : Str255;
    t        : longint;
    km, mi   : longint;
    hh, mm   : integer;
    ss, k    : integer;
    p1, p2   : real;
    dl, hv   : real;
    c, h, sc : real;
    el, brg  : real;
    x, y     : real;
    dir      : string[48];

   procedure Put (var s : Str255);
   begin
      IsCut(s, 80);
      if isRCnt < isRowMax then begin
         isRCnt := isRCnt + 1;
         isRow[isRCnt] := s
      end
   end;

begin
   IsStaEnd := false;
   isRCnt := 0;
   if (ssGot mod 4) <> 3 then
      exit(IsStaEnd);                  { no latitude and longitude }

   IsDeg(ssLat, 'N', 'S', s1);
   IsDeg(ssLon, 'E', 'W', s2);
   big := concat('Over ', concat(s1, concat(',  ', s2)));
   if ssTs > 0 then begin
      t := ssTs mod 86400;
      hh := t div 3600;
      mm := (t mod 3600) div 60;
      ss := t mod 60;
      IsNum(hh, false, s1);
      if hh < 10 then s1 := concat('0', s1);
      IsNum(mm, false, s2);
      if mm < 10 then s2 := concat('0', s2);
      big := concat(big, concat('   at ', concat(s1, concat(':', s2))));
      IsNum(ss, false, s2);
      if ss < 10 then s2 := concat('0', s2);
      big := concat(big, concat(':', concat(s2, ' UTC')))
   end;
   Put(big);

   big := '';
   if ssAlt > 0 then begin
      IsNum((ssAlt + 5000) div 10000, true, s1);
      IsNum(round(ssAlt / 10000.0 * 0.6214), true, s2);
      big := concat('Height ', concat(s1, concat(' km (', concat(s2, ' miles)'))))
   end;
   if ssVel > 0 then begin
      IsNum((ssVel + 5000) div 10000, true, s1);
      IsNum(round(ssVel / 10000.0 * 0.6214), true, s2);
      big := concat(big, concat('   Speed ', concat(s1, concat(' km/h (', concat(s2, ' mph)')))))
   end;
   if ssVis = 'daylight' then
      big := concat(big, '   sunlit')
   else if ssVis = 'eclipsed' then
      big := concat(big, '   in shadow');
   if big <> '' then
      Put(big);

   if not isHave then begin
      big := 'T = set your town, to see how far away the station is and where to look.';
      Put(big)
   end
   else begin
      p1 := isLat / 10000.0 * isPi / 180.0;
      p2 := ssLat / 10000.0 * isPi / 180.0;
      dl := (ssLon - isLon) / 10000.0 * isPi / 180.0;
      x := sin((p2 - p1) / 2.0);
      y := sin(dl / 2.0);
      hv := x * x + cos(p1) * cos(p2) * y * y;
      if hv > 1.0 then hv := 1.0;
      if hv < 0.0 then hv := 0.0;
      c := 2.0 * IsAt2(sqrt(hv), sqrt(1.0 - hv));     { the angle between, radians }
      km := round(isRad * c);
      mi := round(isRad * c * 0.6214);

      h := ssAlt / 10000.0;
      if h < 100.0 then h := 420.0;                    { no altitude: the usual }
      sc := sin(c);
      if sc > 0.000001 then
         el := arctan((cos(c) - isRad / (isRad + h)) / sc)
      else if cos(c) > 0.0 then
         el := isPi / 2.0
      else
         el := -isPi / 2.0;
      el := el * 180.0 / isPi;

      brg := IsAt2(sin(dl) * cos(p2), cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl));
      brg := brg * 180.0 / isPi;
      if brg < 0.0 then brg := brg + 360.0;
      k := round(brg / 22.5);
      k := k mod 16;
      dir := 'N  NNENE ENEE  ESESE SSES  SSWSW WSWW  WNWNW NNW';
      s1 := copy(dir, k * 3 + 1, 3);
      IsTrim(s1);

      big := concat('From ', concat(isTown, ':'));
      Put(big);
      if km < 25 then
         big := '   the station is right overhead'
      else begin
         IsNum(km, true, s2);
         big := concat('   ', concat(s2, ' km away  ('));
         IsNum(mi, true, s2);
         big := concat(big, concat(s2, concat(' miles), toward the ', s1)))
      end;
      Put(big);
      if el > 0.0 then begin
         IsNum(round(el), false, s2);
         big := concat('   ABOVE your horizon now, ', concat(s2, ' degrees up: look '));
         big := concat(big, s1)
      end
      else begin
         IsNum(round(-el), false, s2);
         big := concat('   below your horizon (', concat(s2, ' degrees down).'));
         big := concat(big, '  One orbit takes 93 minutes.')
      end;
      Put(big)
   end;
   IsStaEnd := true
end;

{------------------------------------------------------------------------}
{ The path and the map (REV K).                                          }
{------------------------------------------------------------------------}

procedure IsTrkUrl (var url : Str255);
{ Where the station will be every 10 minutes for the next 90, from the  }
{ time of the last position.                                             }
var k    : integer;
    part : Str255;
begin
   url := 'N1:HTTPS://api.wheretheiss.at/v1/satellites/25544/positions?timestamps=';
   for k := 1 to isTrMax do begin
      IsNum(ssTs + k * 600, false, part);
      if k > 1 then
         url := concat(url, ',');
      url := concat(url, part)
   end
end;

procedure IsTrkBeg;
begin
   trN := 0
end;

procedure IsTrkLn (s : Str255);
{ One kept line of the positions reply: a latitude starts a point. }
var key, val : Str255;
begin
   IsSplit(s, key, val);
   if key = 'latitude' then begin
      if trN < isTrMax then begin
         trN := trN + 1;
         trLat[trN] := IsVal(val, true);
         trLon[trN] := 0
      end
   end
   else if (key = 'longitude') and (trN > 0) then
      trLon[trN] := IsVal(val, true)
end;

procedure IsTrkEnd;
{ The path as dots: from the station to each point in turn, isSub dots  }
{ a leg, along the great circle between them (spherical interpolation). }
var i, j     : integer;
    la0, lo0 : real;
    la1, lo1 : real;
    x0, y0   : real;
    z0, x1   : real;
    y1, z1   : real;
    w, sw, f : real;
    a, b     : real;
    x, y, z  : real;
    la, lo   : real;
    dr       : real;
    px, py   : longint;
begin
   tdN := 0;
   if ((ssGot mod 4) <> 3) or (trN = 0) then
      exit(IsTrkEnd);
   dr := isPi / 180.0;
   la1 := ssLat / 10000.0 * dr;
   lo1 := ssLon / 10000.0 * dr;
   for i := 1 to trN do begin
      la0 := la1;
      lo0 := lo1;
      la1 := trLat[i] / 10000.0 * dr;
      lo1 := trLon[i] / 10000.0 * dr;
      x0 := cos(la0) * cos(lo0);
      y0 := cos(la0) * sin(lo0);
      z0 := sin(la0);
      x1 := cos(la1) * cos(lo1);
      y1 := cos(la1) * sin(lo1);
      z1 := sin(la1);
      f := x0 * x1 + y0 * y1 + z0 * z1;
      if f > 1.0 then f := 1.0;
      if f < -1.0 then f := -1.0;
      w := IsAt2(sqrt(1.0 - f * f), f);
      sw := sin(w);
      for j := 1 to isSub do begin
         f := j / isSub;
         if sw > 0.0001 then begin
            a := sin((1.0 - f) * w) / sw;
            b := sin(f * w) / sw
         end
         else begin
            a := 1.0 - f;
            b := f
         end;
         x := a * x0 + b * x1;
         y := a * y0 + b * y1;
         z := a * z0 + b * z1;
         la := IsAt2(z, sqrt(x * x + y * y)) / dr;
         lo := IsAt2(y, x) / dr;
         px := round((lo + 180.0) * mapW / 360.0);
         py := round((80.0 - la) * mapH / 140.0);
         if (px >= 0) and (px < mapW) and (py >= 0) and (py < mapH) and (tdN < isDotMax) then begin
            tdN := tdN + 1;
            tdX[tdN] := px;
            tdY[tdN] := py
         end
      end
   end
end;

procedure IsXY (la, lo : longint; left, top : integer; var px, py : integer);
{ A latitude and longitude (times 10,000) as a point on the map. }
var a, b : longint;
begin
   a := ((lo + 1800000) * mapW) div 3600000;
   b := ((800000 - la) * mapH) div 1400000;
   if a < 0 then a := 0;
   if a > mapW - 1 then a := mapW - 1;
   if b < 0 then b := 0;
   if b > mapH - 1 then b := mapH - 1;
   px := left + a;
   py := top + b
end;

procedure IsPaint (left, top : integer);
{ The map, the path (dots, from IsTrkEnd), your town (a box with a dot) }
{ and the station (a ring with a dot), over the dots.                    }
{ The window must be the current port.                                  }
var i, x, y : integer;
    r       : Rect;
begin
   MapDraw(left, top);
   for i := 1 to tdN do begin
      x := left + tdX[i];
      y := top + tdY[i];
      SetRect(r, x - 2, y - 1, x + 2, y + 2);
      EraseRect(r);
      SetRect(r, x - 1, y, x + 1, y + 1);
      PaintRect(r)
   end;
   if isHave then begin
      IsXY(isLat, isLon, left, top, x, y);
      SetRect(r, x - 4, y - 3, x + 5, y + 4);
      EraseRect(r);
      FrameRect(r);
      SetRect(r, x - 1, y - 1, x + 2, y + 2);
      PaintRect(r)
   end;
   if (ssGot mod 4) = 3 then begin
      IsXY(ssLat, ssLon, left, top, x, y);
      SetRect(r, x - 8, y - 6, x + 9, y + 7);
      EraseOval(r);
      FrameOval(r);
      SetRect(r, x - 4, y - 3, x + 5, y + 4);
      PaintOval(r)
   end
end;

{------------------------------------------------------------------------}
{ HOMETOWN.DATA beside the tool.                                         }
{------------------------------------------------------------------------}

function IsSave (var vol : E_Name) : boolean;
{ Write your town.  890 from MAKE_FILE = it is already there: fine. }
var path     : Pathname;
    refnum   : integer;
    wrote    : longint;
    ec       : integer;
    schedErr : integer;
    i, n     : integer;
    s, part  : Str255;
begin
   IsSave := false;
   isEcode := 0;
   IsNum(isLat, false, part);
   s := concat('HT1|', concat(part, '|'));
   IsNum(isLon, false, part);
   s := concat(s, concat(part, concat('|', isTown)));
   n := length(s);
   if n > isBufLen - 1 then n := isBufLen - 1;
   for i := 1 to n do
      isBuf[i - 1] := ord(s[i]);
   isBuf[n] := 13;
   n := n + 1;

   path := concat(vol, 'HOMETOWN.DATA');
   Sched_Class(schedErr, false);
   MAKE_FILE(isEcode, path, 0);
   Sched_Class(schedErr, true);
   if (isEcode > 0) and (isEcode <> 890) then
      exit(IsSave);
   Sched_Class(schedErr, false);
   OPEN(isEcode, path, refnum, [DWrite]);
   Sched_Class(schedErr, true);
   if isEcode > 0 then
      exit(IsSave);
   Sched_Class(schedErr, false);
   WRITE_DATA(isEcode, refnum, ord4(@isBuf), n, wrote, sequential, 0);
   if (isEcode <= 0) and (wrote = n) then begin
      TRUNCATE(ec, refnum);
      IsSave := true
   end;
   CLOSE_OBJECT(ec, refnum);
   Sched_Class(schedErr, true);
   if isEcode < 0 then isEcode := 0
end;

function IsLoad (var vol : E_Name) : boolean;
{ Read your town.  FALSE if the file is missing or not in the HT1      }
{ layout.  A short read comes with a nonzero ecode, so the byte count   }
{ decides (the LISACom lesson).                                          }
var path     : Pathname;
    refnum   : integer;
    got      : longint;
    ec       : integer;
    schedErr : integer;
    i, b     : integer;
    fld      : integer;
    f0, f1   : Str255;
    f2, f3   : Str255;
    one      : string[1];
    la, lo   : longint;
begin
   IsLoad := false;
   path := concat(vol, 'HOMETOWN.DATA');
   Sched_Class(schedErr, false);
   OPEN(ec, path, refnum, [DRead]);
   Sched_Class(schedErr, true);
   if ec > 0 then
      exit(IsLoad);
   got := 0;
   Sched_Class(schedErr, false);
   READ_DATA(ec, refnum, ord4(@isBuf), isBufLen, got, sequential, 0);
   CLOSE_OBJECT(ec, refnum);
   Sched_Class(schedErr, true);
   if got < 8 then
      exit(IsLoad);
   f0 := '';
   f1 := '';
   f2 := '';
   f3 := '';
   fld := 0;
   one := ' ';
   for i := 0 to got - 1 do begin
      b := isBuf[i];
      if b < 0 then b := b + 256;
      if (b = 124) and (fld < 3) then
         fld := fld + 1
      else if (b >= 32) and (b <= 126) then begin
         one[1] := chr(b);
         if fld = 0 then begin
            if length(f0) < 8 then f0 := concat(f0, one)
         end
         else if fld = 1 then begin
            if length(f1) < 12 then f1 := concat(f1, one)
         end
         else if fld = 2 then begin
            if length(f2) < 12 then f2 := concat(f2, one)
         end
         else if length(f3) < 60 then
            f3 := concat(f3, one)
      end
   end;
   if (f0 <> 'HT1') or (fld < 3) or (length(f1) = 0) or (length(f2) = 0) then
      exit(IsLoad);
   la := IsVal(f1, false);
   lo := IsVal(f2, false);
   if (la < -900000) or (la > 900000) or (lo < -1800000) or (lo > 1800000) then
      exit(IsLoad);
   IsTrim(f3);
   if length(f3) = 0 then
      f3 := 'your town';
   isTown := f3;
   isLat := la;
   isLon := lo;
   isHave := true;
   IsLoad := true
end;

end.
