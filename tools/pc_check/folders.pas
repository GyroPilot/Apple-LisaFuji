unit Folders; interface
uses UnitStd, QuickDraw, Events;
procedure OpenWm;
procedure TakeWindow(w : WindowPtr);
procedure FolderSize(w : WindowPtr; wd, ht : integer; b : boolean);
procedure BeginUpdate(w : WindowPtr);
procedure EndUpdate(w : WindowPtr);
procedure TakeControl(var e : EventRecord; a, b : boolean);
procedure GiveControl(var e : EventRecord);
implementation
procedure OpenWm; begin end;
procedure TakeWindow(w : WindowPtr); begin end;
procedure FolderSize(w : WindowPtr; wd, ht : integer; b : boolean); begin end;
procedure BeginUpdate(w : WindowPtr); begin end;
procedure EndUpdate(w : WindowPtr); begin end;
procedure TakeControl(var e : EventRecord; a, b : boolean); begin end;
procedure GiveControl(var e : EventRecord); begin end;
end.
