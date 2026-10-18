unit Events; interface
uses UnitStd, QuickDraw;
type WindowPtr = GrafPtr;
     EventKind = (nilEvent, buttonDown, buttonUp, keyDown, folderActivate, folderDeactivate,
                  folderUpdate, folderMoved, filerEvent, abortEvent, diedEvent, diskEvent, catalogEvent);
     EventRecord = record what : EventKind; who : WindowPtr; where : Point;
                     ascii : char; appleKey, repeatKey : boolean; filerOp : integer end;
var menuFolder, activeFolder, deskPort : WindowPtr;
    script : string; scriptAt : integer; theWin, theBar : GrafPort; opened, finished : boolean;
    pickMenu, pickItem : integer;
procedure GetEvent(var e : EventRecord);
function EventAvail : boolean;
function ImActive : boolean;
procedure LetOthersRun;
procedure ImDying;
implementation
uses SimCfg, LSysCall;
{ Script: letters and digits are keys, ~ RETURN, < Backspace, ^x Apple-x,
  @mi menu m item i picked with the mouse, ! shows the screen now.  While Serial B is open (a
  command is running) no script key is delivered; instead, after cfAbort
  network reads, one key press arrives (the "stop" key). }
var typing : boolean;

function EventAvail : boolean;
begin
  if serOpen then EventAvail := (cfAbort > 0) and (serReads >= cfAbort)
  else EventAvail := true
end;
function ImActive : boolean; begin ImActive := true end;
procedure LetOthersRun; begin end;
procedure ImDying; begin end;
procedure GetEvent(var e : EventRecord);
var c : char;
begin
  e.appleKey := false; e.repeatKey := false; e.who := @theWin;
  if serOpen then begin e.what := keyDown; e.ascii := 'x'; writeln('   [key pressed during the fetch]'); exit end;
  if not opened then begin
    opened := true; activeFolder := @theWin; e.what := filerEvent; e.filerOp := 0; exit
  end;
  if scriptAt = 1 then DumpScreen('window opened')
  else begin
    c := script[scriptAt - 1];
    if not (typing and (c <> '~')) then DumpScreen('after ' + copy(script, 1, scriptAt - 1))
  end;
  if scriptAt > length(script) then begin
    e.what := filerEvent; e.filerOp := 9; finished := true; exit
  end;
  c := script[scriptAt]; scriptAt := scriptAt + 1;
  if c = '!' then begin DumpScreen('typing so far'); c := script[scriptAt]; scriptAt := scriptAt + 1 end;
  e.what := keyDown;
  if c = '~' then begin e.ascii := chr(13); typing := false end
  else if c = '<' then e.ascii := chr(8)
  else if c = '^' then begin e.appleKey := true; e.ascii := script[scriptAt]; scriptAt := scriptAt + 1; typing := false end
  else if c = '@' then begin
    e.what := buttonDown; e.who := menuFolder; typing := false;
    pickMenu := ord(script[scriptAt]) - 48; pickItem := ord(script[scriptAt + 1]) - 48; scriptAt := scriptAt + 2
  end
  else begin
    e.ascii := c;
    if ((c = 'F') or (c = 'S')) and not typing then typing := true   { F: address prompt; S: search prompt }
  end
end;
begin
  script := cfScript; scriptAt := 1; opened := false; finished := false; typing := false;
  menuFolder := @theBar;
end.
