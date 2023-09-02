program AsyncRCon;

uses
  Vcl.Forms,
  main in 'main.pas' {frmAsyncRCon};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmAsyncRCon, frmAsyncRCon);
  Application.Run;
end.
