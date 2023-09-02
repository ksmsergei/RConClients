program SyncRCon;

uses
  Vcl.Forms,
  main in 'main.pas' {frmSyncRCon};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmSyncRCon, frmSyncRCon);
  Application.Run;
end.
