unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Mask, Vcl.ExtCtrls, RConClients;

type
  TfrmAsyncRCon = class(TForm)
    lbledtHost: TLabeledEdit;
    lbledtPort: TLabeledEdit;
    lbledtPassword: TLabeledEdit;
    lbledtCommand: TLabeledEdit;
    btnConnect: TButton;
    btnAuth: TButton;
    btnExec: TButton;
    mmoLog: TMemo;
    RConAsyncClient: TRConAsyncClient;

    procedure wmGetMinMaxInfo(var Msg: TMessage); message wm_GetMinMaxInfo;
    procedure FormCreate(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnAuthClick(Sender: TObject);
    procedure btnExecClick(Sender: TObject);
    procedure RConAsyncClientExceptionCaught(ASender: TObject; const AException: Exception);
    procedure RConAsyncClientPacketReceived(ASender: TObject; const AID: Integer; const AResponse: string);
    procedure RConAsyncClientDisconnected(Sender: TObject);
    procedure RConAsyncClientConnected(Sender: TObject);
    procedure RConAsyncClientAuthenticated(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmAsyncRCon: TfrmAsyncRCon;

implementation

{$R *.dfm}

{ TfrmSyncRCon }

procedure TfrmAsyncRCon.btnAuthClick(Sender: TObject);
begin
  RConAsyncClient.Password := lbledtPassword.Text;
  RConAsyncClient.Authenticate;
end;

procedure TfrmAsyncRCon.btnConnectClick(Sender: TObject);
begin
  if btnConnect.Tag = 0 then
  begin
    RConAsyncClient.Host := lbledtHost.Text;
    RConAsyncClient.Port := StrToInt(lbledtPort.Text);

    RConAsyncClient.Connect;
  end
  else
  begin
    RConAsyncClient.Disconnect;
  end;
end;

procedure TfrmAsyncRCon.btnExecClick(Sender: TObject);
begin
  mmoLog.Lines.Add('>' + lbledtCommand.Text);

  RConAsyncClient.ExecCommand(lbledtCommand.Text);
end;

procedure TfrmAsyncRCon.FormCreate(Sender: TObject);
begin
  lbledtHost.Text := RConAsyncClient.Host;
  lbledtPort.Text := RConAsyncClient.Port.ToString;
end;

procedure TfrmAsyncRCon.RConAsyncClientAuthenticated(Sender: TObject);
begin
  mmoLog.Lines.Add('[RCon] Authenticated.');
end;

procedure TfrmAsyncRCon.RConAsyncClientConnected(Sender: TObject);
begin
  btnConnect.Tag := 1;
  btnConnect.Caption := 'Disconnect';

  mmoLog.Clear;
  mmoLog.Lines.Add('[RCon] Connected.');
end;

procedure TfrmAsyncRCon.RConAsyncClientDisconnected(Sender: TObject);
begin
  btnConnect.Tag := 0;
  btnConnect.Caption := 'Connect';

  mmoLog.Lines.Add('[RCon] Disconnected.');
end;

procedure TfrmAsyncRCon.RConAsyncClientExceptionCaught(ASender: TObject; const AException: Exception);
begin
  raise AException;
end;

procedure TfrmAsyncRCon.RConAsyncClientPacketReceived(ASender: TObject; const AID: Integer; const AResponse: string);
begin
  mmoLog.Lines.Add(AResponse);
end;

//Set limit for form width
procedure TfrmAsyncRCon.wmGetMinMaxInfo(var Msg: TMessage);
begin
  PMinMaxInfo(Msg.lParam)^.ptMinTrackSize.X := 640;
end;

end.

