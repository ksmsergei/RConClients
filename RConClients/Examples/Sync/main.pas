unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Mask, Vcl.ExtCtrls, RConClients;

type
  TfrmSyncRCon = class(TForm)
    lbledtHost: TLabeledEdit;
    lbledtPort: TLabeledEdit;
    lbledtPassword: TLabeledEdit;
    lbledtCommand: TLabeledEdit;
    btnConnect: TButton;
    btnAuth: TButton;
    btnExec: TButton;
    mmoLog: TMemo;
    RConSyncClient: TRConClient;

    procedure wmGetMinMaxInfo(var Msg: TMessage); message wm_GetMinMaxInfo;
    procedure FormCreate(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure RConSyncClientConnected(Sender: TObject);
    procedure RConSyncClientDisconnected(Sender: TObject);
    procedure btnAuthClick(Sender: TObject);
    procedure btnExecClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmSyncRCon: TfrmSyncRCon;

implementation

{$R *.dfm}

{ TfrmSyncRCon }

procedure TfrmSyncRCon.btnAuthClick(Sender: TObject);
begin
  RConSyncClient.Password := lbledtPassword.Text;
  RConSyncClient.Authenticate;

  mmoLog.Lines.Add('[RCon] Authenticated.');
end;

procedure TfrmSyncRCon.btnConnectClick(Sender: TObject);
begin
  if btnConnect.Tag = 0 then
  begin
    RConSyncClient.Host := lbledtHost.Text;
    RConSyncClient.Port := StrToInt(lbledtPort.Text);

    RConSyncClient.Connect;
  end
  else
  begin
    RConSyncClient.Disconnect;
  end;
end;

procedure TfrmSyncRCon.btnExecClick(Sender: TObject);
var
  LResponse: string;
begin
  mmoLog.Lines.Add('>' + lbledtCommand.Text);

  LResponse := RConSyncClient.ExecCommand(lbledtCommand.Text);
  mmoLog.Lines.Add(LResponse);
end;

procedure TfrmSyncRCon.FormCreate(Sender: TObject);
begin
  lbledtHost.Text := RConSyncClient.Host;
  lbledtPort.Text := RConSyncClient.Port.ToString;
end;

procedure TfrmSyncRCon.RConSyncClientConnected(Sender: TObject);
begin
  btnConnect.Tag := 1;
  btnConnect.Caption := 'Disconnect';

  mmoLog.Clear;
  mmoLog.Lines.Add('[RCon] Connected.');
end;

procedure TfrmSyncRCon.RConSyncClientDisconnected(Sender: TObject);
begin
  btnConnect.Tag := 0;
  btnConnect.Caption := 'Connect';

  mmoLog.Lines.Add('[RCon] Disconnected.');
end;

//Set limit for form width
procedure TfrmSyncRCon.wmGetMinMaxInfo(var Msg: TMessage);
begin
  PMinMaxInfo(Msg.lParam)^.ptMinTrackSize.X := 640;
end;

end.

