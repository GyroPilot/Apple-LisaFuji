unit Menus; interface
uses UnitStd, QuickDraw;
type MenuInfo = record id : integer end;
procedure ClearMenuBar;
procedure InsertMenu(var m : MenuInfo; before : integer);
procedure DrawMenuBar;
procedure MenuSelect(where : Point; var theMenu, theItem : integer);
procedure MenuKey(ch : char; var theMenu, theItem : integer);
procedure HiLiteMenu(m : integer);
implementation
uses Events;
procedure ClearMenuBar; begin end;
procedure InsertMenu(var m : MenuInfo; before : integer); begin end;
procedure DrawMenuBar; begin end;
procedure MenuSelect(where : Point; var theMenu, theItem : integer); begin theMenu := pickMenu; theItem := pickItem end;
procedure MenuKey(ch : char; var theMenu, theItem : integer);
begin
  { the /keys in LFJ-ALERTS.TEXT }
  theMenu := 0; theItem := 0;
  case upcase(ch) of
    'A' : begin theMenu := 3; theItem := 1 end;   { REV B: Test is menu 3 }
    'F' : begin theMenu := 3; theItem := 2 end;
    'B' : begin theMenu := 3; theItem := 8 end;
    'H' : begin theMenu := 5; theItem := 1 end;   { REV B: Help is menu 5 }
    'W' : begin theMenu := 5; theItem := 2 end;
  end
end;
procedure HiLiteMenu(m : integer); begin end;
end.
