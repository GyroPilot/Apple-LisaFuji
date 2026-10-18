unit FilerComm; interface
uses UnitStd, QuickDraw, Events;
type FlrOp = (fcNone, fcResume, fcClose, fcSuspend, fcShred, fcCopy, fcPut, fcDfClose, fcX, fcTerminate);
     FilerExt = record theFlrOp : FlrOp end;
     FReply = (docClosd, docNotXfered, dfClosed, initFailed);
     FWhy = (allOK, internalError, noMemory, noDiskSpace, docPutBack);
     FCmd = (cmdClosAll, cmdClose);
procedure GetAddParms(var err : integer; var e : EventRecord; var fx : FilerExt);
procedure TellFiler(var err : integer; r : FReply; w : FWhy; who : WindowPtr);
procedure DoFilingCmd(c : FCmd);
implementation
procedure GetAddParms(var err : integer; var e : EventRecord; var fx : FilerExt);
begin err := 0; fx.theFlrOp := FlrOp(e.filerOp) end;
procedure TellFiler(var err : integer; r : FReply; w : FWhy; who : WindowPtr); begin err := 0 end;
procedure DoFilingCmd(c : FCmd); begin end;
end.
