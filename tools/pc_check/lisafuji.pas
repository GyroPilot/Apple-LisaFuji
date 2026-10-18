{$V+}
program LisaFuji;

{ LFJ-MAIN.TEXT -- LisaFuji  ***  1.1 REV P  ***                         }
{ REV P  17-Oct-2026  Weather icons (LfjMore WxPaint, from DrawShow   }
{                      like the map); the sky column moves to x 130.  }
{ REV O  17-Oct-2026  1.1: P = who is aboard the space stations (ISS  }
{                      and Tiangong), O = the weather in your town,   }
{                      both read by the new unit LfjMore (LFJ/MORE).  }
{                      MAIN's code is split into three segments: the }
{                      blank one, LFJNews (news and Wikipedia) and    }
{                      LFJPage (the space, crew and weather pages and }
{                      the event code); it was near the 32K limit.   }
{ REV E  14-Oct-2026  C sets the Lisa's clock from the FujiNet's        }
{                      network time: the twin year, read back, and the }
{                      real year noted in TWINYEAR.DATA, exactly as     }
{                      LisaTwinClock does, with its unit (LFJ/TWUNIT).  }
{                      Y confirms on the pane.  NOT yet compiled.       }
{ REV D  14-Oct-2026  Wikipedia: S, or the Wiki menu.  A typed search, }
{                      nine titles, article pages of 76 x 14 from the  }
{                      FujiNet wiki service, read by NwGet like the    }
{                      news.  NwGet folds accented letters and dashes  }
{                      to plain characters (they were dots).  Wiki is  }
{                      menu 3.  NOT yet compiled on a Lisa.            }
{ REV C  13-Oct-2026  Waits end by the real clock (FnBus FnTStart /    }
{                      FnTOver), so timeouts take the time they say on }
{                      the FPGA too (REV B: 15 s for a 5 s timeout).   }
{                      The two 15-second idle waits (web fetch, news)  }
{                      use them as well.  NOT yet compiled on a Lisa.  }
{ REV B  12-Oct-2026  The news reader: N, or the News menu.  Category   }
{                      list, nine headlines a page, article pages of    }
{                      76 x 14 from the FujiNet news service over       }
{                      HTTPS.  FnBus is unchanged from REV A.  NOT yet  }
{                      compiled on a Lisa.                               }
{ REV A  10-Oct-2026  First build: the FujiNet TEST TOOL.  NOT yet      }
{                      compiled on a Lisa.                               }
{                                                                        }
{ THIS LINE IS THE VERSION CHECK.  If the About box disagrees with the  }
{ number above, a stale file was sent.  (The authoritative constant is  }
{ lfjVersion in LFJ-GLOBALS.TEXT; keep the two in step.)                 }
{                                                                        }
{ Tool 419312 (pencilled in; not yet reserved on the LisaList2 list).   }
{ Skeleton: TWC-MAIN REV A, which is LFU-MAIN REV I (LisaFileMover 1.1) }
{ -- the callbacks, the status pane, the typed prompt, the event loop   }
{ and Initialize.  UserAborted is LISACom 1.7's.                         }
{                                                                        }
{ WHAT IT DOES                                                           }
{   Tests 1 to 3 (A)  -- 1 FujiNet ready (512 letter A's come back),    }
{                        2 adapter and WiFi (network name, address,     }
{                        firmware), 3 network clock.  Keys 1, 2 and 3   }
{                        run one test alone.                             }
{   Fetch a Web File (F) -- asks for an address (RETURN takes the last  }
{                        one), opens it through the FujiNet, reads it   }
{                        in pieces of at most 256 bytes, shows the      }
{                        byte count and the first lines.  Any key or    }
{                        click stops it.                                 }
{   Show Last Bytes (B) -- the last frame sent and the reply, in hex,   }
{                        to compare with GOLDEN_TRACES.md.               }
{   Speed menu        -- 9600 (start here) or 19200.                    }
{                                                                        }
{ The port is opened for each command and closed after it, so LISACom   }
{ can have Serial B back without quitting this tool.                     }
{ All serial and FujiBus work is in FnBus (LFJ-FNBUS.TEXT).              }

uses    UnitStd,
         UnitHz,
        Storage,
      QuickDraw,
        FontMgr,
        LSysCall,
      Events,
      Folders,
       Menus,
       AlertMgr,
         WMLstd,
         WMLCrs,
      FilerComm,
      LfjGlobals,
        FnBus,
       TwcUnit,
          LfjMap,
         LfjMore,
          LfjIss;

var
   termErr : integer;

{------------------------------------------------------------------------}
{ The three required callbacks.                                          }
{------------------------------------------------------------------------}

function OutOfHeapSpace (hz : THz; bytesNeeded : integer) : integer;
begin
   OutOfHeapSpace := 0
end;

procedure AlertFailed;
var err : integer;
begin
   if initing then begin
      TellFiler(err, initFailed, noMemory, nil);
      Halt
   end
end;

procedure LastWishes (environPtr : p_env_blk; excepDataPtr : p_ex_data);
begin
   ImDying;
   Halt
end;

{------------------------------------------------------------------------}
{ Menus.                                                                 }
{------------------------------------------------------------------------}

procedure PutUpMenus;
var m : integer;
begin
   ClearMenuBar;
   for m := mFile to lastBarMenu do
      InsertMenu(myMenus[m], 0);
   DrawMenuBar
end;

{------------------------------------------------------------------------}
{ The status pane.                                                       }
{------------------------------------------------------------------------}

procedure Clip (var big : Str255; var out : StatStr);
{ Copy at most 80 characters.  HARDWARE LESSON (INS REV B): COPY(big,   }
{ 1, 80) with LENGTH(big) < 80 returned an EMPTY string on the Lisa.    }
var n : integer;
begin
   n := length(big);
   if n > 80 then n := 80;
   if n = 0 then
      out := ''
   else
      out := copy(big, 1, n)
end;

procedure PaneStr (var s : StatStr; y : integer);
{ One pane line at baseline y.  A TAB moves to the next column (REV O,  }
{ the weather table: the Lisa's font is proportional, so spaces cannot  }
{ line columns up).                                                      }
var i, k : integer;
    tab  : string[1];
    one  : string[1];
    part : StatStr;
begin
   MoveTo(10, y);
   tab := ' ';
   tab[1] := chr(9);
   if pos(tab, s) = 0 then begin
      DrawString(s);
      exit(PaneStr)
   end;
   part := '';
   one := ' ';
   k := 0;
   for i := 1 to length(s) do
      if s[i] = chr(9) then begin
         DrawString(part);
         part := '';
         k := k + 1;
         case k of
            1 : MoveTo(130, y);          { REV P: room for the icon at 100 }
            2 : MoveTo(250, y);
            3 : MoveTo(370, y);
            4 : MoveTo(480, y);
            otherwise
         end
      end
      else begin
         one[1] := s[i];
         part := concat(part, one)
      end;
   DrawString(part)
end;

procedure DrawShow;
{ Repaint the whole status pane. }
var fi : FontInfo;
    i  : integer;
begin
   if myWindow = nil then
      exit(DrawShow);
   SetPort(myWindow);
   EraseRect(myWindow^.portRect);
   GetFontInfo(fi);
   for i := 1 to statCnt do
      PaneStr(statLine[i], 6 + (i - 1) * lineHt + fi.ascent);
   if isMapOn then
      IsPaint(44, 40);                  { REV K: the map under pane lines 3 to 11 }
   if wxOn then
      WxPaint(6, lineHt)                { REV P: the weather icons }
end;

procedure DrawOne (i : integer);
{ Repaint pane line i only: no flash while typing (2/10 bench, 16-Oct). }
var fi : FontInfo;
    r  : Rect;
begin
   if myWindow = nil then
      exit(DrawOne);
   SetPort(myWindow);
   r := myWindow^.portRect;
   r.top := 6 + (i - 1) * lineHt;
   r.bottom := r.top + lineHt;
   EraseRect(r);
   GetFontInfo(fi);
   PaneStr(statLine[i], 6 + (i - 1) * lineHt + fi.ascent)
end;

procedure AddLine (var s : StatStr);
{ Append a line; scroll the list up when full.  Only a scroll repaints the whole pane; }
{ otherwise just the new line is drawn (no flash as a page fills, 2/10 bench 16-Oct).   }
var i      : integer;
    scroll : boolean;
begin
   scroll := statCnt >= maxLines;
   if not scroll then
      statCnt := statCnt + 1
   else
      for i := 1 to maxLines - 1 do
         statLine[i] := statLine[i + 1];
   statLine[statCnt] := s;
   if not quiet then begin
      if scroll then DrawShow else DrawOne(statCnt)
   end
end;

procedure SetLast (var s : StatStr);
{ Replace the last line and repaint that line only. }
begin
   if statCnt = 0 then
      AddLine(s)
   else begin
      statLine[statCnt] := s;
      if not quiet then DrawOne(statCnt)
   end
end;

procedure AddBig (var big : Str255);
{ Clip a long string and append it. }
var out : StatStr;
begin
   Clip(big, out);
   AddLine(out)
end;

procedure SetBig (var big : Str255);
{ Clip a long string and put it in place of the last line. }
var out : StatStr;
begin
   Clip(big, out);
   SetLast(out)
end;

procedure LogMode;
{ Clear the pane for a fresh run of lines.  Since AddLine draws only the }
{ new line, the pane is erased here, once per screen; otherwise the last }
{ screen's lower lines stayed under a short new one (LisaEm, 16-Oct-2026). }
begin
   statCnt := 0;
   isMapOn := false;                    { REV K: a new screen has no map }
   wxOn := false;                       { REV P: nor weather icons }
   if (not quiet) and (myWindow <> nil) then begin
      SetPort(myWindow);
      EraseRect(myWindow^.portRect)
   end
end;

procedure Two (n : integer; var txt : Str255);
{ n as two digits: 5 gives 05. }
begin
   FnNum(n, txt);
   if length(txt) < 2 then
      txt := concat('0', txt)
end;

{------------------------------------------------------------------------}
{ A key or a click stops a fetch.  LISACom 1.7's UserAborted: a command }
{ runs INSIDE the event loop, so the queue is looked at from here.      }
{ Only a key or a click counts; anything else (updates, Filer traffic)  }
{ goes to the normal handler, because an unanswered Filer event freezes }
{ the desktop.                                                           }
{------------------------------------------------------------------------}

procedure ProcessTheEvent; FORWARD;

function UserAborted : boolean;
begin
   UserAborted := false;
   if not EventAvail then
      exit(UserAborted);
   GetEvent(theEvent);
   if (theEvent.what = keyDown) or (theEvent.what = buttonDown) then begin
      cancelled := true;
      UserAborted := true
   end
   else begin
      ProcessTheEvent;
      if toldToDie or (myWindow = nil) then begin
         cancelled := true;
         UserAborted := true
      end
   end
end;

{------------------------------------------------------------------------}
{ Shared pieces of every command.                                        }
{------------------------------------------------------------------------}

procedure Head (var ttl : StatStr);
{ Clear the pane; version and speed, the title, a blank line. }
var part : Str255;
    big  : Str255;
    row  : StatStr;
begin
   LogMode;
   FnNum(curBaud, part);
   big := concat(lfjVersion, '     Serial B, ');
   big := concat(big, concat(part, ' baud'));
   AddBig(big);
   AddLine(ttl);
   row := '';
   AddLine(row)
end;

procedure Foot;
var row : StatStr;
begin
   row := '';
   AddLine(row);
   row := 'A = tests 1 to 3   F = fetch a web file   B = last bytes   H = help   N = news';
   AddLine(row)
end;

procedure WhyTxt (rc : integer; var txt : Str255);
{ A result code from FnBus in plain words. }
begin
   if rc = fnNakd then
      txt := 'the FujiNet refused the command (NAK)'
   else if rc = fnNoRep then
      txt := 'no reply'
   else if rc = fnBadFr then
      txt := 'the reply was damaged (length or checksum wrong)'
   else if rc = fnPortEr then
      txt := 'the serial port gave an error'
   else if rc = fnBadArg then
      txt := 'not sent: the request was not allowed'
   else if rc = fnShort then
      txt := 'the reply was not the data expected'
   else if rc = fnStall then
      txt := 'the reply stopped part-way'
   else
      txt := 'unknown result'
end;

procedure SayFail (var lead : StatStr; rc : integer);
{ Replace the last line with: lead FAIL: reason.  Then, when nothing    }
{ usable came back, the things to check.                                 }
var reason : Str255;
    big : Str255;
    row : StatStr;
begin
   WhyTxt(rc, reason);
   big := concat(lead, concat('FAIL: ', reason));
   SetBig(big);
   if (rc = fnNoRep) or (rc = fnStall) or (rc = fnBadFr) then begin
      row := '   Check: FujiNet powered?  Cable on Serial B, no null modem?';
      AddLine(row);
      row := '   Same speed at both ends (baud= on the SD card, then restart)?';
      AddLine(row)
   end
   else if rc = fnPortEr then begin
      FnNum(fnEcode, reason);
      big := concat('   (OS ecode ', concat(reason, ')'));
      AddBig(big)
   end
end;

function LineUp : boolean;
{ Open Serial B at curBaud.  FALSE: the reason and the fix are shown.   }
var part : Str255;
    big  : Str255;
    row  : StatStr;
begin
   LineUp := true;
   if FnPortUp(curBaud) then
      exit(LineUp);
   LineUp := false;
   FnNum(fnEcode, part);
   big := concat('Serial B would not open (ecode ', part);
   FnNum(fnMntEc, part);
   big := concat(big, concat(', mount ', part));
   big := concat(big, ').');
   AddBig(big);
   row := 'Quit LISACom if it is running: only one tool can hold Serial B.';
   AddLine(row);
   row := 'Otherwise open Preferences, choose Connect Devices, and set the';
   AddLine(row);
   row := 'Serial B Connector to Serial Cable.  Then try again.';
   AddLine(row)
end;

{------------------------------------------------------------------------}
{ Tests 1 to 3.  Each expects the port to be open.                       }
{------------------------------------------------------------------------}

function Test1 : boolean;
{ FujiNet ready: 512 letter A's.  Proves port, framing and checksum.    }
var rc   : integer;
    row  : StatStr;
    lead : StatStr;
begin
   row := '1. FujiNet ready:  asking ...';
   AddLine(row);
   rc := FnReady;
   if rc = fnOK then begin
      row := '1. FujiNet ready:  PASS   (512 letter A''s came back)';
      SetLast(row)
   end
   else begin
      lead := '1. FujiNet ready:  ';
      SayFail(lead, rc)
   end;
   Test1 := rc = fnOK
end;

function Test2 : boolean;
{ Adapter and WiFi.  Proves un-escaping: an address that starts 192     }
{ arrives as an escaped C0.                                              }
var rc, st : integer;
    i, b   : integer;
    allZip : boolean;
    row    : StatStr;
    lead   : StatStr;
    ssid   : Str255;
    host   : Str255;
    ver    : Str255;
    ip     : Str255;
    part   : Str255;
    big    : Str255;
begin
   row := '2. Adapter and WiFi:  asking ...';
   AddLine(row);
   rc := FnAdCfg;
   if rc <> fnOK then begin
      lead := '2. Adapter and WiFi:  ';
      SayFail(lead, rc);
      Test2 := false;
      exit(Test2)
   end;

   { take everything out of the reply before the next call replaces it }
   FnPlStr(0, 32, ssid);
   FnPlStr(33, 63, host);
   FnPlStr(125, 15, ver);
   ip := '';
   allZip := true;
   for i := 0 to 3 do begin
      b := FnPlB(97 + i);
      if b <> 0 then allZip := false;
      FnNum(b, part);
      if i > 0 then ip := concat(ip, '.');
      ip := concat(ip, part)
   end;
   if length(ssid) = 0 then ssid := '(none)';
   if length(host) = 0 then host := '(none)';

   row := '2. Adapter and WiFi:  PASS';
   SetLast(row);
   big := concat('     Network: ', ssid);
   AddBig(big);
   big := concat('     Address: ', ip);
   big := concat(big, concat('     Name: ', host));
   AddBig(big);

   rc := FnWifi(st);
   big := concat('     Firmware: ', ver);
   if rc <> fnOK then
      big := concat(big, '     WiFi: no answer')
   else if st = 3 then
      big := concat(big, '     WiFi: connected')
   else if st = 6 then
      big := concat(big, '     WiFi: NOT connected')
   else begin
      FnNum(st, part);
      big := concat(big, concat('     WiFi: status ', part))
   end;
   AddBig(big);
   if allZip then begin
      row := '     No address yet: check the WiFi name and password on the SD card.';
      AddLine(row)
   end;
   Test2 := true
end;

function Test3 : boolean;
{ Network clock.  Proves a command that carries a parameter.            }
var rc               : integer;
    d, mo, y, h, mi, s : integer;
    row              : StatStr;
    lead             : StatStr;
    part             : Str255;
    big              : Str255;
begin
   row := '3. Network clock:  asking ...';
   AddLine(row);
   rc := FnClock(d, mo, y, h, mi, s);
   if rc <> fnOK then begin
      lead := '3. Network clock:  ';
      SayFail(lead, rc);
      Test3 := false;
      exit(Test3)
   end;
   FnNum(y, part);
   big := concat('3. Network clock:  PASS   ', part);
   Two(mo, part);
   big := concat(big, concat('-', part));
   Two(d, part);
   big := concat(big, concat('-', part));
   Two(h, part);
   big := concat(big, concat('   ', part));
   Two(mi, part);
   big := concat(big, concat(':', part));
   Two(s, part);
   big := concat(big, concat(':', part));
   SetBig(big);
   if y < 2024 then begin
      row := '     The FujiNet has not fetched the time yet: is WiFi connected?';
      AddLine(row)
   end;
   Test3 := true
end;

procedure DoTests (which : integer);
{ which = 0: tests 1, 2 and 3 (2 and 3 only if 1 passes).  1, 2 or 3:   }
{ that test alone.                                                       }
var ok  : boolean;
    row : StatStr;
begin
   promptOn := false;
   if which = 0 then
      row := 'Tests 1 to 3'
   else
      row := 'One test';
   Head(row);
   if LineUp then begin
      if which = 0 then begin
         if Test1 then begin
            ok := Test2;
            ok := Test3
         end
      end
      else if which = 1 then
         ok := Test1
      else if which = 2 then
         ok := Test2
      else
         ok := Test3;
      FnPortDn
   end;
   Foot
end;

{------------------------------------------------------------------------}
{ Fetch a web file.                                                      }
{------------------------------------------------------------------------}

procedure DoFetch;
{ OPEN curUrl for reading, then STATUS / READ until the FujiNet says    }
{ end of data, then CLOSE.  LF ends a line; CR is dropped; anything     }
{ that will not print shows as a dot.  The first capMax lines are kept. }
{ The check number is the sum of every byte, modulo 65536: the same    }
{ file fetched on another computer must give the same number.          }
var rc      : integer;
    k, i, b : integer;
    total   : longint;
    reads   : longint;
    lines   : longint;
    idle    : longint;
    idleT0  : longint;
    idleClk : boolean;
    sum     : longint;
    done    : boolean;
    fail    : boolean;
    midLine  : boolean;
    cur     : StatStr;
    tmp     : string[1];
    url     : Str255;
    part    : Str255;
    big     : Str255;
    row     : StatStr;
    lead    : StatStr;
begin
   promptOn := false;
   cancelled := false;
   capCnt := 0;
   row := 'Fetch a web file';
   Head(row);
   big := concat('Address: ', curUrl);
   AddBig(big);
   if not LineUp then begin
      Foot;
      exit(DoFetch)
   end;

   row := 'Open:  asking ...  (this can take up to 25 seconds)';
   AddLine(row);
   url := curUrl;
   rc := FnNClos;                      { REV G: a channel left open by a failed fetch }
   rc := FnNOpen(url, 4, 0);
   if rc <> fnOK then begin
      lead := 'Open:  ';
      SayFail(lead, rc);
      rc := FnNClos;
      FnPortDn;
      Foot;
      exit(DoFetch)
   end;

   if fnStat <> 1 then begin
      FnNum(fnStat, part);
      if fnStat = 170 then
         big := 'Open:  NOT FOUND (status 170).  The server has no such file.'
      else if fnStat = 207 then
         big := 'Open:  NO CONNECTION (status 207).  The server was not reached.'
      else
         big := concat('Open:  refused, status ', part);
      SetBig(big);
      rc := FnNClos;
      FnPortDn;
      Foot;
      exit(DoFetch)
   end;

   FnNum(fnWait, part);
   big := concat('Open:  good (status 1), ', part);
   big := concat(big, ' bytes waiting');
   SetBig(big);
   row := 'Reading ...';
   AddLine(row);

   total := 0;
   reads := 0;
   lines := 0;
   idle  := 0;
   FnTStart(idleT0, idleClk);
   sum   := 0;
   done  := false;
   fail  := false;
   midLine := false;
   cur := '';
   tmp := ' ';
   rc  := fnOK;

   while not (done or fail or cancelled) do begin
      if fnWait = 0 then begin
         rc := FnNStat;
         if rc <> fnOK then
            fail := true
         else if fnWait = 0 then begin
            if fnStat = 136 then
               done := true                       { end of data }
            else if (fnConn = 0) and (fnStat <> 1) then
               done := true                       { the far end is gone }
            else begin
               FnNap(100);
               idle := idle + 100;
               if FnTOver(idleT0, idleClk, idle, idleMax) then
                  fail := true                    { rc stays fnOK }
            end
         end
      end
      else begin
         k := fnRdMax;
         if fnWait < k then
            k := fnWait;
         rc := FnNRead(k);
         if rc <> fnOK then
            fail := true
         else begin
            idle := 0;
            FnTStart(idleT0, idleClk);
            reads := reads + 1;
            total := total + fnPlLen;
            for i := 0 to fnPlLen - 1 do begin
               b := FnPlB(i);
               sum := (sum + b) mod 65536;
               if b = 10 then begin
                  lines := lines + 1;
                  if capCnt < capMax then begin
                     capCnt := capCnt + 1;
                     capLine[capCnt] := cur
                  end;
                  cur := '';
                  midLine := false
               end
               else if b <> 13 then begin
                  midLine := true;
                  if b = 9 then b := 32;
                  if (b < 32) or (b > 126) then b := 46;
                  if (capCnt < capMax) and (length(cur) < 76) then begin
                     tmp[1] := chr(b);
                     cur := concat(cur, tmp)
                  end
               end
            end;
            FnNum(total, part);
            big := concat('Reading ...  ', concat(part, ' bytes'));
            SetBig(big)
         end
      end;
      if not (done or fail) then
         if UserAborted then
            cancelled := true
   end;

   if midLine then begin                           { a last line with no LF }
      lines := lines + 1;
      if capCnt < capMax then begin
         capCnt := capCnt + 1;
         capLine[capCnt] := cur
      end
   end;

   k := FnNClos;
   FnPortDn;

   FnNum(total, part);
   if cancelled then begin
      big := concat('Stopped by a key or click.  ', part);
      big := concat(big, ' bytes had arrived.  Closed.');
      SetBig(big)
   end
   else if fail and (rc = fnOK) then begin
      big := concat('Gave up: nothing arrived for 15 seconds.  ', part);
      big := concat(big, ' bytes had arrived.');
      SetBig(big)
   end
   else if fail then begin
      lead := 'Read:  ';
      SayFail(lead, rc);
      big := concat('   ', concat(part, ' bytes had arrived.'));
      AddBig(big)
   end
   else begin
      big := concat('Received ', concat(part, ' bytes in '));
      FnNum(reads, part);
      big := concat(big, concat(part, ' reads, '));
      FnNum(lines, part);
      big := concat(big, concat(part, ' lines, check '));
      FnNum(sum, part);
      big := concat(big, concat(part, '.  Closed.'));
      SetBig(big)
   end;

   if capCnt > 0 then begin
      row := 'First lines:';
      AddLine(row);
      for i := 1 to capCnt do begin
         big := concat('   ', capLine[i]);
         AddBig(big)
      end
   end;
   Foot
end;

{------------------------------------------------------------------------}
{ Show Last Bytes.                                                       }
{------------------------------------------------------------------------}

procedure HexRow (fromTx : boolean; cnt : integer);
{ cnt bytes (20 at most) as hex on one line: from the last frame sent,  }
{ or from the last reply packet.                                         }
var i, b : integer;
    part : Str255;
    big  : Str255;
begin
   big := '   ';
   for i := 0 to cnt - 1 do begin
      if fromTx then begin
         b := fnTx[i];
         if b < 0 then b := b + 256
      end
      else
         b := FnGetB(i);
      FnHex(b, part);
      big := concat(big, concat(part, ' '))
   end;
   AddBig(big)
end;

procedure ShowBytes;
var n    : integer;
    part : Str255;
    big  : Str255;
    row  : StatStr;
begin
   promptOn := false;
   if fnTxLen = 0 then begin
      row := 'Nothing has been sent yet.';
      AddLine(row);
      exit(ShowBytes)
   end;
   FnNum(fnTxLen, part);
   big := concat('Last frame sent: ', concat(part, ' bytes on the wire.  It starts'));
   AddBig(big);
   n := fnTxLen;
   if n > 20 then n := 20;
   HexRow(true, n);

   FnNum(fnLen, part);
   big := concat('Last reply: ', concat(part, ' bytes without the C0 marks and escapes'));
   if fnRCmd = fnAck then
      big := concat(big, ' (ACK)')
   else if fnRCmd = fnNak then
      big := concat(big, ' (NAK)');
   AddBig(big);
   n := fnLen;
   if n > 20 then n := 20;
   if n > 0 then
      HexRow(false, n)
   else begin
      row := '   (nothing)';
      AddLine(row)
   end
end;

{------------------------------------------------------------------------}
{ Pages that fill the pane once.                                         }
{------------------------------------------------------------------------}

procedure HomePage;
var row : StatStr;
begin
   promptOn := false;
   quiet := true;
   row := 'News, Wikipedia, space, weather and tests: an RS-232 FujiNet on Serial B.';
   Head(row);
   row := 'N = the news: headlines and articles from the FujiNet news service';
   AddLine(row);
   row := 'S = search Wikipedia and read an article page by page';
   AddLine(row);
   row := 'I = where the space station is now, and how far from your town (T sets it)';
   AddLine(row);
   row := 'P = who is aboard the space stations now';
   AddLine(row);
   row := 'O = the weather in your town, now and for three days';
   AddLine(row);
   row := 'C = set the Lisa''s clock from the network (the twin year)';
   AddLine(row);
   row := 'A = run tests 1 to 3: FujiNet ready, adapter and WiFi, network clock';
   AddLine(row);
   row := '1, 2 or 3 = run that test alone';
   AddLine(row);
   row := 'F = fetch a small web file through the FujiNet';
   AddLine(row);
   row := 'B = show the last bytes sent and received';
   AddLine(row);
   row := 'H = help      W = wiring and set-up';
   AddLine(row);
   row := '';
   AddLine(row);
   row := 'Nothing is sent to the FujiNet until you press one of these keys.';
   AddLine(row);
   quiet := false;
   DrawShow
end;

{------------------------------------------------------------------------}
{ The network clock (REV E).  C asks the FujiNet for the time, shows it  }
{ and the twin-year date the Lisa will get, and waits for Y.  The set,   }
{ the read-back and the TWINYEAR.DATA note are LisaTwinClock's (TwcUnit).}
{------------------------------------------------------------------------}

procedure CkShow (var lead : StatStr; y, doy, h, mi : integer);
{ lead, then "Wednesday, October 14, 1987   16:05". }
var m, d, wd : integer;
    nm, part : Str255;
    big      : Str255;
begin
   TwMonDay(y, doy, m, d);
   wd := TwWkDay(y, m, d);
   TwDayNm(wd, nm);
   big := concat(lead, concat(nm, ', '));
   TwMonNm(m, nm);
   big := concat(big, concat(nm, ' '));
   TwNum(d, part);
   big := concat(big, concat(part, ', '));
   TwNum(y, part);
   big := concat(big, concat(part, '   '));
   Tw2Dig(h, part);
   big := concat(big, concat(part, ':'));
   Tw2Dig(mi, part);
   big := concat(big, part);
   AddBig(big)
end;

procedure CkAsk;
{ C: fetch the network time and offer to set the clock. }
var rc    : integer;
    d, mo, y, h, mi, s : integer;
    exact : boolean;
    row   : StatStr;
    lead  : StatStr;
    part  : Str255;
    big   : Str255;
begin
   promptOn := false;
   nwMode := 0;
   wkMode := 0;
   ckMode := 0;
   row := 'Set the Lisa''s clock from the network';
   Head(row);
   if not LineUp then
      exit(CkAsk);
   row := 'Asking the FujiNet for the time ...';
   AddLine(row);
   rc := FnClock(d, mo, y, h, mi, s);
   FnPortDn;
   if rc <> fnOK then begin
      lead := 'Clock:  ';
      SayFail(lead, rc);
      exit(CkAsk)
   end;
   if (y < 2024) or (y > twHiReal) or (mo < 1) or (mo > 12) or (d < 1)
      or (d > TwDaysIn(y, mo)) or (h < 0) or (h > 23) or (mi < 0) or (mi > 59)
   then begin
      row := 'The FujiNet has not fetched the time yet: is WiFi connected?';
      SetLast(row);
      exit(CkAsk)
   end;
   ckY := y;
   ckMo := mo;
   ckD := d;
   ckH := h;
   ckMi := mi;
   ckTwin := TwYear(y, exact);
   if (mo = 2) and (d = 29) and (not TwLeap(ckTwin)) then
      ckDoy := TwDayOY(ckTwin, 3, 1)       { defensive: cannot happen }
   else
      ckDoy := TwDayOY(ckTwin, mo, d);
   lead := 'Network time:        ';
   CkShow(lead, y, TwDayOY(y, mo, d), h, mi);
   lead := 'Lisa will be set to: ';
   CkShow(lead, ckTwin, ckDoy, h, mi);
   if not exact then begin
      FnNum(y, part);
      big := concat(part, ' has no twin year: dates right, weekday names wrong.');
      AddBig(big)
   end;
   row := '';
   AddLine(row);
   row := 'Y sets the clock to the twin year, as LisaTwinClock does.  Any other key: no.';
   AddLine(row);
   ckMode := 1
end;

procedure CkSet;
{ Y after CkAsk: set the clock, read it back, note the real year. }
var rc   : integer;
    part : Str255;
    big  : Str255;
    row  : StatStr;
begin
   ckMode := 0;
   rc := TwSet(ckTwin, ckDoy, ckH, ckMi);
   if rc = 0 then begin
      row := 'The clock is set.';
      SetLast(row);
      if not TwSave(myVol, ckY, ckMo, ckD, ckTwin) then begin
         TwNum(twEcode, part);
         big := concat('(The note file was not saved: ecode ', concat(part, '.)'));
         AddBig(big)
      end
      else begin
         row := 'The real year is noted in TWINYEAR.DATA, as LisaTwinClock does.';
         AddLine(row)
      end
   end
   else begin
      TwNum(rc, part);
      big := concat('The clock was NOT set (result ', concat(part, ').'));
      SetBig(big);
      if rc = 2 then
         row := 'The read-back did not match; the old time was put back.'
      else if rc = 3 then
         row := 'The read-back did not match; there was no old time to restore.'
      else
         row := 'A value was out of range; nothing was written.';
      AddLine(row)
   end
end;

procedure CkAnswer (ch : char);
{ The key after CkAsk. }
var row : StatStr;
begin
   if (ch = 'Y') or (ch = 'y') then
      CkSet
   else begin
      ckMode := 0;
      row := 'The clock was not changed.';
      SetLast(row)
   end
end;

procedure HelpUse;
var row : StatStr;
begin
   promptOn := false;
   quiet := true;
   row := 'How to use';
   Head(row);
   row := 'Press A.  Three lines should each end in PASS:';
   AddLine(row);
   row := '  1  the FujiNet answers (cable, speed and framing are right)';
   AddLine(row);
   row := '  2  its network name, address and firmware version';
   AddLine(row);
   row := '  3  the date and time it got from the network';
   AddLine(row);
   row := '';
   AddLine(row);
   row := 'Press F to fetch a web file.  Type an address such as';
   AddLine(row);
   row := '  HTTP://example.com/     and press RETURN.  RETURN alone uses';
   AddLine(row);
   row := 'the address shown.  Any key or click stops a fetch.';
   AddLine(row);
   row := '';
   AddLine(row);
   row := 'A FAIL line says what went wrong and what to check.';
   AddLine(row);
   row := 'B shows the bytes of the last command, to compare with the traces.';
   AddLine(row);
   row := 'Speed menu: start at 9600.  It must match the FujiNet''s SD card.';
   AddLine(row);
   row := 'N or the News menu: pick a category, then a headline by its number.';
   AddLine(row);
   row := 'S or the Wiki menu: type a search, then pick an article by its number.';
   AddLine(row);
   row := 'C sets the Lisa''s clock from the FujiNet''s network time (twin year).';
   AddLine(row);
   quiet := false;
   DrawShow
end;

procedure HelpWire;
var row : StatStr;
begin
   promptOn := false;
   quiet := true;
   row := 'Wiring and set-up';
   Head(row);
   row := 'FujiNet: power it from USB-C.  Connect Lisa Serial B to its 9-pin';
   AddLine(row);
   row := 'socket, wired as for a modem: NO null-modem adapter.';
   AddLine(row);
   row := '';
   AddLine(row);
   row := 'SD card: in the file fnconfig.ini, under [Serial], put baud=9600';
   AddLine(row);
   row := 'and restart the FujiNet.  The Speed menu here must say the same.';
   AddLine(row);
   row := '';
   AddLine(row);
   row := 'Lisa: Preferences, Connect Devices, Serial B Connector set to';
   AddLine(row);
   row := 'Serial Cable.';
   AddLine(row);
   row := '';
   AddLine(row);
   row := 'Quit LISACom first: only one tool can hold Serial B at a time.';
   AddLine(row);
   quiet := false;
   DrawShow
end;

procedure SetSpeed (baud : longint);
var row : StatStr;
begin
   promptOn := false;
   curBaud := baud;
   quiet := true;
   row := 'Speed changed.';
   Head(row);
   row := 'The FujiNet must be set to the same speed: on its SD card, in';
   AddLine(row);
   row := 'fnconfig.ini under [Serial], set baud= to this number, then';
   AddLine(row);
   row := 'restart the FujiNet.  Press A to test.';
   AddLine(row);
   quiet := false;
   DrawShow
end;

{------------------------------------------------------------------------}
{ The news reader.  The FujiNet news service (fujinet.online/8bitnews)  }
{ hands out plain ASCII pages:                                           }
{   headlines  line 1 "page/pages", then  id|yyyy-mm-dd hh:mm:ss|title  }
{   an article line 1 title, 2 date and time, 3 source, 4 "page/pages", }
{              then the text, already wrapped to 76 columns             }
{   a problem  one line starting ERROR:                                  }
{ Each page is fetched when asked for; nothing is saved to disk.        }
{ Keys while in the news are handled by NwKey, not PlainKey.            }
{------------------------------------------------------------------------}

{ REV O: the news and Wikipedia code in its own segment. }
{$S LFJNews}

procedure NwSub (var s : NewsStr; from, cnt : integer; var out : Str255);
{ out = at most cnt characters of s, starting at from.  Never asks COPY }
{ for more than is there (the INS REV B lesson, see Clip).              }
var room : integer;
begin
   out := '';
   room := length(s) - from + 1;
   if cnt > room then cnt := room;
   if (from >= 1) and (cnt > 0) then
      out := copy(s, from, cnt)
end;

function NwNumIn (var s : NewsStr; var p : integer) : longint;
{ The digits of s from position p, as a number; p ends on the first     }
{ character that is not a digit.  No digits gives 0.                    }
var n  : longint;
    go : boolean;
begin
   n := 0;
   go := true;
   while go do begin
      if p > length(s) then
         go := false
      else if (s[p] < '0') or (s[p] > '9') then
         go := false
      else if n > 99999999 then
         go := false
      else begin
         n := n * 10 + (ord(s[p]) - 48);
         p := p + 1
      end
   end;
   NwNumIn := n
end;

procedure NwSlug (cat : integer; var s : Str255);
{ The category as the service spells it.  Same order as the News menu. }
begin
   case cat of
      1 : s := 'top';
      2 : s := 'world';
      3 : s := 'science';
      4 : s := 'business';
      5 : s := 'technology';
      6 : s := 'health';
      7 : s := 'entertainment';
      8 : s := 'politics';
      otherwise
         s := 'sports'
   end
end;

procedure NwName (cat : integer; var s : Str255);
{ The category as the screen shows it. }
begin
   case cat of
      1 : s := 'Top Stories';
      2 : s := 'World';
      3 : s := 'Science';
      4 : s := 'Business';
      5 : s := 'Technology';
      6 : s := 'Health';
      7 : s := 'Entertainment';
      8 : s := 'Politics';
      otherwise
         s := 'Sports'
   end
end;

function NwGet (var url : Str255) : boolean;
{ Fetch url through the FujiNet into nwLine (nwCnt lines, each cut at   }
{ nwWide characters, LF ends a line, CR is dropped, anything that will  }
{ not print is a dot).  TRUE: something usable arrived.  FALSE: the     }
{ reason is on the pane.  The read loop is DoFetch's.                   }
var rc, k, i, b : integer;
    total     : longint;
    idle      : longint;
    idleT0    : longint;
    idleClk   : boolean;
    done      : boolean;
    fail      : boolean;
    cur       : NewsStr;
    tmp       : string[1];
    part      : Str255;
    big       : Str255;
    row       : StatStr;
    lead      : StatStr;
    u1, u2    : integer;      { a UTF-8 character being collected }
    uLeft     : integer;      { bytes of it still to come }
    lat       : string[64];   { C3 80..BF as plain letters }

   procedure NwPut (b : integer);
   begin
      if length(cur) < nwWide then begin
         tmp[1] := chr(b);
         cur := concat(cur, tmp)
      end
   end;

   procedure NwFlush;
   { A lead byte that was not followed by its continuation bytes was a  }
   { single Latin-1 letter, not UTF-8: show it without its accent.      }
   begin
      if uLeft > 0 then begin
         uLeft := 0;
         if (u1 >= 192) and (u2 = 0) then
            NwPut(ord(lat[u1 - 191]))
         else
            NwPut(63)
      end
   end;

   procedure NwFold (u1, u2, u3 : integer);
   { One UTF-8 character of two or three bytes as a plain character:   }
   { accented Latin letters lose the accent, dashes and quotes become   }
   { the plain ones, anything else is a question mark.                   }
   var k : integer;
   begin
      if u1 = 195 then begin                         { C3 xx: Latin letters }
         k := u2 - 127;
         if (k >= 1) and (k <= 64) then
            NwPut(ord(lat[k]))
         else
            NwPut(63)
      end
      else if (u1 = 194) and (u2 = 160) then        { no-break space }
         NwPut(32)
      else if (u1 = 226) and (u2 = 128) then begin  { E2 80 xx: spaces, dashes, quotes }
         if ((u3 >= 128) and (u3 <= 138)) or (u3 = 175) then
            NwPut(32)                                { the typographic spaces }
         else if (u3 = 146) or (u3 = 147) or (u3 = 148) then
            NwPut(45)
         else if (u3 = 152) or (u3 = 153) then
            NwPut(39)
         else if (u3 = 156) or (u3 = 157) then
            NwPut(34)
         else if u3 = 166 then begin
            NwPut(46);
            NwPut(46);
            NwPut(46)
         end
         else
            NwPut(63)
      end
      else
         NwPut(63)
   end;

begin
   NwGet := false;
   cancelled := false;
   svcEmpty := false;
   nwCnt := 0;
   lat := 'AAAAAAACEEEEIIIIDNOOOOOxOUUUUYTsaaaaaaaceeeeiiiidnooooo/ouuuuyty';
   uLeft := 0;
   u1 := 0;
   u2 := 0;
   big := concat('Asking ', concat(svcName, ' ...  (any key stops it)'));
   Clip(big, row);
   AddLine(row);
   if not LineUp then
      exit(NwGet);

   if svcName = 'Wikipedia' then
      lead := 'Wiki:  '
   else if nwSplit then
      lead := 'Space:  '
   else
      lead := 'News:  ';
   rc := FnNClos;                      { REV G: a channel left open by a failed fetch }
   rc := FnNOpen(url, 4, 0);
   if rc <> fnOK then begin
      SayFail(lead, rc);
      rc := FnNClos;
      FnPortDn;
      exit(NwGet)
   end;
   if fnStat = 136 then begin                     { opened, but nothing to read }
      svcEmpty := true;
      big := concat('Nothing came back from ', concat(svcName, '.'));
      SetBig(big);
      k := FnNClos;
      FnPortDn;
      exit(NwGet)
   end;
   if fnStat <> 1 then begin
      FnNum(fnStat, part);
      if fnStat = 170 then
         big := concat('Status 170: ', concat(svcName, ' was not found.'))
      else if fnStat = 207 then
         big := concat('Status 207: no connection to ', concat(svcName, '.'))
      else
         big := concat('Refused by ', concat(svcName, concat(', status ', part)));
      SetBig(big);
      k := FnNClos;
      FnPortDn;
      exit(NwGet)
   end;

   total := 0;
   idle  := 0;
   FnTStart(idleT0, idleClk);
   done  := false;
   fail  := false;
   cur   := '';
   tmp   := ' ';
   rc    := fnOK;

   while not (done or fail or cancelled) do begin
      if fnWait = 0 then begin
         rc := FnNStat;
         if rc <> fnOK then
            fail := true
         else if fnWait = 0 then begin
            if fnStat = 136 then
               done := true                       { end of data }
            else if (fnConn = 0) and (fnStat <> 1) then
               done := true                       { the far end is gone }
            else begin
               FnNap(100);
               idle := idle + 100;
               if FnTOver(idleT0, idleClk, idle, idleMax) then
                  fail := true                    { rc stays fnOK }
            end
         end
      end
      else begin
         k := fnRdMax;
         if fnWait < k then
            k := fnWait;
         rc := FnNRead(k);
         if rc <> fnOK then
            fail := true
         else begin
            idle := 0;
            FnTStart(idleT0, idleClk);
            total := total + fnPlLen;
            for i := 0 to fnPlLen - 1 do begin
               b := FnPlB(i);
               if (b = 10) or (nwSplit and (b = 44)) then begin
                  NwFlush;
                  if nwCnt < nwMax then
                     if (not nwSplit) or IsKeep(cur) then begin
                        nwCnt := nwCnt + 1;
                        nwLine[nwCnt] := cur
                     end;
                  cur := ''
               end
               else if b <> 13 then begin
                  if b = 9 then b := 32;
                  if b < 128 then begin
                     if b < 32 then b := 46;
                     NwFlush;
                     NwPut(b)
                  end
                  else if b >= 192 then begin       { first byte of a UTF-8 character }
                     NwFlush;
                     u1 := b;
                     u2 := 0;
                     if b >= 240 then
                        uLeft := 3
                     else if b >= 224 then
                        uLeft := 2
                     else
                        uLeft := 1
                  end
                  else if uLeft > 0 then begin      { one of its following bytes }
                     uLeft := uLeft - 1;
                     if u2 = 0 then u2 := b;
                     if uLeft = 0 then NwFold(u1, u2, b)
                  end
                  else
                     NwPut(63)                      { a stray byte }
               end
            end;
            FnNum(total, part);
            big := concat('Asking ', concat(svcName, concat(' ...  ', concat(part, ' bytes'))));
            SetBig(big)
         end
      end;
      if not (done or fail) then
         if UserAborted then
            cancelled := true
   end;

   if length(cur) > 0 then                         { a last line with no LF }
      if nwCnt < nwMax then
         if (not nwSplit) or IsKeep(cur) then begin
            nwCnt := nwCnt + 1;
            nwLine[nwCnt] := cur
         end;

   k := FnNClos;
   FnPortDn;

   if cancelled then begin
      row := 'Stopped by a key or click.';
      SetLast(row)
   end
   else if fail and (rc = fnOK) then begin
      row := 'Gave up: nothing arrived for 15 seconds.';
      SetLast(row)
   end
   else if fail then
      SayFail(lead, rc)
   else if nwCnt = 0 then begin
      svcEmpty := true;
      big := concat('Nothing came back from ', concat(svcName, '.'));
      SetBig(big)
   end
   else if pos('ERROR', nwLine[1]) = 1 then begin
      big := concat(svcName, concat(' said:  ', nwLine[1]));
      SetBig(big)
   end
   else
      NwGet := true
end;

procedure NwFail;
{ After a failed fetch: what can be done next. }
var row : StatStr;
begin
   nwMode := 4;
   row := '';
   AddLine(row);
   row := 'R = try again   C = categories   Q = leave the news';
   AddLine(row)
end;

procedure NwCats;
{ The category list. }
var i    : integer;
    row  : StatStr;
    nm   : Str255;
    part : Str255;
    big  : Str255;
begin
   promptOn := false;
   quiet := true;
   row := 'News from the FujiNet news service';
   Head(row);
   for i := 1 to 9 do begin
      NwName(i, nm);
      FnNum(i, part);
      big := concat('   ', concat(part, concat('   ', nm)));
      AddBig(big)
   end;
   row := '';
   AddLine(row);
   row := '1 to 9 = pick a category   Q = leave the news';
   AddLine(row);
   row := 'Each page is fetched through the FujiNet when you ask for it.';
   AddLine(row);
   quiet := false;
   DrawShow;
   nwMode := 1
end;

procedure NwHDraw;
{ Show the headline page held in nwHTop, nwHRow and nwHCnt. }
var i   : integer;
    row : StatStr;
begin
   promptOn := false;
   quiet := true;
   Head(nwHTop);
   for i := 1 to nwHCnt do
      AddLine(nwHRow[i]);
   if nwHCnt = 0 then begin
      row := 'No headlines on this page.';
      AddLine(row)
   end;
   row := '';
   AddLine(row);
   row := '1 to 9 = read   N = next page   P = previous   C = categories   Q = leave';
   AddLine(row);
   quiet := false;
   DrawShow;
   nwMode := 2
end;

procedure NwList (cat, page : integer);
{ Fetch headline page page of category cat, keep it, show it. }
var i, p, q : integer;
    v       : longint;
    id      : longint;
    go      : boolean;
    s       : NewsStr;
    url     : Str255;
    part    : Str255;
    nm      : Str255;
    dd      : Str255;
    tt      : Str255;
    big     : Str255;
    row     : StatStr;
begin
   promptOn := false;
   nwRqK := 2;
   nwRqC := cat;
   nwRqP := page;
   NwName(cat, nm);
   row := concat('News: ', nm);
   Head(row);
   NwSlug(cat, part);
   url := concat(nwBase, concat('&l=9&c=', part));
   FnNum(page, part);
   url := concat(url, concat('&p=', part));
   svcName := 'the news service';
   if not NwGet(url) then begin
      NwFail;
      exit(NwList)
   end;

   { line 1: page/pages }
   s := nwLine[1];
   p := 1;
   v := NwNumIn(s, p);
   q := 0;
   if p <= length(s) then
      if s[p] = '/' then begin
         p := p + 1;
         q := 1
      end;
   if (q = 0) or (v < 1) or (v > 9999) then begin
      row := 'The news service sent something unexpected:';
      SetLast(row);
      NwSub(s, 1, 80, big);
      AddBig(big);
      NwFail;
      exit(NwList)
   end;
   nwPage := v;
   v := NwNumIn(s, p);
   if v > 9999 then v := 9999;
   if v < nwPage then v := nwPage;
   nwPgs := v;
   nwCat := cat;

   { the headlines: id|date|title }
   nwHCnt := 0;
   for i := 2 to nwCnt do
      if nwHCnt < nwPer then begin
         s := nwLine[i];
         p := 1;
         id := NwNumIn(s, p);
         q := 0;
         if (id > 0) and (p <= length(s)) then
            if s[p] = '|' then
               q := p;
         if q > 0 then begin
            NwSub(s, q + 6, 5, dd);                { mm-dd of yyyy-mm-dd }
            p := q + 1;                            { find the second bar }
            go := true;
            while go do begin
               if p > length(s) then
                  go := false
               else if s[p] = '|' then
                  go := false
               else
                  p := p + 1
            end;
            NwSub(s, p + 1, nwWide, tt);
            if length(tt) > 66 then
               tt := concat(copy(tt, 1, 63), '...');
            nwHCnt := nwHCnt + 1;
            nwId[nwHCnt] := id;
            FnNum(nwHCnt, part);
            big := concat(part, concat('  ', concat(dd, concat('  ', tt))));
            Clip(big, nwHRow[nwHCnt])
         end
      end;

   big := concat('News: ', concat(nm, '      Page '));
   FnNum(nwPage, part);
   big := concat(big, concat(part, ' of '));
   FnNum(nwPgs, part);
   big := concat(big, part);
   Clip(big, nwHTop);
   NwHDraw
end;

procedure NwArt (id : longint; page : integer);
{ Fetch page page of article id and show it: title, date, source and    }
{ page count, then 14 lines of text, then the keys.                     }
var i, p, q : integer;
    last    : integer;
    v       : longint;
    s       : NewsStr;
    url     : Str255;
    part    : Str255;
    a       : Str255;
    big     : Str255;
    row     : StatStr;
begin
   promptOn := false;
   nwRqK := 3;
   nwRqA := id;
   nwRqP := page;
   row := 'News: fetching the article';
   Head(row);
   FnNum(id, part);
   url := concat(nwBase, concat('&a=', part));
   FnNum(page, part);
   url := concat(url, concat('&p=', part));
   svcName := 'the news service';
   if not NwGet(url) then begin
      NwFail;
      exit(NwArt)
   end;

   { line 4: page/pages }
   q := 0;
   v := 0;
   if nwCnt >= 4 then begin
      s := nwLine[4];
      p := 1;
      v := NwNumIn(s, p);
      if p <= length(s) then
         if s[p] = '/' then begin
            p := p + 1;
            q := 1
         end
   end;
   if (q = 0) or (v < 1) or (v > 9999) then begin
      row := 'The news service sent something unexpected:';
      SetLast(row);
      s := nwLine[1];
      NwSub(s, 1, 80, big);
      AddBig(big);
      NwFail;
      exit(NwArt)
   end;
   nwAPage := v;
   v := NwNumIn(s, p);
   if v > 9999 then v := 9999;
   if v < nwAPage then v := nwAPage;
   nwAPgs := v;
   nwArtId := id;

   quiet := true;
   LogMode;
   s := nwLine[1];                                 { the title }
   if length(s) > 80 then begin
      NwSub(s, 1, 77, a);
      big := concat(a, '...')
   end
   else
      NwSub(s, 1, 80, big);
   AddBig(big);
   s := nwLine[2];                                 { date, to the minute }
   NwSub(s, 1, 16, big);
   s := nwLine[3];                                 { source }
   NwSub(s, 1, 30, a);
   big := concat(big, concat('   ', a));
   FnNum(nwAPage, part);
   big := concat(big, concat('   Page ', part));
   FnNum(nwAPgs, part);
   big := concat(big, concat(' of ', part));
   AddBig(big);
   row := '';
   AddLine(row);
   last := nwCnt;
   if last > 4 + nwBody then
      last := 4 + nwBody;
   for i := 5 to last do begin
      s := nwLine[i];
      NwSub(s, 1, 80, big);
      AddBig(big)
   end;
   for i := last + 1 to 4 + nwBody do
      AddLine(row);                                { row is still empty }
   row := 'SPACE = next page   P = previous   H = headlines   C = categories   Q = leave';
   AddLine(row);
   quiet := false;
   DrawShow;
   nwMode := 3
end;

procedure NwKey (ch : char);
{ A key while in the news.  Q or Clear leaves, C goes to the category   }
{ list, from anywhere in the news.  The rest depend on the page shown.  }
var d : integer;
begin
   if (ch = 'Q') or (ch = 'q') or (ch = chr(27)) then begin
      nwMode := 0;
      HomePage;
      exit(NwKey)
   end;
   if (ch = 'C') or (ch = 'c') then begin
      NwCats;
      exit(NwKey)
   end;
   d := ord(ch) - 48;
   case nwMode of
      1 :
         if (d >= 1) and (d <= 9) then
            NwList(d, 1);
      2 :
         if (d >= 1) and (d <= nwHCnt) then
            NwArt(nwId[d], 1)
         else if (ch = 'N') or (ch = 'n') then begin
            if nwPage < nwPgs then
               NwList(nwCat, nwPage + 1)
         end
         else if (ch = 'P') or (ch = 'p') then begin
            if nwPage > 1 then
               NwList(nwCat, nwPage - 1)
         end
         else if (ch = 'R') or (ch = 'r') then
            NwList(nwCat, nwPage);
      3 :
         if (ch = ' ') or (ch = 'N') or (ch = 'n') then begin
            if nwAPage < nwAPgs then
               NwArt(nwArtId, nwAPage + 1)
         end
         else if (ch = 'P') or (ch = 'p') then begin
            if nwAPage > 1 then
               NwArt(nwArtId, nwAPage - 1)
         end
         else if (ch = 'H') or (ch = 'h') then
            NwHDraw
         else if (ch = 'R') or (ch = 'r') then
            NwArt(nwArtId, nwAPage);
      4 :
         if (ch = 'R') or (ch = 'r') then begin
            if nwRqK = 2 then
               NwList(nwRqC, nwRqP)
            else if nwRqK = 3 then
               NwArt(nwRqA, nwRqP)
         end;
      otherwise

   end
end;

{------------------------------------------------------------------------}
{ The typed address prompt, on the last pane line.                       }
{------------------------------------------------------------------------}

procedure DrawPrompt;
{ Label, what has been typed, a cursor mark.  A long address shows its  }
{ last 60 characters.                                                    }
var big : Str255;
    n   : integer;
begin
   n := length(promptTxt);
   if length(promptLbl) + n < 78 then
      big := concat(promptLbl, concat(promptTxt, '_'))
   else begin
      big := concat('Address: ...', copy(promptTxt, n - 59, 60));
      big := concat(big, '_')
   end;
   SetBig(big)
end;

{------------------------------------------------------------------------}
{ Wikipedia, through the FujiNet wiki service (REV D).  A search gives  }
{ up to nine titles; an article comes in pages of 14 lines, like a news }
{ article.  The fetch loop is NwGet's.  Keys while in Wikipedia are     }
{ handled by WkKey; the search words are typed at the address prompt.   }
{------------------------------------------------------------------------}

procedure WkEnc (var q : UrlStr; var out : Str255);
{ q as an address needs it: letters, digits and - _ . ~ as they are,    }
{ anything else as %XX.                                                  }
var i, b : integer;
    tmp  : string[3];
    hx   : string[16];
    c    : char;
begin
   hx := '0123456789ABCDEF';
   out := '';
   for i := 1 to length(q) do begin
      c := q[i];
      if ((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z'))
         or ((c >= '0') and (c <= '9')) or (c = '-') or (c = '_')
         or (c = '.') or (c = '~') then begin
         tmp := ' ';
         tmp[1] := c
      end
      else begin
         b := ord(c);
         tmp := '%00';
         tmp[2] := hx[(b div 16) + 1];
         tmp[3] := hx[(b mod 16) + 1]
      end;
      if length(out) < 240 then
         out := concat(out, tmp)
   end
end;

procedure WkFail;
{ After a failed fetch: what can be done next. }
var row : StatStr;
begin
   wkMode := 4;
   row := '';
   AddLine(row);
   row := 'R = try again   S = search again   Q = leave Wikipedia';
   AddLine(row)
end;

procedure WkAsk;
{ The search prompt.  RETURN at it runs WkFind (see TakeUrl). }
var row : StatStr;
begin
   nwMode := 0;
   row := 'Search Wikipedia';
   Head(row);
   row := 'Type a word or two, then RETURN.  Clear cancels.';
   AddLine(row);
   row := 'Up to nine matching articles come back, one key each.';
   AddLine(row);
   row := '';
   AddLine(row);
   promptLbl := 'Search Wikipedia: ';
   promptTxt := '';
   promptOn := true;
   AddLine(row);
   DrawPrompt;
   wkMode := 1
end;

procedure WkRDraw;
{ Show the title list held in wkRTop, wkRRow and wkRCnt. }
var i   : integer;
    row : StatStr;
begin
   promptOn := false;
   quiet := true;
   Head(wkRTop);
   for i := 1 to wkRCnt do
      AddLine(wkRRow[i]);
   row := '';
   AddLine(row);
   row := '1 to 9 = read an article   S = search again   Q = leave Wikipedia';
   AddLine(row);
   quiet := false;
   DrawShow;
   wkMode := 2
end;

procedure WkFind;
{ Search for wkQ: fetch the title list ("Title, number" lines), keep   }
{ it, show it.  The number is after the LAST comma: titles have commas. }
var i, p, q : integer;
    id      : longint;
    s       : NewsStr;
    url     : Str255;
    part    : Str255;
    big     : Str255;
    row     : StatStr;
begin
   promptOn := false;
   wkRqK := 2;
   big := concat('Wikipedia: looking for ', wkQ);
   Clip(big, row);
   Head(row);
   WkEnc(wkQ, part);
   url := concat(wkBase, concat('&l=9&s=', part));
   svcName := 'Wikipedia';
   if not NwGet(url) then begin
      if svcEmpty then begin
         big := concat('No articles found for ', wkQ);
         SetBig(big)
      end;
      WkFail;
      exit(WkFind)
   end;
   wkRCnt := 0;
   for i := 1 to nwCnt do
      if wkRCnt < nwPer then begin
         s := nwLine[i];
         q := 0;
         for p := 1 to length(s) do
            if s[p] = ',' then q := p;
         id := 0;
         if q > 0 then begin
            p := q + 1;
            if p <= length(s) then
               if s[p] = ' ' then p := p + 1;
            id := NwNumIn(s, p)
         end;
         if id > 0 then begin
            wkRCnt := wkRCnt + 1;
            wkId[wkRCnt] := id;
            NwSub(s, 1, q - 1, part);
            if length(part) > 70 then
               part := concat(copy(part, 1, 67), '...');
            FnNum(wkRCnt, big);
            big := concat(big, concat('  ', part));
            Clip(big, wkRRow[wkRCnt])
         end
      end;
   if wkRCnt = 0 then begin
      big := concat('No articles found for ', wkQ);
      SetBig(big);
      WkFail;
      exit(WkFind)
   end;
   big := concat('Wikipedia: ', wkQ);
   Clip(big, wkRTop);
   WkRDraw
end;

procedure WkArt (id : longint; page : integer);
{ Fetch page page of article id and show it: title, page count, then   }
{ 14 lines of text, then the keys.  The service puts the title on line  }
{ 1 and Pg:n/N on line 2 (h=1); an older server puts both on line 1.    }
var i, p, q : integer;
    first   : integer;
    last    : integer;
    okp     : boolean;
    v       : longint;
    s       : NewsStr;
    url     : Str255;
    part    : Str255;
    big     : Str255;
    row     : StatStr;
begin
   promptOn := false;
   wkRqK := 3;
   wkRqA := id;
   wkRqP := page;
   row := 'Wikipedia: fetching the article';
   Head(row);
   FnNum(id, part);
   url := concat(wkBase, concat('&h=1&a=', part));
   FnNum(page, part);
   url := concat(url, concat('&p=', part));
   svcName := 'Wikipedia';
   if not NwGet(url) then begin
      WkFail;
      exit(WkArt)
   end;

   { Pg:n/N on line 2, or at the end of line 1 }
   first := 3;
   q := 0;
   if nwCnt >= 2 then begin
      s := nwLine[2];
      q := pos('Pg:', s)
   end;
   if q = 0 then begin
      s := nwLine[1];
      q := pos('Pg:', s);
      first := 2
   end;
   okp := false;
   v := 0;
   p := 1;
   if q > 0 then begin
      p := q + 3;
      v := NwNumIn(s, p);
      if p <= length(s) then
         if s[p] = '/' then begin
            p := p + 1;
            okp := true
         end
   end;
   if (not okp) or (v < 1) or (v > 9999) then begin
      row := 'Wikipedia sent something unexpected:';
      SetLast(row);
      s := nwLine[1];
      NwSub(s, 1, 80, big);
      AddBig(big);
      WkFail;
      exit(WkArt)
   end;
   wkAPage := v;
   v := NwNumIn(s, p);
   if v > 9999 then v := 9999;
   if v < 1 then begin
      row := 'There is no article with that number.';
      SetLast(row);
      WkFail;
      exit(WkArt)
   end;
   if v < wkAPage then v := wkAPage;
   wkAPgs := v;
   wkArtId := id;

   quiet := true;
   LogMode;
   s := nwLine[1];                                 { the title }
   if first = 2 then begin                         { cut Pg:n/N off it }
      q := pos(' Pg:', s);
      if q > 1 then s[0] := chr(q - 1)
   end;
   if length(s) > 80 then begin
      NwSub(s, 1, 77, big);
      big := concat(big, '...')
   end
   else
      NwSub(s, 1, 80, big);
   AddBig(big);
   big := 'Wikipedia';
   FnNum(wkAPage, part);
   big := concat(big, concat('   Page ', part));
   FnNum(wkAPgs, part);
   big := concat(big, concat(' of ', part));
   AddBig(big);
   row := '';
   AddLine(row);
   last := nwCnt;
   if last > first - 1 + nwBody then
      last := first - 1 + nwBody;
   for i := first to last do begin
      s := nwLine[i];
      NwSub(s, 1, 80, big);
      AddBig(big)
   end;
   for i := last + 1 to first - 1 + nwBody do
      AddLine(row);                                { row is still empty }
   row := 'SPACE = next page   P = previous   L = the list   S = search   Q = leave';
   AddLine(row);
   quiet := false;
   DrawShow;
   wkMode := 3
end;

procedure WkKey (ch : char);
{ A key while in Wikipedia (the prompt's keys go to PromptKey instead). }
{ Q or Clear leaves, S asks for a new search, from anywhere.            }
var d : integer;
begin
   if (ch = 'Q') or (ch = 'q') or (ch = chr(27)) then begin
      wkMode := 0;
      HomePage;
      exit(WkKey)
   end;
   if (ch = 'S') or (ch = 's') then begin
      WkAsk;
      exit(WkKey)
   end;
   d := ord(ch) - 48;
   case wkMode of
      2 :
         if (d >= 1) and (d <= wkRCnt) then
            WkArt(wkId[d], 1);
      3 :
         if (ch = ' ') or (ch = 'N') or (ch = 'n') then begin
            if wkAPage < wkAPgs then
               WkArt(wkArtId, wkAPage + 1)
         end
         else if (ch = 'P') or (ch = 'p') then begin
            if wkAPage > 1 then
               WkArt(wkArtId, wkAPage - 1)
         end
         else if (ch = 'L') or (ch = 'l') then begin
            if wkRCnt > 0 then
               WkRDraw
         end
         else if (ch = 'R') or (ch = 'r') then
            WkArt(wkArtId, wkAPage);
      4 :
         if (ch = 'R') or (ch = 'r') then begin
            if wkRqK = 2 then
               WkFind
            else if wkRqK = 3 then
               WkArt(wkRqA, wkRqP)
         end
         else if (ch = 'L') or (ch = 'l') then begin
            if wkRCnt > 0 then
               WkRDraw
         end;
      otherwise

   end
end;

{------------------------------------------------------------------------}
{ The space station (REV J).  I fetches where the station is from       }
{ wheretheiss.at through the FujiNet; with your town set (T), how far   }
{ away it is and whether it is above your horizon.  The reading and the }
{ arithmetic are in LfjIss (LFJ-ISS.TEXT, its own segment).  The town   }
{ is looked up at open-meteo.com and kept in HOMETOWN.DATA.             }
{------------------------------------------------------------------------}

{ REV O: the space, crew and weather pages and the event code. }
{$S LFJPage}

procedure IsKeys (ok : boolean);
var row : StatStr;
begin
   row := '';
   AddLine(row);
   if ok then
      row := 'R = a fresh position   T = set your town   Q = back to the start'
   else
      row := 'R = try again   T = set your town   Q = back to the start';
   AddLine(row)
end;

procedure IsShow;
{ Fetch the station's position, then where it will be for the next 90  }
{ minutes, and show them on the world map (REV K): the map fills pane    }
{ lines 3 to 11, the words go under it, the keys on line 18.             }
var i   : integer;
    ok  : boolean;
    row : StatStr;
    url : Str255;
begin
   promptOn := false;
   nwMode := 0;
   wkMode := 0;
   isMode := 2;
   row := 'The International Space Station, right now';
   Head(row);
   svcName := 'wheretheiss.at';
   url := isUrl;
   isKeepM := 0;
   nwSplit := true;
   ok := NwGet(url);
   nwSplit := false;
   if ok then begin
      IsStaBeg;
      for i := 1 to nwCnt do
         IsStaLn(nwLine[i]);
      ok := IsStaEnd;
      if not ok then begin
         row := 'wheretheiss.at answered, but with no position in it.';
         SetLast(row)
      end
   end;
   if not ok then begin
      IsKeys(false);
      exit(IsShow)
   end;
   IsTrkBeg;                            { the path: a failure only loses the dots }
   if ssTs > 0 then begin
      IsTrkUrl(url);
      isKeepM := 1;
      nwSplit := true;
      if NwGet(url) then
         for i := 1 to nwCnt do
            IsTrkLn(nwLine[i]);
      nwSplit := false;
      isKeepM := 0
   end;
   IsTrkEnd;                            { the dotted path, worked out once }
   quiet := true;
   row := 'The International Space Station, right now';
   Head(row);
   row := '';
   for i := 1 to 8 do                   { Head's blank line and these 8: the map }
      AddLine(row);
   for i := 1 to isRCnt do begin
      row := isRow[i];
      AddLine(row)
   end;
   row := '';
   while statCnt < maxLines - 2 do
      AddLine(row);
   if isNote = '' then                  { REV N: where the crew is (Tim) }
      isNote := 'Who is aboard now?  Press P.          The weather in your town?  Press O.';
   AddLine(isNote);
   isNote := '';
   row := 'R fresh   T town   Q back     Map: O = station, dots = next 90 min, box = you';
   AddLine(row);
   isMapOn := true;
   quiet := false;
   DrawShow
end;

procedure IsAsk;
{ The town prompt.  RETURN at it runs IsFind (see TakeUrl). }
var row : StatStr;
    big : Str255;
begin
   nwMode := 0;
   wkMode := 0;
   row := 'Your town, for the space station and the weather';
   Head(row);
   if isHave then begin
      big := concat('Now:  ', isTown);
      AddBig(big)
   end;
   row := 'Type your town, a comma, and its state or country, then RETURN:';
   AddLine(row);
   row := '     Cincinnati, Ohio        Leeds, UK        Perth, Australia';
   AddLine(row);
   row := 'The FujiNet looks it up at open-meteo.com.  Clear cancels.';
   AddLine(row);
   row := '';
   AddLine(row);
   promptLbl := 'Your town: ';
   promptTxt := '';
   promptOn := true;
   AddLine(row);
   DrawPrompt;
   isMode := 1
end;

procedure CrDraw;
{ One screen of the crew page (crPer lines) from the rows LfjMore wrote. }
var i, top, last : integer;
    row          : StatStr;
begin
   quiet := true;
   row := 'Who is aboard the space stations';
   Head(row);
   top := (mrPage - 1) * crPer + 1;
   last := top + crPer - 1;
   if last > mrRCnt then last := mrRCnt;
   for i := top to last do begin
      row := mrRow[i];
      AddLine(row)
   end;
   row := '';
   while statCnt < maxLines - 1 do
      AddLine(row);
   if mrRCnt > crPer then
      row := 'N = more   R = fresh   I = the station   O = the weather   Q = back'
   else
      row := 'R = fresh   I = the station on the map   O = the weather   Q = back';
   AddLine(row);
   quiet := false;
   DrawShow
end;

procedure CrShow;
{ P (REV O): who is aboard the space stations, from the list kept at    }
{ corquaid.github.io.  LfjMore reads it as it arrives (isKeepM 2).      }
var ok  : boolean;
    row : StatStr;
    url : Str255;
begin
   promptOn := false;
   nwMode := 0;
   wkMode := 0;
   isMode := 3;
   row := 'Who is aboard the space stations';
   Head(row);
   svcName := 'corquaid.github.io';
   url := concat(crUrlA, crUrlB);
   CrBeg;
   isKeepM := 2;
   nwSplit := true;
   ok := NwGet(url);
   nwSplit := false;
   isKeepM := 0;
   if ok then
      if not CrEnd then begin
         ok := false;
         row := 'corquaid.github.io answered, but with no names in it.';
         SetLast(row)
      end;
   if not ok then begin
      row := '';
      AddLine(row);
      row := 'R = try again   I = the space station   Q = back to the start';
      AddLine(row);
      exit(CrShow)
   end;
   CrDraw
end;

procedure WxShow;
{ O (REV O): the weather in your town, now and for three days, from     }
{ open-meteo.com (no key).  No town yet: ask for it, then come back.    }
var ok  : boolean;
    i   : integer;
    row : StatStr;
    big : Str255;
    url : Str255;
begin
   promptOn := false;
   nwMode := 0;
   wkMode := 0;
   if not isHave then begin
      wxWant := true;
      IsAsk;
      exit(WxShow)
   end;
   isMode := 4;
   big := concat('The weather in ', isTown);
   Clip(big, row);
   Head(row);
   WxUrl(isLat, isLon, url);
   svcName := 'open-meteo.com';
   WxBeg;
   isKeepM := 3;
   nwSplit := true;
   ok := NwGet(url);
   nwSplit := false;
   isKeepM := 0;
   if ok then
      if not WxEnd then begin
         ok := false;
         if wxWhy <> '' then
            big := concat('open-meteo.com said:  ', wxWhy)
         else
            big := 'open-meteo.com answered, but with no weather in it.';
         SetBig(big)
      end;
   if not ok then begin
      row := '';
      AddLine(row);
      row := 'R = try again   T = another town   Q = back to the start';
      AddLine(row);
      exit(WxShow)
   end;
   quiet := true;
   big := concat('The weather in ', isTown);
   Clip(big, row);
   Head(row);
   for i := 1 to mrRCnt do begin
      row := mrRow[i];
      AddLine(row)
   end;
   row := '';
   while statCnt < maxLines - 1 do
      AddLine(row);
   row := 'R = fresh   T = another town   I = space station   P = crew   Q = back';
   AddLine(row);
   wxOn := true;                        { REV P: DrawShow adds the icons }
   quiet := false;
   DrawShow
end;

procedure IsFind;
{ RETURN at the town prompt: look the town up, keep it, show the page. }
var url  : Str255;
    nm   : Str255;
    enc  : Str255;
    big  : Str255;
    q    : UrlStr;
    i    : integer;
    ok   : boolean;
    row  : StatStr;
begin
   isMode := 2;
   IsQuery(promptTxt, nm);
   if length(nm) < 2 then begin
      row := 'Type the town''s name first, then a comma and its state or country.';
      SetLast(row);
      IsKeys(false);
      exit(IsFind)
   end;
   q := nm;
   WkEnc(q, enc);
   url := concat(isGeo, concat(isGeoQ, enc));
   svcName := 'open-meteo.com';
   nwSplit := true;
   ok := NwGet(url);
   nwSplit := false;
   if (not ok) and (not svcEmpty) then begin
      IsKeys(false);
      exit(IsFind)
   end;
   for i := 1 to nwCnt do
      IsGeoLn(nwLine[i]);
   if (not ok) or (not IsGeoEnd) then begin
      big := concat('open-meteo.com knows no town called ', concat(nm, '.  Try another spelling.'));
      SetBig(big);
      IsKeys(false);
      exit(IsFind)
   end;
   ok := IsSave(myVol);
   if not ok then
      isNote := 'HOMETOWN.DATA could not be written: the town lasts until you quit.'
   else if not isExact then
      isNote := 'No place matched the words after the comma; the first one found is used.';
   if wxWant then begin                 { REV O: the town was for the weather }
      wxWant := false;
      isNote := '';
      WxShow
   end
   else
      IsShow
end;

procedure IsKey (ch : char);
{ Keys on the station (isMode 2), crew (3) and weather (4) pages. }
begin
   if (ch = 'Q') or (ch = 'q') then begin
      isMode := 0;
      HomePage
   end
   else if (ch = 'I') or (ch = 'i') then
      IsShow
   else if (ch = 'P') or (ch = 'p') then
      CrShow
   else if (ch = 'O') or (ch = 'o') then
      WxShow
   else if (ch = 'T') or (ch = 't') then begin
      wxWant := isMode = 4;
      IsAsk
   end
   else if (ch = 'R') or (ch = 'r') then begin
      if isMode = 3 then
         CrShow
      else if isMode = 4 then
         WxShow
      else
         IsShow
   end
   else if (isMode = 3) and ((ch = 'N') or (ch = 'n') or (ch = ' ')) then begin
      if mrRCnt > crPer then begin
         mrPage := mrPage + 1;
         if (mrPage - 1) * crPer >= mrRCnt then mrPage := 1;
         CrDraw
      end
   end
end;

procedure StartFetch;
var row : StatStr;
    big : Str255;
begin
   row := 'Fetch a web file';
   Head(row);
   row := 'Type the address, then RETURN.  RETURN alone uses this one:';
   AddLine(row);
   big := concat('   ', curUrl);
   AddBig(big);
   row := 'N1: is put in front for you.  Apple-period cancels.';
   AddLine(row);
   row := '';
   AddLine(row);
   promptLbl := 'Address: ';
   promptTxt := '';
   promptOn := true;
   AddLine(row);
   DrawPrompt
end;

procedure CancelAsk;
var row : StatStr;
begin
   promptOn := false;
   if wkMode = 1 then begin                { the search prompt: back home }
      wkMode := 0;
      HomePage;
      exit(CancelAsk)
   end;
   if isMode = 1 then begin                { the town prompt: back home }
      isMode := 0;
      wxWant := false;
      HomePage;
      exit(CancelAsk)
   end;
   row := 'Cancelled.  Nothing was sent.';
   SetLast(row)
end;

procedure TakeUrl;
{ RETURN at the prompt.  Empty: keep curUrl.  Otherwise the typed text  }
{ becomes curUrl, with N1: (and HTTP:// when no scheme was typed) put   }
{ in front.  The prompt takes at most urlCap - 10 characters, so the    }
{ result always fits.                                                    }
var hasN1 : boolean;
begin
   promptOn := false;
   if wkMode = 1 then begin                { the search prompt, not an address }
      if length(promptTxt) = 0 then begin
         wkMode := 0;
         HomePage
      end
      else begin
         wkQ := promptTxt;
         WkFind
      end;
      exit(TakeUrl)
   end;
   if isMode = 1 then begin                { the town prompt }
      if length(promptTxt) = 0 then begin
         isMode := 0;
         HomePage
      end
      else
         IsFind;
      exit(TakeUrl)
   end;
   if length(promptTxt) > 0 then begin
      hasN1 := false;
      if length(promptTxt) >= 3 then
         hasN1 := ((promptTxt[1] = 'N') or (promptTxt[1] = 'n'))
                  and (promptTxt[2] = '1') and (promptTxt[3] = ':');
      if hasN1 then
         curUrl := promptTxt
      else if pos('://', promptTxt) = 0 then
         curUrl := concat('N1:HTTP://', promptTxt)
      else
         curUrl := concat('N1:', promptTxt)
   end;
   DoFetch
end;

procedure PromptKey (ch : char);
{ RETURN (or ENTER) finishes, Backspace erases, Clear cancels, anything }
{ printable except a space is added (a space too at the search prompt). }
var tmp : string[1];
    cap : integer;
    ok  : boolean;
begin
   cap := urlCap - 10;
   if wkMode = 1 then cap := wkQCap;
   if isMode = 1 then cap := isTCap;
   ok := (ch > ' ') and (ch <= '~');
   if (ch = ' ') and ((wkMode = 1) or (isMode = 1)) and (length(promptTxt) > 0) then ok := true;
   if (ch = chr(13)) or (ch = chr(3)) then
      TakeUrl
   else if ch = chr(27) then
      CancelAsk
   else if ((ch = 'Q') or (ch = 'q')) and (promptTxt = '') then
      CancelAsk                        { REV G: Q at an empty prompt cancels it }
   else if ch = chr(8) then begin
      if length(promptTxt) > 0 then begin
         promptTxt[0] := chr(length(promptTxt) - 1);
         DrawPrompt
      end
   end
   else if ok and (length(promptTxt) < cap) then begin
      tmp := ' ';
      tmp[1] := ch;
      promptTxt := concat(promptTxt, tmp);
      DrawPrompt
   end
end;

procedure PlainKey (ch : char);
{ Keys without the Apple key, when no prompt is up.  In the news, every }
{ key goes to NwKey.                                                     }
begin
   if ckMode = 1 then
      CkAnswer(ch)
   else if wkMode <> 0 then
      WkKey(ch)
   else if nwMode <> 0 then
      NwKey(ch)
   else if isMode <> 0 then
      IsKey(ch)
   else if (ch = 'N') or (ch = 'n') then
      NwCats
   else if (ch = 'I') or (ch = 'i') then
      IsShow
   else if (ch = 'P') or (ch = 'p') then
      CrShow
   else if (ch = 'O') or (ch = 'o') then
      WxShow
   else if (ch = 'T') or (ch = 't') then
      IsAsk
   else if (ch = 'S') or (ch = 's') then
      WkAsk
   else if (ch = 'C') or (ch = 'c') then
      CkAsk
   else if (ch = 'A') or (ch = 'a') then
      DoTests(0)
   else if ch = '1' then
      DoTests(1)
   else if ch = '2' then
      DoTests(2)
   else if ch = '3' then
      DoTests(3)
   else if (ch = 'F') or (ch = 'f') then
      StartFetch
   else if (ch = 'B') or (ch = 'b') then
      ShowBytes
   else if (ch = 'H') or (ch = 'h') or (ch = '?') then
      HelpUse
   else if (ch = 'W') or (ch = 'w') then
      HelpWire
end;

{------------------------------------------------------------------------}
{ Window.                                                                }
{------------------------------------------------------------------------}

procedure doUpdateEvent (normal : boolean; window : WindowPtr);
begin
   if normal then BeginUpdate(window);
   DrawShow;
   if normal then EndUpdate(window)
end;

procedure InitNewDoc (window : WindowPtr);
begin
   myWindow := window;
   TakeWindow(myWindow);
   FolderSize(myWindow, winW, winH, false);
   SetPort(myWindow);
   ValidRect(myWindow^.portRect);

   HomePage;                            { opens on the key list }
   doUpdateEvent(false, myWindow);

   if activeFolder = myWindow then
      PutUpMenus
end;

procedure DoFilerEvent;
var wantsOpen : boolean;
begin
   HandleFilerOp(wantsOpen);
   if wantsOpen then
      InitNewDoc(theEvent.who)
end;

{------------------------------------------------------------------------}
{ Commands and events.                                                   }
{------------------------------------------------------------------------}

procedure MenuCommand (menu, item : integer);
var err : integer;
begin
   promptOn := false;                   { a menu command abandons the prompt }
   ckMode := 0;                         { and the clock question }
   isMode := 0;                         { and the space station page }
   wxWant := false;                     { and a town asked for the weather }
   if (menu = mTest) or (menu = mSpeed) or (menu = mHelp) then begin
      nwMode := 0;                      { and these leave the news }
      wkMode := 0                       { and Wikipedia }
   end;
   case menu of

      mFile :
         case item of
            miAsideAll : DoFilingCmd(cmdClosAll);
            miAside    : DoFilingCmd(cmdClose);
            miPutAway  :
               begin
                  TellFiler(err, docClosd, docPutBack, myWindow);
                  myWindow := nil
               end;
         end;

      mNews :
         if (item >= 1) and (item <= 9) then begin
            wkMode := 0;
            NwList(item, 1)
         end;

      mWiki :
         begin
            nwMode := 0;
            case item of
               miWkFind : WkAsk;
               miWkLisa : WkArt(wkLisa, 1);
            end
         end;

      mSpace :
         begin
            nwMode := 0;
            wkMode := 0;
            case item of
               miIsShow : IsShow;
               miIsTown : IsAsk;
               miCrew   : CrShow;
            end
         end;

      mWthr :
         begin
            nwMode := 0;
            wkMode := 0;
            case item of
               miWxShow : WxShow;
               miWxTown :
                  begin
                     wxWant := true;
                     IsAsk
                  end;
            end
         end;

      mTest :
         case item of
            miAll   : DoTests(0);
            miFetch : StartFetch;
            miT1    : DoTests(1);
            miT2    : DoTests(2);
            miT3    : DoTests(3);
            miBytes : ShowBytes;
            miClock : CkAsk;
         end;

      mSpeed :
         case item of
            mi9600  : SetSpeed(9600);
            mi19200 : SetSpeed(19200);
         end;

      mHelp :
         case item of
            miHelpUse  : HelpUse;
            miHelpWire : HelpWire;
         end;

      mVer :
         case item of
            miAbout : NoteAlert(allAlerts, alrtAbou);
         end;

   end
end;

procedure ProcessTheEvent;
var theMenu, theItem : integer;
begin
   case theEvent.what of

      buttonDown :
         if theEvent.who = menuFolder then begin
            MenuSelect(theEvent.where, theMenu, theItem);
            if (theMenu <> 0) and (theItem <> 0) then
               MenuCommand(theMenu, theItem);
            HiLiteMenu(0)
         end;

      buttonUp :
         ;

      keyDown :
         if (theEvent.who = myWindow) and (not theEvent.repeatKey) then begin
            if theEvent.appleKey then begin
               if theEvent.ascii = '.' then begin
                  if promptOn then
                     CancelAsk
               end
               else begin
                  MenuKey(theEvent.ascii, theMenu, theItem);
                  if theMenu <> 0 then begin
                     HiLiteMenu(theMenu);
                     MenuCommand(theMenu, theItem);
                     HiLiteMenu(0)
                  end
               end
            end
            else if promptOn then
               PromptKey(theEvent.ascii)
            else
               PlainKey(theEvent.ascii)
         end;

      folderActivate :
         begin
            TakeControl(theEvent, false, false);
            PutUpMenus
         end;

      folderDeactivate :
         GiveControl(theEvent);

      folderUpdate :
         if theEvent.who = myWindow then
            doUpdateEvent(true, theEvent.who)
         else begin
            BeginUpdate(theEvent.who);
            EndUpdate(theEvent.who)
         end;

      folderMoved :
         ;

      filerEvent :
         DoFilerEvent;

      abortEvent, diedEvent, diskEvent, catalogEvent, nilEvent :
         ;

      otherwise

   end
end;

{------------------------------------------------------------------------}
{ Initialize.                                                            }
{------------------------------------------------------------------------}

procedure Initialize;
var err      : integer;
    schedErr : integer;
    tmp1     : string[1];
    pcInfo   : procinfoRec;
    excName  : t_ex_name;
    myPrefix : TParamAlert;
    cutAt    : integer;
begin
   initing := true;

   excName := 'SYS_TERMINATE';
   Declare_Excep_Hdl(err, excName, @LastWishes);
   if err <> 0 then begin
      TellFiler(err, initFailed, noMemory, nil);
      halt
   end;

   toldToDie := false;
   myWindow  := nil;
   statCnt   := 0;
   quiet     := false;
   promptOn  := false;
   promptTxt := '';
   promptLbl := '';
   curUrl    := defUrl;
   curBaud   := 9600;
   cancelled := false;
   capCnt    := 0;
   nwMode    := 0;
   nwCnt     := 0;
   nwCat     := 1;
   nwPage    := 1;
   nwPgs     := 0;
   nwHCnt    := 0;
   nwHTop    := '';
   nwArtId   := 0;
   nwAPage   := 1;
   nwAPgs    := 0;
   nwRqK     := 0;
   nwRqC     := 1;
   nwRqA     := 0;
   nwRqP     := 1;
   svcName   := 'the news service';
   svcEmpty  := false;
   wkMode    := 0;
   wkQ       := '';
   wkRCnt    := 0;
   wkRTop    := '';
   wkArtId   := 0;
   wkAPage   := 1;
   wkAPgs    := 0;
   wkRqK     := 0;
   wkRqA     := 0;
   wkRqP     := 1;
   ckMode    := 0;
   isMode    := 0;
   isNote    := '';
   nwSplit   := false;
   ckY       := 0;
   ckMo      := 1;
   ckD       := 1;
   ckH       := 0;
   ckMi      := 0;
   ckTwin    := 0;
   ckDoy     := 1;
   FnInit;

   InitHeap(@myZone[0], @myZone[maxHeap], @OutOfHeapSpace);

   Sched_Class(schedErr, false);
   Info_Process(err, My_ID, pcInfo);
   Sched_Class(schedErr, true);

   cutAt := pos('}', pcInfo.progpathname);
   if (cutAt = 0) or (cutAt > 40) then begin
      TellFiler(err, initFailed, internalError, nil);
      halt
   end;
   myPrefix := copy(pcInfo.progpathname, 1, cutAt);
   { the device prefix alone: everything before the open-brace of the  }
   { tool file set.  chr(123) is the open brace, built the SanName way. }
   tmp1 := ' ';
   tmp1[1] := chr(123);
   cutAt := pos(tmp1, pcInfo.progpathname);
   if (cutAt > 1) and (cutAt <= 33) then
      myVol := copy(pcInfo.progpathname, 1, cutAt - 1)
   else
      myVol := '-#12-';                { defensive fallback: boot }
   IsInit;
   MrInit;                             { REV O: the crew and weather pages }
   if IsLoad(myVol) then ;             { REV J: your town, if HOMETOWN.DATA is there }

   InitMP(theHeap, myPrefix, @AlertFailed, alertVerNum,
          @myMenus[mFile], allAlerts, err);
   if err > 0 then begin
      TellFiler(err, initFailed, noMemory, nil);
      halt
   end;

   InitWmlCrs(err);
   if err <> 0 then begin
      TellFiler(err, initFailed, noDiskSpace, nil);
      halt
   end;

   SetPort(deskPort);

   initing := false
end;

{------------------------------------------------------------------------}
{ The main program -- two-phase loop, nothing to do when idle.           }
{------------------------------------------------------------------------}

begin { main program }

   InitGraf(@thePort);
   OpenWm;
   Initialize;

   repeat

      while not (ImActive or toldToDie) do begin
         GetEvent(theEvent);
         ProcessTheEvent
      end;

      while ImActive and (not toldToDie) do begin
         if EventAvail then begin
            GetEvent(theEvent);
            ProcessTheEvent
         end
         else
            LetOthersRun
      end;

   until toldToDie;

   termErr := 0
end.
