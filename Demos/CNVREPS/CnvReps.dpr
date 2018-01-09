program CnvReps;

uses
  Forms,
  MainF in 'MainF.pas' {Form1},
  FR_E_TNPDF in '..\..\frexppdf\FR_E_TNPDF.PAS';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
