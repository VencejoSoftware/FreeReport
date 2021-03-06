{ ****************************************** }
{ }
{ FastReport v2.3 }
{ Interpreter }
{ }
{ Copyright (c) 1998-2000 by Tzyganenko A. }
{ }
{ ****************************************** }

unit FR_Intrp;

interface

{$I FR.inc}

uses
  Classes, SysUtils, Graphics, FR_Pars, Variants;

type
  TfrInterpretator = class(TObject)
  private
    FParser: TfrParser;
  public
    constructor Create;
    destructor Destroy; override;
    procedure GetValue(const Name: String; var Value: Variant); virtual;
    procedure SetValue(const Name: String; Value: Variant); virtual;
    procedure DoFunction(const Name: String; p1, p2, p3: Variant; var val: String); virtual;
    procedure PrepareScript(MemoFrom, MemoTo, MemoErr: TStringList); virtual;
    procedure DoScript(Memo: TStringList); virtual;
  end;

  TfrVariables = class(TObject)
  private
    FList: TList;
    procedure SetVariable(Name: String; Value: Variant);
    function GetVariable(Name: String): Variant;
    procedure SetValue(Index: Integer; Value: Variant);
    function GetValue(Index: Integer): Variant;
    function GetName(Index: Integer): String;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Delete(Index: Integer);
    function IndexOf(Name: String): Integer;
    property Variable[Name: String]: Variant read GetVariable write SetVariable; default;
    property Value[Index: Integer]: Variant read GetValue write SetValue;
    property Name[Index: Integer]: String read GetName;
    property Count: Integer read GetCount;
  end;

implementation

{$IFDEF Delphi6}

uses
  Variants;
{$ENDIF}

type
  TCharArray = Array [0 .. 31999] of WideChar;
  PCharArray = ^TCharArray;

  lrec = record
    Name: String[16];
    n: Integer;
  end;

  PVariable = ^TVariable;

  TVariable = record
{$IFDEF UNICODE}
    Name: PAnsiString;
{$ELSE}
    Name: PString;
{$ENDIF}
    Value: Variant;
  end;

const
  ttIf = #1;
  ttGoto = #2;
  ttProc = #3;

var
  labels: Array [0 .. 100] of lrec;
  labc: Integer;

{ ------------------------------------------------------------------------------ }
constructor TfrVariables.Create;
begin
  inherited Create;
  FList := TList.Create;
end;

destructor TfrVariables.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TfrVariables.Clear;
begin
  while FList.Count > 0 do
    Delete(0);
end;

procedure TfrVariables.SetVariable(Name: String; Value: Variant);
var
  i: Integer;
  p: PVariable;
begin
  for i := 0 to FList.Count - 1 do
    if CompareText(String(PVariable(FList[i]).Name^), Name) = 0 then
    begin
      PVariable(FList[i]).Value := Value;
      Exit;
    end;
  GetMem(p, SizeOf(TVariable));
  FillChar(p^, SizeOf(TVariable), 0);
  p^.Name := PAnsiString(Name);
  p^.Value := Value;
  FList.Add(p);
end;

function TfrVariables.GetVariable(Name: String): Variant;
var
  i: Integer;
begin
  Result := Null;
  for i := 0 to FList.Count - 1 do
    if CompareText(String(PVariable(FList[i]).Name^), Name) = 0 then
    begin
      Result := PVariable(FList[i]).Value;
      break;
    end;
end;

procedure TfrVariables.SetValue(Index: Integer; Value: Variant);
begin
  if (Index < 0) or (Index >= FList.Count) then
    Exit;
  PVariable(FList[Index])^.Value := Value;
end;

function TfrVariables.GetValue(Index: Integer): Variant;
begin
  Result := 0;
  if (Index < 0) or (Index >= FList.Count) then
    Exit;
  Result := PVariable(FList[Index])^.Value;
end;

function TfrVariables.IndexOf(Name: String): Integer;
var
  i: Integer;
begin
  Result := - 1;
  for i := 0 to FList.Count - 1 do
    if CompareText(String(PVariable(FList[i]).Name^), Name) = 0 then
    begin
      Result := i;
      break;
    end;
end;

function TfrVariables.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TfrVariables.GetName(Index: Integer): String;
begin
  Result := '';
  if (Index < 0) or (Index >= FList.Count) then
    Exit;
  Result := String(PVariable(FList[Index])^.Name^);
end;

procedure TfrVariables.Delete(Index: Integer);
var
  p: PVariable;
begin
  if (Index < 0) or (Index >= FList.Count) then
    Exit;
  p := FList[Index];
  p^.Value := 0;
  FreeMem(p, SizeOf(TVariable));
  FList.Delete(Index);
end;

{ ------------------------------------------------------------------------------ }
function Remain(S: String; From: Integer): String;
begin
  Result := Copy(S, From, Length(S) - 1);
end;

function GetIdentify(const S: String; var i: Integer): String;
var
  k: Integer;
begin
  while (i <= Length(S)) and (S[i] = ' ') do
    Inc(i);
  k := i;
  while (i <= Length(S)) and (S[i] <> ' ') do
    Inc(i);
  Result := Copy(S, k, i - k);
end;

{ ----------------------------------------------------------------------------- }
constructor TfrInterpretator.Create;
begin
  inherited Create;
  FParser := TfrParser.Create;
  FParser.OnGetValue := GetValue;
  FParser.OnFunction := DoFunction;
end;

destructor TfrInterpretator.Destroy;
begin
  FParser.Free;
  inherited Destroy;
end;

procedure TfrInterpretator.PrepareScript(MemoFrom, MemoTo, MemoErr: TStringList);
var
  i, j, cur, lastp: Integer;
  S, bs: String;
  len: Integer;
  buf: PCharArray;
  Error: Boolean;

procedure DoCommand; forward;
procedure DoBegin; forward;
procedure DoIf; forward;
procedure DoRepeat; forward;
procedure DoWhile; forward;
procedure DoGoto; forward;
procedure DoEqual; forward;
procedure DoExpression; forward;
procedure DoSExpression; forward;
procedure DoTerm; forward;
procedure DoFactor; forward;
procedure DoVariable; forward;
procedure DoConst; forward;
procedure DoLabel; forward;
procedure DoFunc; forward;
procedure DoFuncId; forward;

  function last: Integer;
  begin
    Result := MemoTo.Count;
  end;

  function CopyArr(cur, n: Integer): String;
  begin
    SetLength(Result, n);
    Move(buf^[cur], Result[1], n * SizeOf(char));
  end;

  procedure AddLabel(S: String; n: Integer);
  var
    i: Integer;
    f: Boolean;
  begin
    f := True;
    for i := 0 to Pred(labc) do
      if labels[i].Name = ShortString(S) then
        f := False;
    if f then
    begin
      labels[labc].Name := ShortString(S);
      labels[labc].n := n;
      Inc(labc);
    end;
  end;

  procedure SkipSpace;
  begin
    while (buf^[cur] = ' ') and (cur < len) do
      Inc(cur);
  end;

  function GetToken: String;
  var
    j: Integer;
  begin
    SkipSpace;
    j := cur;
    Inc(cur);
    while (buf^[cur] > ' ') and (cur < len) do
      Inc(cur);
    Result := UpperCase(CopyArr(j, cur - j));
  end;

  procedure AddError(S: String);
  var
    i, j, c: Integer;
    s1: String;
  begin
    Error := True;
    cur := lastp;
    SkipSpace;
    c := 0;
    for i := 0 to cur do
      if buf^[i] > ' ' then
        Inc(c);
    i := 0;
    j := 1;
    while c > 0 do
    begin
      s1 := MemoFrom[i];
      j := 1;
      while (j <= Length(s1)) and (c > 0) do
      begin
        if s1[j] = '{' then
          break;
        if s1[j] > ' ' then
          Dec(c);
        Inc(j);
      end;
      if c = 0 then
        break;
      Inc(i);
    end;
    MemoErr.Add('������ ' + IntToStr(i + 1) + '/' + IntToStr(j - 1) + ': ' + S);
  end;

  procedure ProcessBrackets(var i: Integer);
  var
    c: Integer;
    fl1, fl2: Boolean;
  begin
    fl1 := True;
    fl2 := True;
    c := 0;
    Dec(i);
    repeat
      Inc(i);
      if fl1 and fl2 then
        if buf^[i] = '[' then
          Inc(c)
        else
          if buf^[i] = ']' then
            Dec(c);
      if fl1 then
        if buf^[i] = '"' then
          fl2 := not fl2;
      if fl2 then
        if buf^[i] = '''' then
          fl1 := not fl1;
    until (c = 0) or (i >= len);
  end;

  { ---------------------------------------------- }
  procedure DoDigit;
  begin
    while (buf^[cur] = ' ') and (cur < len) do
      Inc(cur);
    if CharInset(buf^[cur], ['0' .. '9']) then
      while CharInset(buf^[cur], ['0' .. '9']) and (cur < len) do
        Inc(cur)
    else
      Error := True;
  end;

  procedure DoBegin;
  label
    1;
  begin
  1:
    DoCommand;
    if Error then
      Exit;
    lastp := cur;
    bs := GetToken;
    if (bs = '') or (bs[1] = ';') then
    begin
      cur := cur - Length(bs) + 1;
      goto 1;
    end else if Pos('END', bs) = 1 then
      cur := cur - Length(bs) + 3
    else
      AddError('����� ��������� ";" ��� "end"');
  end;

  procedure DoIf;
  var
    nsm, nl, nl1: Integer;
  begin
    nsm := cur;
    DoExpression;
    if Error then
      Exit;
    bs := ttIf + '  ' + CopyArr(nsm, cur - nsm);
    nl := last;
    MemoTo.Add(bs);
    lastp := cur;
    if GetToken = 'THEN' then
    begin
      DoCommand;
      if Error then
        Exit;
      nsm := cur;
      if GetToken = 'ELSE' then
      begin
        nl1 := last;
        MemoTo.Add(ttGoto + '  ');
        bs := MemoTo[nl];
        bs[2] := Chr(last);
        bs[3] := Chr(last div 256);
        MemoTo[nl] := bs;
        DoCommand;
        bs := MemoTo[nl1];
        bs[2] := Chr(last);
        bs[3] := Chr(last div 256);
        MemoTo[nl1] := bs;
      end else begin
        bs := MemoTo[nl];
        bs[2] := Chr(last);
        bs[3] := Chr(last div 256);
        MemoTo[nl] := bs;
        cur := nsm;
      end;
    end
    else
      AddError('����� ��������� "then"');
  end;

  procedure DoRepeat;
  label
    1;
  var
    nl, nsm: Integer;
  begin
    nl := last;
  1:
    DoCommand;
    if Error then
      Exit;
    lastp := cur;
    bs := GetToken;
    if bs[1] = ';' then
    begin
      cur := cur - Length(bs) + 1;
      goto 1;
    end else if bs = 'UNTIL' then
    begin
      nsm := cur;
      DoExpression;
      MemoTo.Add(ttIf + Chr(nl) + Chr(nl div 256) + CopyArr(nsm, cur - nsm));
    end
    else
      AddError('����� ��������� ";" ��� "until"');
  end;

  procedure DoWhile;
  var
    nl, nsm: Integer;
  begin
    nl := last;
    nsm := cur;
    DoExpression;
    if Error then
      Exit;
    MemoTo.Add(ttIf + '  ' + CopyArr(nsm, cur - nsm));
    lastp := cur;
    if GetToken = 'DO' then
    begin
      DoCommand;
      MemoTo.Add(ttGoto + Chr(nl) + Chr(nl div 256));
      bs := MemoTo[nl];
      bs[2] := Chr(last);
      bs[3] := Chr(last div 256);
      MemoTo[nl] := bs;
    end
    else
      AddError('����� ��������� "do"');
  end;

  procedure DoGoto;
  var
    nsm: Integer;
  begin
    SkipSpace;
    nsm := cur;
    lastp := cur;
    DoDigit;
    if Error then
      AddError('����� � goto ������ ���� ������');
    MemoTo.Add(ttGoto + Trim(CopyArr(nsm, cur - nsm)));
  end;

  procedure DoEqual;
  var
    S: String;
    n, nsm: Integer;
  begin
    nsm := cur;
    DoVariable;
    S := Trim(CopyArr(nsm, cur - nsm)) + ' ';
    lastp := cur;
    bs := GetToken;
    if (bs = ';') or (bs = '') or (bs = #0) then
    begin
      S := Trim(CopyArr(nsm, lastp - nsm));
      MemoTo.Add(ttProc + S + '(0)');
      cur := lastp;
    end else if Pos(':=', bs) = 1 then
    begin
      cur := cur - Length(bs) + 2;
      nsm := cur;
      DoExpression;
      n := Pos('[', S);
      if n <> 0 then
      begin
        S := ttProc + 'SETARRAY(' + Copy(S, 1, n - 1) + ', ' + Copy(S, n + 1, Length(S) - n - 2) + ', ' +
          CopyArr(nsm, cur - nsm) + ')';
      end
      else
        S := S + CopyArr(nsm, cur - nsm);
      MemoTo.Add(S);
    end
    else
      AddError('����� ��������� ":="');
  end;
  { ------------------------------------- }
  procedure DoExpression;
  var
    nsm: Integer;
  begin
    DoSExpression;
    nsm := cur;
    bs := GetToken;
    if (Pos('>=', bs) = 1) or (Pos('<=', bs) = 1) or (Pos('<>', bs) = 1) then
    begin
      cur := cur - Length(bs) + 2;
      DoSExpression;
    end else if (bs[1] = '>') or (bs[1] = '<') or (bs[1] = '=') then
    begin
      cur := cur - Length(bs) + 1;
      DoSExpression;
    end
    else
      cur := nsm;
  end;

  procedure DoSExpression;
  var
    nsm: Integer;
  begin
    DoTerm;
    nsm := cur;
    bs := GetToken;
    if (bs[1] = '+') or (bs[1] = '-') then
    begin
      cur := cur - Length(bs) + 1;
      DoSExpression;
    end else if Pos('OR', bs) = 1 then
    begin
      cur := cur - Length(bs) + 2;
      DoSExpression;
    end
    else
      cur := nsm;
  end;

  procedure DoTerm;
  var
    nsm: Integer;
  begin
    DoFactor;
    nsm := cur;
    bs := GetToken;
    if (bs[1] = '*') or (bs[1] = '/') then
    begin
      cur := cur - Length(bs) + 1;
      DoTerm;
    end else if (Pos('AND', bs) = 1) or (Pos('MOD', bs) = 1) then
    begin
      cur := cur - Length(bs) + 3;
      DoTerm;
    end
    else
      cur := nsm;
  end;

  procedure DoFactor;
  var
    nsm: Integer;
  begin
    nsm := cur;
    bs := GetToken;
    if bs[1] = '(' then
    begin
      cur := cur - Length(bs) + 1;
      DoExpression;
      SkipSpace;
      lastp := cur;
      if buf^[cur] = ')' then
        Inc(cur)
      else
        AddError('����� ��������� ")"');
    end else if bs[1] = '[' then
    begin
      cur := cur - Length(bs);
      ProcessBrackets(cur);
      SkipSpace;
      lastp := cur;
      if buf^[cur] = ']' then
        Inc(cur)
      else
        AddError('����� ��������� "]"');
    end else if (bs[1] = '+') or (bs[1] = '-') then
    begin
      cur := cur - Length(bs) + 1;
      DoExpression;
    end else if bs = 'NOT' then
    begin
      cur := cur - Length(bs) + 3;
      DoExpression;
    end else begin
      cur := nsm;
      DoVariable;
      if Error then
      begin
        Error := False;
        cur := nsm;
        DoConst;
        if Error then
        begin
          Error := False;
          cur := nsm;
          DoFunc;
        end;
      end;
    end;
  end;

  procedure DoVariable;
  begin
    SkipSpace;
    if CharInset(buf^[cur], ['a' .. 'z', 'A' .. 'Z']) then
    begin
      Inc(cur);
      while CharInset(buf^[cur], ['0' .. '9', '_', '.', 'A' .. 'Z', 'a' .. 'z']) do
        Inc(cur);
      if buf^[cur] = '(' then
        Error := True;
      if buf^[cur] = '[' then
      begin
        Inc(cur);
        DoExpression;
        if buf^[cur] <> ']' then
          Error := True
        else
          Inc(cur);
      end;
    end
    else
      Error := True;
  end;

  procedure DoConst;
  begin
    SkipSpace;
    if buf^[cur] = #$27 then
    begin
      Inc(cur);
      while (buf^[cur] <> #$27) and (cur < len) do
        Inc(cur);
      if cur = len then
        Error := True
      else
        Inc(cur);
    end else begin
      DoDigit;
      if buf^[cur] = '.' then
      begin
        Inc(cur);
        DoDigit;
      end;
    end;
  end;

  procedure DoLabel;
  begin
    DoDigit;
    if buf^[cur] = ':' then
      Inc(cur)
    else
      Error := True;
  end;

  procedure DoFunc;
  label
    1;
  begin
    DoFuncId;
    if buf^[cur] = '(' then
    begin
      Inc(cur);
    1:
      DoExpression;
      lastp := cur;
      SkipSpace;
      if buf^[cur] = ',' then
      begin
        Inc(cur);
        goto 1;
      end else if buf^[cur] = ')' then
        Inc(cur)
      else
        AddError('����� ��������� "," ��� ")"');
    end;
  end;

  procedure DoFuncId;
  label
    1;
  begin
    SkipSpace;
    if CharInset(buf^[cur], ['A' .. 'Z', 'a' .. 'z']) then
      while CharInset(buf^[cur], ['0' .. '9', '_', 'A' .. 'Z', 'a' .. 'z']) do
        Inc(cur)
    else
      Error := True;
  end;

  procedure DoCommand;
  label
    1;
  var
    nsm: Integer;
  begin
  1:
    Error := False;
    nsm := cur;
    lastp := cur;
    bs := GetToken;
    if bs = 'BEGIN' then
      DoBegin
    else
      if bs = 'IF' then
        DoIf
      else
        if bs = 'REPEAT' then
          DoRepeat
        else
          if bs = 'WHILE' then
            DoWhile
          else
            if bs = 'GOTO' then
              DoGoto
            else
              if Pos('END', bs) = 1 then
              begin
                cur := nsm;
                Error := False;
              end else begin
                cur := nsm;
                DoLabel;
                if Error then
                begin
                  Error := False;
                  cur := nsm;
                  DoVariable;
                  if not Error then
                  begin
                    cur := nsm;
                    DoEqual;
                  end else begin
                    cur := nsm;
                    Error := False;
                    DoExpression;
                    MemoTo.Add(ttProc + Trim(CopyArr(nsm, cur - nsm)));
                  end;
                end else begin
                  AddLabel(Trim(CopyArr(nsm, cur - nsm)), last);
                  goto 1;
                end;
              end;
  end;

begin
  Error := False;
  GetMem(buf, 32000 * SizeOf(PWideChar));
  FillChar(buf^, 32000 * SizeOf(PWideChar), 0);
  len := 0;
  for i := 0 to MemoFrom.Count - 1 do
  begin
    S := ' ' + MemoFrom[i];
    if Pos('//', S) <> 0 then
      SetLength(S, Pos('//', S) - 1);
    if Pos('{', S) <> 0 then
      SetLength(S, Pos('{', S) - 1);
    while Pos(#9, S) <> 0 do
      S[Pos(#9, S)] := ' ';
    while Pos('  ', S) <> 0 do
      Delete(S, Pos('  ', S), 1);
    Move(S[1], buf^[len], Length(S) * SizeOf(char));
    Inc(len, Length(S));
  end;
  cur := 0;
  labc := 0;
  MemoTo.Clear;
  MemoErr.Clear;
  if len > 0 then
    DoCommand;
  FreeMem(buf, 32000);
  for i := 0 to MemoTo.Count - 1 do
    if MemoTo[i][1] = ttGoto then
    begin
      S := Remain(MemoTo[i], 2) + ':';
      for j := 0 to labc do
        if CompareText(String(labels[j].Name), S) = 0 then
        begin
          S := MemoTo[i];
          S[2] := Chr(labels[j].n);
          S[3] := Chr(labels[j].n div 256);
          MemoTo[i] := S;
          break;
        end;
    end else if MemoTo[i][1] = ttIf then
    begin
      S := FParser.Str2OPZ(Remain(MemoTo[i], 4));
      MemoTo[i] := Copy(MemoTo[i], 1, 3) + S;
    end else if MemoTo[i][1] = ttProc then
    begin
      S := FParser.Str2OPZ(Remain(MemoTo[i], 2));
      MemoTo[i] := Copy(MemoTo[i], 1, 1) + S;
    end else begin
      j := 1;
      GetIdentify(MemoTo[i], j);
      len := j;
      S := FParser.Str2OPZ(Remain(MemoTo[i], j));
      MemoTo[i] := Copy(MemoTo[i], 1, len) + S;
    end;
end;

procedure TfrInterpretator.DoScript(Memo: TStringList);
var
  i, j: Integer;
  S, s1: String;
begin
  i := 0;
  while i < Memo.Count do
  begin
    S := Memo[i];
    j := 1;
    if S[1] = ttIf then
    begin
      if FParser.CalcOPZ(Remain(S, 4)) = 0 then
      begin
        i := Ord(S[2]) + Ord(S[3]) * 256;
        continue;
      end;
    end else if S[1] = ttGoto then
    begin
      i := Ord(S[2]) + Ord(S[3]) * 256;
      continue;
    end else if S[1] = ttProc then
      FParser.CalcOPZ(Remain(S, 2))
    else
    begin
      s1 := GetIdentify(S, j);
      SetValue(s1, FParser.CalcOPZ(Remain(S, j)));
    end;
    Inc(i);
  end;
end;

procedure TfrInterpretator.GetValue(const Name: String; var Value: Variant);
begin
// abstract method
end;

procedure TfrInterpretator.SetValue(const Name: String; Value: Variant);
begin
// abstract method
end;

procedure TfrInterpretator.DoFunction(const Name: String; p1, p2, p3: Variant; var val: String);
begin
// abstract method
end;

end.
