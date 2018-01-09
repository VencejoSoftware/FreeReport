// FastReport 2.3 demo.
//
// Demonstrates how to create reports with no designer.

unit Unit1;

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls,
  DB,
  FR_DSet, FR_DBSet, FR_Class, FR_E_CSV, FR_E_TXT, FR_E_TNPDF, frexBMP,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client, FR_Desgn, FR_Chart, FR_Shape;

type
  TForm1 = class(TForm)
    Button1: TButton;
    frReport1: TfrReport;
    frDBDataSet1: TfrDBDataSet;
    DataSource1: TDataSource;
    FDMemTable1: TFDMemTable;
    FDMemTable1field1: TIntegerField;
    FDMemTable1field2: TStringField;
    frTextExport1: TfrTextExport;
    frCSVExport1: TfrCSVExport;
    Button2: TButton;
    frDesigner1: TfrDesigner;
    frShapeObject1: TfrShapeObject;
    frChartObject1: TfrChartObject;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}

procedure TForm1.Button1Click(Sender: TObject);
var
// v: TfrView;
// b: TfrBandView;
// Page: TfrPage;
  i: Cardinal;
begin
  FDMemTable1.Open;
  for i := 0 to 100 do
  begin
    FDMemTable1.Append;
    FDMemTable1.FieldByName('field1').AsInteger := i;
    FDMemTable1.FieldByName('field2').AsString := 'field' + IntToStr(i);
    FDMemTable1.Post;
  end;
// frReport1.Pages.Clear;
// frReport1.Pages.Add; // create page
// Page := frReport1.Pages[0];
//
// b := TfrBandView(frCreateObject(gtBand, '')); // create MasterData band
// b.SetBounds(0, 20, 0, 20);
// b.BandType := btMasterData;
// b.DataSet := 'frDBDataSet1';
// Page.Objects.Add(b);
//
// v := frCreateObject(gtMemo, ''); // create data field
// v.SetBounds(20, 20, 200, 16);
// v.Memo.Add('["field1"]');
// Page.Objects.Add(v);
//
// v := frCreateObject(gtMemo, ''); // create data field
// v.SetBounds(100, 20, 200, 16);
// v.Memo.Add('["field2"]');
// Page.Objects.Add(v);

  frReport1.ShowReport;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  frReport1.DesignReport;
end;

end.
