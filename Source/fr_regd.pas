{ ***************************************** }
{ }
{ FastReport v2.3 }
{ Registration unit }
{ }
{ Copyright (c) 1998-99 by Tzyganenko A. }
{ }
{ ***************************************** }

unit Fr_regd;

interface

{$I FR.inc}
procedure Register;

implementation

uses
  Classes,
  FR_Ctrls, FR_Dock, FR_DBOp;

procedure Register;
begin
  RegisterComponents('FR Tools', [TfrSpeedButton, TfrDock, TfrToolBar, TfrTBButton, TfrTBSeparator, TfrTBPanel,
    TfrOpenDBDialog]);
end;

end.
