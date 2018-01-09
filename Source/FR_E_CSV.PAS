{ ***************************************** }
{ FastReport v2.3 }
{ CSV export filter }
{ Copyright (c) 1998-99 by Tzyganenko A. }
{ ***************************************** }

unit FR_E_CSV;

interface

{$I FR.inc}

uses
  SysUtils, Classes, Graphics,
  FR_Class, FR_E_TXT, FR_Const;

type
  TfrCSVExport = class(TComponent)// fake component
  end;

  TfrCSVExportFilter = class(TfrTextExportFilter)
  public
    procedure OnEndPage; override;
  end;

implementation

procedure TfrCSVExportFilter.OnEndPage;
const
  FIELD_SEPARATOR = ';';
var
  i, j, n, tc1, tc2: Integer;
  p: PfrTextRec;
  s: AnsiString;
begin
  n := Pred(Lines.Count);
  while n >= 0 do
  begin
    if Lines[n] <> nil then
      break;
    Dec(n);
  end;

  for i := 0 to n do
  begin
    s := EmptyAnsiStr;
    tc1 := 0;
    p := PfrTextRec(Lines[i]);
    while p <> nil do
    begin
      tc2 := p^.X div 64;
      for j := 0 to tc2 - tc1 - 1 do
        s := s + FIELD_SEPARATOR;
      s := s + AnsiString(p^.Text);
      tc1 := tc2;
      p := p^.Next;
    end;
    s := s + sLineBreak;
    Stream.Write(s[1], Length(s));
  end;
end;

initialization

frRegisterExportFilter(TfrCSVExportFilter, LoadStr(SCSVFile) + ' (*.csv)', '*.csv');

end.
