program Project1;

uses
  Forms,
  Unit1 in 'unit1.PAS' {Form1},
  frexBMP in '..\..\frexbmp\frexBMP.PAS';

{$R *.RES}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;

end.
