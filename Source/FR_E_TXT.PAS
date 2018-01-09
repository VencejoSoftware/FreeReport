{ ***************************************** }
{ FastReport v2.3 }
{ Text export filter }
{ Copyright (c) 1998-99 by Tzyganenko A. }
{ ***************************************** }

unit FR_E_TXT;

interface

{$I FR.inc}

uses
  SysUtils, Classes, Graphics, Dialogs, UITypes,
  FR_Class, FR_Utils, FR_Const;

type
  TfrTextExport = class(TComponent)// fake component
  end;

  TfrTextExportFilter = class(TfrExportFilter)
  public
    constructor Create(AStream: TStream); override;
    procedure OnEndPage; override;
    procedure OnBeginPage; override;
    procedure OnText(X, Y: Integer; const Text: String; View: TfrView); override;
  end;

implementation

var
  UsedFont: Integer = 16;

constructor TfrTextExportFilter.Create(AStream: TStream);
var
  s: String;
  n: Integer;
begin
  inherited;
  s := InputBox(LoadStr(SFilter), LoadStr(SFilterParam), '16');
  Val(s, UsedFont, n);
end;

procedure TfrTextExportFilter.OnEndPage;
var
  i, n, X, tc1: Integer;
  p: PfrTextRec;
  s: AnsiString;
  function Dup(Count: Integer): AnsiString;
  var
    i: Integer;
  begin
    Result := EmptyAnsiStr;
    for i := 1 to Count do
      Result := Result + ' ';
  end;

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
      X := Round(p^.X / 6.5);
      s := s + Dup(X - tc1) + p^.Text;
      tc1 := X + Length(p^.Text);
      p := p^.Next;
    end;
    s := s + sLineBreak;
    Stream.Write(s[1], Length(s));
  end;
  s := #12 + sLineBreak;
  Stream.Write(s[1], Length(s));
end;

procedure TfrTextExportFilter.OnBeginPage;
var
  i: Integer;
begin
  ClearLines;
  for i := 0 to 200 do
    Lines.Add(nil);
end;

procedure TfrTextExportFilter.OnText(X, Y: Integer; const Text: String; View: TfrView);
var
  p, p1, p2: PfrTextRec;
begin
  if View = nil then
    Exit;
  Y := Round(Y / UsedFont);
  p1 := PfrTextRec(Lines[Y]);
  GetMem(p, SizeOf(TfrTextRec));
  FillChar(p^, SizeOf(TfrTextRec), 0);
  p^.Next := nil;
  p^.X := X;
  p^.Text := ShortString(Text);
  if View is TfrMemoView then
    with View as TfrMemoView do
    begin
      p^.FontName := ShortString(Font.Name);
      p^.FontSize := Font.Size;
      p^.FontStyle := frGetFontStyle(Font.Style);
      p^.FontColor := Font.Color;
{$IFNDEF Delphi2}
      p^.FontCharset := Font.Charset;
{$ENDIF}
    end;
  p^.FillColor := View.FillColor;
  if p1 = nil then
    Lines[Y] := TObject(p)
  else
  begin
    p2 := p1;
    while (p1 <> nil) and (p1^.X < p^.X) do
    begin
      p2 := p1;
      p1 := p1^.Next;
    end;
    if p2 <> p1 then
    begin
      p2^.Next := p;
      p^.Next := p1;
    end else begin
      Lines[Y] := TObject(p);
      p^.Next := p1;
    end;
  end;
end;

initialization

frRegisterExportFilter(TfrTextExportFilter, LoadStr(STextFile) + ' (*.txt)', '*.txt');

end.
