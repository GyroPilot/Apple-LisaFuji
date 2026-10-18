{$V+}
unit TwcUnit;
{ LFJ-TWUNIT.TEXT -- LisaFuji: unit TwcUnit, IDENTICAL to LisaTwinClock }
{ 0.1 REV A's TWC-UNIT.TEXT.  Kept as a copy so LisaFuji builds on its   }
{ own; any change belongs in both files.  Used by the C command (set the }
{ Lisa's clock from the network, twin year, TWINYEAR.DATA note).          }

{ REV A  10-Oct-2026  First version: twin-year arithmetic, the clock    }
{                      read and set, and the note file.  Written to be  }
{                      linked by LisaTwinClock (419313) and, later, by  }
{                      LisaFuji (419312).                                }

{ TWC-UNIT.TEXT -- the twin-year engine.                                 }
{ Nothing here touches menus, windows or alerts.                        }
{                                                                        }
{ WHY A TWIN YEAR.  The Lisa's clock chip stores the year as four bits  }
{ counted from 1980, and the Office System refuses any year outside     }
{ 1981 to 1995.  A twin year is a year inside that range whose          }
{ calendar is identical to the real year's: January 1 falls on the      }
{ same weekday and both are, or both are not, leap years.  2026 has     }
{ the twins 1981 and 1987; the later one is used.  Leap years starting  }
{ on some weekdays (2028, 2032, 2036) have NO twin: 1988 is used then,  }
{ so every date is right and only the weekday names are wrong.          }
{                                                                        }
{ THE CLOCK CALLS.  DateTime and SetDateTime are the hardware library's }
{ own routines (unit HwInt, in the system library on every Office       }
{ System disk).  The Office System's Set_Time is nothing more than a    }
{ year check followed by SetDateTime; the year check is repeated here   }
{ in TwSet, so a year the Lisa cannot hold is never written.  The       }
{ clock is treated as LOCAL time, which is what Office System 3.1 does. }
{                                                                        }
{ THE NOTE FILE.  TWINYEAR.DATA, 20 bytes, beside the tool:             }
{    TW1 yyyy mm dd tttt <CR>                                           }
{ real year, month, day of the last date set, and the twin year used.   }
{ Any tool can read it to show the real year while the clock says 1987. }

INTERFACE

uses      HwInt,
        UnitStd,
         UnitHz,
        Storage,
      QuickDraw,
        LSysCall;

const
   twMinYr  = 1981;           { first year the Lisa's clock accepts }
   twMaxYr  = 1995;           { last year it accepts }
   twLeapYr = 1988;           { stand-in for a leap year with no twin }
   twLoReal = 1981;           { real years this unit will work with }
   twHiReal = 2099;
   twRecLen = 20;             { bytes in the note file }

type
   TwByte = -128..127;

var
   twBuf   : array [0..31] of TwByte;   { the note file record }
   twEcode : integer;         { OS ecode of the last note-file failure }

function  TwLeap   (y : integer) : boolean;
function  TwJan1   (y : integer) : integer;
function  TwDaysIn (y, m : integer) : integer;
function  TwDayOY  (y, m, d : integer) : integer;
procedure TwMonDay (y, doy : integer; var m, d : integer);
function  TwWkDay  (y, m, d : integer) : integer;
function  TwYear   (realY : integer; var exact : boolean) : integer;
function  TwGet    (var y, doy, h, mi, s : integer) : boolean;
function  TwSet    (y, doy, h, mi : integer) : integer;
procedure TwDayNm  (wd : integer; var nm : Str255);
procedure TwMonNm  (m : integer; var nm : Str255);
procedure TwNum    (n : longint; var txt : Str255);
procedure Tw2Dig   (n : integer; var txt : Str255);
function  TwSave   (var vol : E_Name; realY, m, d, twinY : integer) : boolean;
function  TwLoad   (var vol : E_Name; var realY, m, d, twinY : integer) : boolean;


IMPLEMENTATION

{ LisaFuji REV E: this unit's code goes in its own segment.  LisaFuji's }
{ code passed the 32K limit of one segment when this unit was added;    }
{ the Lisa swaps segments in as they are called.                         }
{$S LFJTwUn}

{------------------------------------------------------------------------}
{ Calendar arithmetic.  Everything fits in 16-bit integers.              }
{------------------------------------------------------------------------}

function TwLeap (y : integer) : boolean;
begin
   TwLeap := ((y mod 4) = 0) and (((y mod 100) <> 0) or ((y mod 400) = 0))
end;

function TwJan1 (y : integer) : integer;
{ Weekday of January 1 of year y: 0 = Sunday .. 6 = Saturday.  Gauss's  }
{ formula; the largest intermediate value is under 3,000.               }
var a, b, c : integer;
begin
   a := (y - 1) mod 4;
   b := (y - 1) mod 100;
   c := (y - 1) mod 400;
   TwJan1 := (1 + 5 * a + 4 * b + 6 * c) mod 7
end;

function TwDaysIn (y, m : integer) : integer;
{ Days in month m of year y; 0 for a month number out of range. }
var n : integer;
begin
   n := 0;
   if (m = 1) or (m = 3) or (m = 5) or (m = 7) or (m = 8) or (m = 10)
      or (m = 12) then
      n := 31
   else if (m = 4) or (m = 6) or (m = 9) or (m = 11) then
      n := 30
   else if m = 2 then begin
      if TwLeap(y) then n := 29 else n := 28
   end;
   TwDaysIn := n
end;

function TwDayOY (y, m, d : integer) : integer;
{ Day of the year, 1..366, for month m day d of year y. }
var i, n : integer;
begin
   n := d;
   for i := 1 to m - 1 do
      n := n + TwDaysIn(y, i);
   TwDayOY := n
end;

procedure TwMonDay (y, doy : integer; var m, d : integer);
{ The reverse: month and day for day-of-year doy of year y. }
var rest : integer;
    span : integer;
    done : boolean;
begin
   m := 1;
   rest := doy;
   if rest < 1 then rest := 1;
   done := false;
   while not done do begin
      span := TwDaysIn(y, m);
      if (rest > span) and (m < 12) then begin
         rest := rest - span;
         m := m + 1
      end
      else
         done := true
   end;
   d := rest
end;

function TwWkDay (y, m, d : integer) : integer;
{ Weekday of a date: 0 = Sunday .. 6 = Saturday. }
begin
   TwWkDay := (TwJan1(y) + TwDayOY(y, m, d) - 1) mod 7
end;

function TwYear (realY : integer; var exact : boolean) : integer;
{ The twin year for realY.  exact = TRUE when the calendars match.      }
{ A real year already inside the Lisa's range is its own twin.  When    }
{ there are two twins the LATER one is returned.  With no twin, exact   }
{ is FALSE and the result has the same leap-year status as realY.       }
var z     : integer;
    found : integer;
begin
   exact := true;
   if (realY >= twMinYr) and (realY <= twMaxYr) then begin
      TwYear := realY;
      exit(TwYear)
   end;
   found := 0;
   z := twMaxYr;
   while (z >= twMinYr) and (found = 0) do begin
      if (TwLeap(z) = TwLeap(realY)) and (TwJan1(z) = TwJan1(realY)) then
         found := z;
      z := z - 1
   end;
   if found = 0 then begin
      exact := false;
      if TwLeap(realY) then
         found := twLeapYr
      else
         found := 1987                  { cannot happen: every weekday has }
                                        { a common year in 1981..1995      }
   end;
   TwYear := found
end;

{------------------------------------------------------------------------}
{ The clock.                                                             }
{------------------------------------------------------------------------}

function TwGet (var y, doy, h, mi, s : integer) : boolean;
{ Read the Lisa's clock.  FALSE when it holds no usable date -- a clock }
{ that has lost power reads as 1980, which the Office System also       }
{ treats as "not set".                                                  }
var da : DateArray;
begin
   DateTime(da);
   y   := da.year;
   doy := da.day;
   h   := da.hour;
   mi  := da.minute;
   s   := da.second;
   TwGet := (y >= twMinYr) and (y <= twMaxYr)
            and (doy >= 1) and (doy <= 366)
            and (h >= 0) and (h <= 23)
            and (mi >= 0) and (mi <= 59)
            and (s >= 0) and (s <= 59)
end;

function TwSet (y, doy, h, mi : integer) : integer;
{ Set the clock to year y, day-of-year doy, h:mi:00, then read it back. }
{   0 = set and confirmed                                                }
{   1 = refused here: the year or another value is out of range;        }
{       nothing was written                                              }
{   2 = written, but the read-back did not match; the old time was      }
{       put back                                                         }
{   3 = written, the read-back did not match, and there was no valid    }
{       old time to put back                                             }
var da     : DateArray;
    old    : DateArray;
    hadOld : boolean;
    ok     : boolean;
    oy, od, oh, om, os : integer;
    ny, nd, nh, nm, ns : integer;
begin
   if (y < twMinYr) or (y > twMaxYr) or (doy < 1) or (doy > 366)
      or (h < 0) or (h > 23) or (mi < 0) or (mi > 59) then begin
      TwSet := 1;
      exit(TwSet)
   end;
   if (doy = 366) and (not TwLeap(y)) then begin
      TwSet := 1;
      exit(TwSet)
   end;

   hadOld := TwGet(oy, od, oh, om, os);
   old.year   := oy;
   old.day    := od;
   old.hour   := oh;
   old.minute := om;
   old.second := os;

   da.year   := y;
   da.day    := doy;
   da.hour   := h;
   da.minute := mi;
   da.second := 0;
   SetDateTime(da);

   ok := TwGet(ny, nd, nh, nm, ns);
   if ok then
      ok := (ny = y) and (nd = doy) and (nh = h) and (abs(nm - mi) <= 1);

   if ok then
      TwSet := 0
   else if hadOld then begin
      SetDateTime(old);
      TwSet := 2
   end
   else
      TwSet := 3
end;

{------------------------------------------------------------------------}
{ Names and numbers.                                                     }
{------------------------------------------------------------------------}

procedure TwDayNm (wd : integer; var nm : Str255);
begin
   case wd of
      0 : nm := 'Sunday';
      1 : nm := 'Monday';
      2 : nm := 'Tuesday';
      3 : nm := 'Wednesday';
      4 : nm := 'Thursday';
      5 : nm := 'Friday';
      6 : nm := 'Saturday';
      otherwise nm := '?'
   end
end;

procedure TwMonNm (m : integer; var nm : Str255);
begin
   case m of
      1  : nm := 'January';
      2  : nm := 'February';
      3  : nm := 'March';
      4  : nm := 'April';
      5  : nm := 'May';
      6  : nm := 'June';
      7  : nm := 'July';
      8  : nm := 'August';
      9  : nm := 'September';
      10 : nm := 'October';
      11 : nm := 'November';
      12 : nm := 'December';
      otherwise nm := '?'
   end
end;

procedure TwNum (n : longint; var txt : Str255);
{ LISACom's NumStr, with negatives (ecodes can be warnings below 0). }
var tmp : string[1];
    d   : integer;
    neg : boolean;
begin
   neg := n < 0;
   if neg then n := -n;
   if n = 0 then
      txt := '0'
   else begin
      txt := '';
      while n > 0 do begin
         d := n mod 10;
         tmp := '0';
         tmp[1] := chr(ord('0') + d);
         txt := concat(tmp, txt);
         n := n div 10
      end
   end;
   if neg then txt := concat('-', txt)
end;

procedure Tw2Dig (n : integer; var txt : Str255);
{ Two digits with a leading zero: 5 -> 05.  For minutes. }
var tmp : string[2];
begin
   if n < 0 then n := 0;
   n := n mod 100;
   tmp := '00';
   tmp[1] := chr(ord('0') + (n div 10));
   tmp[2] := chr(ord('0') + (n mod 10));
   txt := tmp
end;

{------------------------------------------------------------------------}
{ The note file.                                                         }
{------------------------------------------------------------------------}

procedure TwPutN (ix, nDig, n : integer);
{ Write n as nDig decimal digits into twBuf starting at index ix. }
var i : integer;
begin
   for i := nDig - 1 downto 0 do begin
      twBuf[ix + i] := ord('0') + (n mod 10);
      n := n div 10
   end
end;

function TwGetN (ix, nDig : integer; var n : integer) : boolean;
{ Read nDig decimal digits from twBuf.  FALSE if any is not a digit. }
var i, v : integer;
    ok   : boolean;
begin
   ok := true;
   n := 0;
   for i := 0 to nDig - 1 do begin
      v := twBuf[ix + i];
      if (v >= ord('0')) and (v <= ord('9')) then
         n := n * 10 + (v - ord('0'))
      else
         ok := false
   end;
   TwGetN := ok
end;

function TwSave (var vol : E_Name; realY, m, d, twinY : integer) : boolean;
{ Write TWINYEAR.DATA on volume vol.  890 from MAKE_FILE = it already   }
{ exists, which is fine.  FALSE and twEcode on failure.                 }
var path     : Pathname;
    refnum   : integer;
    wrote    : longint;
    ec       : integer;
    schedErr : integer;
    i        : integer;
begin
   TwSave := false;
   twEcode := 0;
   for i := 0 to 31 do twBuf[i] := 32;
   twBuf[0] := ord('T');
   twBuf[1] := ord('W');
   twBuf[2] := ord('1');
   TwPutN(4, 4, realY);
   TwPutN(9, 2, m);
   TwPutN(12, 2, d);
   TwPutN(15, 4, twinY);
   twBuf[19] := 13;

   path := concat(vol, 'TWINYEAR.DATA');
   Sched_Class(schedErr, false);
   MAKE_FILE(twEcode, path, 0);
   Sched_Class(schedErr, true);
   if (twEcode > 0) and (twEcode <> 890) then
      exit(TwSave);
   Sched_Class(schedErr, false);
   OPEN(twEcode, path, refnum, [DWrite]);
   Sched_Class(schedErr, true);
   if twEcode > 0 then
      exit(TwSave);
   Sched_Class(schedErr, false);
   WRITE_DATA(twEcode, refnum, ord4(@twBuf), twRecLen, wrote, sequential, 0);
   if (twEcode <= 0) and (wrote = twRecLen) then begin
      TRUNCATE(ec, refnum);
      TwSave := true
   end;
   CLOSE_OBJECT(ec, refnum);
   Sched_Class(schedErr, true);
   if twEcode < 0 then twEcode := 0
end;

function TwLoad (var vol : E_Name; var realY, m, d, twinY : integer) : boolean;
{ Read TWINYEAR.DATA from volume vol.  FALSE if it is missing, short or }
{ not in the TW1 layout.  A short read arrives with a nonzero ecode     }
{ (LISACom lesson), so the byte count decides, never the ecode.         }
var path     : Pathname;
    refnum   : integer;
    got      : longint;
    ec       : integer;
    schedErr : integer;
    ok       : boolean;
begin
   TwLoad := false;
   realY := 0;
   m := 0;
   d := 0;
   twinY := 0;
   path := concat(vol, 'TWINYEAR.DATA');
   Sched_Class(schedErr, false);
   OPEN(ec, path, refnum, [DRead]);
   Sched_Class(schedErr, true);
   if ec > 0 then
      exit(TwLoad);
   got := 0;
   Sched_Class(schedErr, false);
   READ_DATA(ec, refnum, ord4(@twBuf), twRecLen, got, sequential, 0);
   CLOSE_OBJECT(ec, refnum);
   Sched_Class(schedErr, true);
   if got < twRecLen then
      exit(TwLoad);
   ok := (twBuf[0] = ord('T')) and (twBuf[1] = ord('W'))
         and (twBuf[2] = ord('1'));
   if ok then ok := TwGetN(4, 4, realY);
   if ok then ok := TwGetN(9, 2, m);
   if ok then ok := TwGetN(12, 2, d);
   if ok then ok := TwGetN(15, 4, twinY);
   if ok then
      ok := (realY >= twLoReal) and (realY <= twHiReal)
            and (m >= 1) and (m <= 12) and (d >= 1) and (d <= 31)
            and (twinY >= twMinYr) and (twinY <= twMaxYr);
   TwLoad := ok
end;

end.
