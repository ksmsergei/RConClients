{**************************************************************************}
{                                                                          }
{ File: RConClients.pas                                                    }
{ Author: Kolevatov Sergey                                                 }
{ GitHub: https://github.com/ksmsergei                                     }
{ Date: 2023-08-28                                                         }
{                                                                          }
{ Description:                                                             }
{ Implementation of sync. and async. RCon clients based on TIdTCPClient.   }
{                                                                          }
{ All information about source RCON is here:                               }
{ https://developer.valvesoftware.com/wiki/Source_RCON_Protocol            }
{                                                                          }
{**************************************************************************}

unit RConClients;

interface

uses
  System.Classes, System.SysUtils, System.Threading, System.Generics.Collections,
  IdTCPClient, IdGlobal, syncobjs, VCL.Dialogs;

const
  RCON_DEFAULT_HOST = 'localhost';
  RCON_DEFAULT_PORT = 27015;
  RCON_DEFAULT_PASSWORD = '';
  RCON_DEFAULT_CONNECT_TIMEOUT = 0;
  RCON_DEFAULT_READ_TIMEOUT = -1;

const
  RCON_MAX_PACKET_SIZE = 4096;

type
  ERconError = class(Exception);

  EArleadyAuthenticated = class(ERconError);

  EArleadyAuthenticating = class(ERconError);

  EArleadyConnected = class(ERconError);

  EArleadyConnecting = class(ERconError);

  EMaxSizeExceeded = class(ERconError);

  ENotAuthenticated = class(ERconError);

  ENotConnected = class(ERconError);

  EUnexpectedPacket = class(ERconError);

  EWrongPassword = class(ERconError);

{
  Packet structure. See:
  https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Basic_Packet_Structure

  Note: there is no packet size and an empty string in the record, since they are needed only
  when reading the packet and do not carry other useful information.
}
type
  TRConPacket = record
    id: Integer;
    packet_type: Integer;
    body: string;
  end;

// Class for sending and receiving RCon requests in synchronous mode
type
  TRConClient = class(TComponent)
  private
    FAuthenticated: Boolean;
    FIdTcpClient: TIdTCPClient;
    FLastSentPacketID: Integer;
    FOnDisconnected: TNotifyEvent;
    FPassword: string;

    function GetConnectTimeout: Integer;
    function GetConnected: Boolean;
    function GetHost: string;
    function GetOnConnected: TNotifyEvent;
    function GetPort: Word;
    function GetReadTimeout: Integer;

    procedure SetConnectTimeout(AConnectTimeout: Integer);
    procedure SetHost(AHost: string);
    procedure SetOnConnected(ANotifyEvent: TNotifyEvent);
    procedure SetPort(APort: Word);
    procedure SetReadTimeout(AReadTimeout: Integer);

    procedure DoOnDisconnected(Sender: TObject);

    // Sending/Receiving basic packets via RCon protocol
    function ReceivePacket(var APacket: TRConPacket): Integer;
    procedure SendPacket(APacket: TRConPacket);
  public
    property Authenticated: Boolean read FAuthenticated;
    property Connected: Boolean read GetConnected;

    procedure Connect; overload; virtual;
    procedure Connect(AHost: string; APort: Integer); overload;
    procedure Disconnect;

    // Prepared RCon requests
    procedure Authenticate; overload; virtual;
    procedure Authenticate(APassword: string); overload;
    function ExecCommand(ACommand: string): string; virtual;
  published
    property ConnectTimeout: Integer read GetConnectTimeout write SetConnectTimeout;
    property Host: string read GetHost write SetHost;
    property Password: string write FPassword;
    property Port: Word read GetPort write SetPort;
    property ReadTimeout: Integer read GetReadTimeout write SetReadTimeout;

    property OnConnected: TNotifyEvent read GetOnConnected write SetOnConnected;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

type
  TAsyncExceptionCaughtEvent = procedure(ASender: TObject; const AException: Exception) of object;

  TAsyncPacketReceivedEvent = procedure(ASender: TObject; const AID: Integer; const AResponse: string) of object;

// Class for sending and receiving RCon requests in asynchronous mode
type
  TRConAsyncClient = class(TRConClient)
  private
    FAuthenticateTask: ITask;
    FConnectTask: ITask;
    FExecCommandTask: ITask;
    FOnAuthenticated: TNotifyEvent;
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FOnExceptionCaught: TAsyncExceptionCaughtEvent;
    FOnPacketReceived: TAsyncPacketReceivedEvent;
    FWaitingRequests: TThreadList<TPair<Integer, string>>;

    procedure DoOnAuthenticated;
    procedure DoOnConnected(Sender: TObject);
    procedure DoOnDisconnected(Sender: TObject);
    procedure DoOnExceptionCaught(AException: Exception);
    procedure DoOnPacketReceived(AID: Integer; AResponse: string);
  public
    // Asynchronous version of normal requests
    procedure Connect; override;
    procedure Authenticate; override;
    function ExecCommand(ACommand: string): Integer; reintroduce;
  published
    property OnAuthenticated: TNotifyEvent read FOnAuthenticated write FOnAuthenticated;
    property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
    property OnExceptionCaught: TAsyncExceptionCaughtEvent read FOnExceptionCaught write FOnExceptionCaught;
    property OnPacketReceived: TAsyncPacketReceivedEvent read FOnPacketReceived write FOnPacketReceived;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

procedure Register;

implementation

{
  Types of packets. See:
  https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Packet_Type
}

const
  SERVERDATA_AUTH = 3;
  SERVERDATA_AUTH_RESPONSE = 2;
  SERVERDATA_EXECCOMMAND = 2;
  SERVERDATA_RESPONSE_VALUE = 0;

const
  ARLEADY_AUTHENTICATED = 'RCon: Client is already authenticated.';
  ARLEADY_AUTHENTICATING = 'RCon: Authentication attempt already in progress.';
  ARLEADY_CONNECTED = 'RCon: Client is already connected.';
  ARLEADY_CONNECTING_MSG = 'RCon: Connection attempt already in progress.';
  MAX_SIZE_EXCEEDED_MSG = 'RCon: Body is too big.';
  NOT_AUTHENTICATED = 'RCon: Client is not authenticated.';
  NOT_CONNECTED_MSG = 'RCon: No connection with RCon server.';
  UNEXPECTED_PACKET_MSG = 'RCON: Received unexpected packet.';
  WRONG_PASSWORD_MSG = 'RCon: Wrong password.';

const
  LAST_BODY = #0#1#0#0;

{ TRconClient }

function TRConClient.GetConnectTimeout: Integer;
begin
  Result := FIdTcpClient.ConnectTimeout;
end;

function TRConClient.GetConnected: Boolean;
begin
  Result := FIdTcpClient.Connected;
end;

function TRConClient.GetHost: string;
begin
  Result := FIdTcpClient.Host;
end;

function TRConClient.GetPort: Word;
begin
  Result := FIdTcpClient.Port;
end;

function TRConClient.GetReadTimeout: Integer;
begin
  Result := FIdTcpClient.ReadTimeout;
end;

procedure TRConClient.SetConnectTimeout(AConnectTimeout: Integer);
begin
  FIdTcpClient.ConnectTimeout := AConnectTimeout;
end;

procedure TRConClient.SetHost(AHost: string);
begin
  FIdTcpClient.Host := AHost;
end;

procedure TRConClient.SetPort(APort: Word);
begin
  FIdTcpClient.Port := APort;
end;

procedure TRConClient.SetReadTimeout(AReadTimeout: Integer);
begin
  FIdTcpClient.ReadTimeout := AReadTimeout;
end;

function TRConClient.GetOnConnected: TNotifyEvent;
begin
  Result := FIdTcpClient.OnConnected;
end;

procedure TRConClient.SetOnConnected(ANotifyEvent: TNotifyEvent);
begin
  FIdTcpClient.OnConnected := ANotifyEvent;
end;

procedure TRConClient.DoOnDisconnected(Sender: TObject);
begin
  FAuthenticated := False;

  if Assigned(OnDisconnected) then
    OnDisconnected(Self);
end;

function TRConClient.ReceivePacket(var APacket: TRConPacket): Integer;
var
  LSize: Integer;
begin
  if not Connected then
    raise ENotConnected.Create(NOT_CONNECTED_MSG);

  try
    // See: Packet structure.
    LSize := FIdTcpClient.IOHandler.ReadInt32(False);
    APacket.id := FIdTcpClient.IOHandler.ReadInt32(False);
    APacket.packet_type := FIdTcpClient.IOHandler.ReadInt32(False);
    APacket.body := FIdTcpClient.IOHandler.ReadString(LSize - 10, IndyTextEncoding_ASCII);

    // Discard body terminator and empty string.
    FIdTcpClient.IOHandler.Discard(2);

    Result := APacket.id;
  except
    FIdTcpClient.IOHandler.InputBuffer.Clear;
    FIdTcpClient.Disconnect;
    raise;
  end;
end;

procedure TRConClient.SendPacket(APacket: TRConPacket);
begin
  if not Connected then
    raise ENotConnected.Create(NOT_CONNECTED_MSG);

  {
    Apart from the body, the package size is fixed, so to find out the package size,
    you need to add 10 to the body size. See:
    https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Packet_Size
  }

  if Length(APacket.body) + 10 > RCON_MAX_PACKET_SIZE then
    raise EMaxSizeExceeded.Create(MAX_SIZE_EXCEEDED_MSG);

  FIdTcpClient.IOHandler.WriteBufferOpen;
  try
    // See: Packet structure
    FIdTcpClient.IOHandler.Write(Int32(Length(APacket.body) + 10), False);
    FIdTcpClient.IOHandler.Write(Int32(APacket.id), False);
    FIdTcpClient.IOHandler.Write(Int32(APacket.packet_type), False);
    FIdTcpClient.IOHandler.Write(IndyTextEncoding_ASCII.GetBytes(APacket.body + #0));
    FIdTcpClient.IOHandler.Write(#0);
    FIdTcpClient.IOHandler.WriteBufferClose;
  except
    FIdTcpClient.IOHandler.WriteBufferCancel;
    FIdTcpClient.IOHandler.InputBuffer.Clear;
    FIdTcpClient.Disconnect;
    raise;
  end;

end;

constructor TRConClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FIdTcpClient := TIdTCPClient.Create(nil);
  FIdTcpClient.OnDisconnected := DoOnDisconnected;

  ConnectTimeout := RCON_DEFAULT_CONNECT_TIMEOUT;
  FAuthenticated := False;
  FLastSentPacketID := -1;
  FPassword := RCON_DEFAULT_PASSWORD;
  Host := RCON_DEFAULT_HOST;
  Port := RCON_DEFAULT_PORT;
  ReadTimeout := RCON_DEFAULT_READ_TIMEOUT;
end;

destructor TRConClient.Destroy;
begin
  FIdTcpClient.Free;

  inherited;
end;

procedure TRConClient.Connect;
begin
  if Connected then
    raise EArleadyConnected.Create(ARLEADY_CONNECTED);

  FIdTcpClient.Connect;
end;

procedure TRConClient.Connect(AHost: string; APort: Integer);
begin
  Host := AHost;
  Port := APort;

  Connect;
end;

procedure TRConClient.Disconnect;
begin
  FIdTcpClient.Disconnect;
end;

procedure TRConClient.Authenticate;
var
  LPacket: TRConPacket;
begin
  if not Connected then
    raise ENotConnected.Create(NOT_CONNECTED_MSG);

  if Authenticated then
    raise EArleadyAuthenticated.Create(ARLEADY_AUTHENTICATED);

  Inc(FLastSentPacketID);
  LPacket.id := FLastSentPacketID;
  LPacket.packet_type := SERVERDATA_AUTH;
  LPacket.body := FPassword;
  SendPacket(LPacket);

  {
    When sending an authorization request, 2 responses are received:
    SERVERDATA_RESPONSE_VALUE, and then SERVERDATA_AUTH_RESPONSE.
    If authorization failed, the second packet will contain an ID equal to -1

    See: https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#SERVERDATA_AUTH_RESPONSE
  }

  ReceivePacket(LPacket);
  if (LPacket.packet_type <> SERVERDATA_RESPONSE_VALUE) or (LPacket.id <> FLastSentPacketID) then
    raise EUnexpectedPacket.Create(UNEXPECTED_PACKET_MSG);

  ReceivePacket(LPacket);
  if LPacket.packet_type <> SERVERDATA_AUTH_RESPONSE then
    raise EUnexpectedPacket.Create(UNEXPECTED_PACKET_MSG);

  if LPacket.id = -1 then
    raise EWrongPassword.Create(WRONG_PASSWORD_MSG)
  else if LPacket.id <> FLastSentPacketID then
    raise EUnexpectedPacket.Create(UNEXPECTED_PACKET_MSG);

  FAuthenticated := True;
end;

procedure TRConClient.Authenticate(APassword: string);
begin
  Password := APassword;

  Authenticate;
end;

function TRConClient.ExecCommand(ACommand: string): string;
var
  LPacket: TRConPacket;
  LResponse: string;
begin
  if not Connected then
    raise ENotConnected.Create(NOT_CONNECTED_MSG);

  if not Authenticated then
    raise ENotAuthenticated.Create(NOT_AUTHENTICATED);

  Inc(FLastSentPacketID);
  LPacket.id := FLastSentPacketID;
  LPacket.packet_type := SERVERDATA_EXECCOMMAND;
  LPacket.body := ACommand;

  SendPacket(LPacket);

  {
    Here I use a method to read multiple-packet responses.
    See: https://developer.valvesoftware.com/wiki/Source_RCON_Protocol#Multiple-packet_Responses

    In short, after the SERVERDATA_EXECCOMMAND request, I send an empty packet of the SERVERDATA_RESPONSE_VALUE type,
    then I read the packets until the packet body contains 0x0000 0001 0000 0000.
    After that, I just concatenate the contents of all the past packages into one string.
  }

  LPacket.packet_type := SERVERDATA_RESPONSE_VALUE;
  LPacket.body := '';

  SendPacket(LPacket);

  LResponse := '';
  ReceivePacket(LPacket);

  while LPacket.body <> LAST_BODY do
  begin
    if (LPacket.packet_type <> SERVERDATA_RESPONSE_VALUE) or (LPacket.id <> FLastSentPacketID) then
      raise EUnexpectedPacket.Create(UNEXPECTED_PACKET_MSG);

    LResponse := LResponse + LPacket.body;
    ReceivePacket(LPacket);
  end;

  if (LPacket.packet_type <> SERVERDATA_RESPONSE_VALUE) or (LPacket.id <> FLastSentPacketID) then
    raise EUnexpectedPacket.Create(UNEXPECTED_PACKET_MSG);

  Result := LResponse;
end;

{ TRconAsync }

{
  Although events are called from different threads, they are processed in the
  main thread, so that they can safely access VCL components and global variables.
}
procedure TRConAsyncClient.DoOnAuthenticated;
begin
  TThread.Synchronize(nil,
    procedure
    begin
      if Assigned(OnAuthenticated) then
        OnAuthenticated(Self);
    end);
end;

procedure TRConAsyncClient.DoOnConnected(Sender: TObject);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      if Assigned(OnConnected) then
        OnConnected(Self);
    end);
end;

procedure TRConAsyncClient.DoOnDisconnected(Sender: TObject);
begin
  FAuthenticated := False;
  FWaitingRequests.Clear;

  TThread.Synchronize(nil,
    procedure
    begin
      if Assigned(OnDisconnected) then
        OnDisconnected(Self);
    end);
end;

procedure TRConAsyncClient.DoOnExceptionCaught(AException: Exception);
begin
  {
    I call Queue to be able to raise an exception from the main thread, and then
    I call an empty Syncronize to wait for the execution of the code inside the Queue.

    When using Synchronize instead of Queue, if an exception is
    raised in the OnExceptionCaught event, it will not be handled
    by the main thread, causing a lot of bugs.
  }

  TThread.Queue(nil,
    procedure
    begin
      {
        If the AException was re-raised in the OnExceptionCaught event,
        then do not release its memory - it will be done automatically.
      }
      try
        if Assigned(OnExceptionCaught) then
          OnExceptionCaught(Self, AException);

        AException.Free;
      except
        on E: Exception do
        begin
          if E <> AException then
            AException.Free;

          raise;
        end;
      end;
    end);

  TThread.Synchronize(nil, nil);
end;

procedure TRConAsyncClient.DoOnPacketReceived(AID: Integer; AResponse: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      if Assigned(OnPacketReceived) then
        OnPacketReceived(Self, AID, AResponse);
    end);
end;

constructor TRConAsyncClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FIdTcpClient.OnConnected := DoOnConnected;
  FIdTcpClient.OnDisconnected := DoOnDisconnected;

  FWaitingRequests := TThreadList<TPair<Integer, string>>.Create;
  FWaitingRequests.Duplicates := TDuplicates.dupAccept;
end;

destructor TRConAsyncClient.Destroy;

  procedure MyWaitForTask(var ATask: ITask); inline;
  begin
    while Assigned(ATask) do
      if not ATask.Wait(500) then
        CheckSynchronize;
  end;

begin
  try
    FIdTcpClient.IOHandler.Close;
  except
    //Ignore
  end;

  MyWaitForTask(FConnectTask);
  MyWaitForTask(FAuthenticateTask);
  MyWaitForTask(FExecCommandTask);

  FWaitingRequests.Free;
  inherited;
end;

procedure TRConAsyncClient.Connect;
begin
  if Connected then
    raise EArleadyConnected.Create(ARLEADY_CONNECTED);

  if Assigned(FConnectTask) then
    raise EArleadyConnecting.Create(ARLEADY_CONNECTING_MSG);

  FConnectTask := TTask.Run(
    procedure()
    begin
      try
        try
          FIdTcpClient.Connect;
        except
          {
            Call AcquireExceptionObject so that the exception memory is not automatically
            released and the OnExceptionCaught event can work with it.
          }
          DoOnExceptionCaught(AcquireExceptionObject as Exception);
        end;
      finally
        FConnectTask := nil;
      end;
    end);
end;

procedure TRConAsyncClient.Authenticate;
begin
  if not Connected then
    raise ENotConnected.Create(NOT_CONNECTED_MSG);

  if Authenticated then
    raise EArleadyAuthenticated.Create(ARLEADY_AUTHENTICATED);

  if Assigned(FAuthenticateTask) then
    raise EArleadyAuthenticating.Create(ARLEADY_AUTHENTICATING);

  FAuthenticateTask := TTask.Run(
    procedure()
    begin
      try
        try
          inherited;
          DoOnAuthenticated;
        except
          DoOnExceptionCaught(Exception(AcquireExceptionObject));
        end;
      finally
        FAuthenticateTask := nil;
      end;
    end);
end;

function TRConAsyncClient.ExecCommand(ACommand: string): Integer;
begin
  if not Connected then
    raise ENotConnected.Create(NOT_CONNECTED_MSG);

  if not Authenticated then
    raise ENotAuthenticated.Create(NOT_AUTHENTICATED);

  Inc(FLastSentPacketID);
  Result := FLastSentPacketID;

  // Add a request to the end of the queue
  FWaitingRequests.Add(TPair<Integer, string>.Create(FLastSentPacketID, ACommand));

  if Assigned(FExecCommandTask) then
    exit;

  FExecCommandTask := TTask.Run(
    procedure
    var
      LPacket: TRConPacket;
      LResponse: string;
      LReceivedParts: TDictionary<Integer, string>;
      LWaitingRequests: TList<TPair<Integer, string>>;
    begin
      LReceivedParts := TDictionary<Integer, string>.Create;
      try
        {
          As long as there is something to send and something to read,
          I will send and receive a package in turn, and so on.
        }
        while True do
        try
          // Sending Part
          LWaitingRequests := FWaitingRequests.LockList;
          try
            if (LWaitingRequests.Count = 0) and (LReceivedParts.Count = 0) then
              Break;

            if LWaitingRequests.Count > 0 then
            begin
              LPacket.id := LWaitingRequests.First.Key;
              LPacket.body := LWaitingRequests.First.Value;
              LWaitingRequests.Delete(0);

              LPacket.packet_type := SERVERDATA_EXECCOMMAND;
              SendPacket(LPacket);

              LPacket.packet_type := SERVERDATA_RESPONSE_VALUE;
              LPacket.body := '';
              SendPacket(LPacket);

              LReceivedParts.Add(LPacket.id, '');
            end;
          finally
            FWaitingRequests.UnlockList;
          end;

          // Receiving Part
          ReceivePacket(LPacket);

          if not LReceivedParts.ContainsKey(LPacket.id) then
            raise EUnexpectedPacket.Create(UNEXPECTED_PACKET_MSG);

          if LPacket.body <> LAST_BODY then
          begin
            LReceivedParts.Items[LPacket.id] := LReceivedParts.Items[LPacket.id] + LPacket.body;
          end
          else
          begin
            //Remove the last line break character from the response
            LResponse := LReceivedParts.Items[LPacket.id];
            SetLength(LResponse, Length(LResponse) - 1);

            DoOnPacketReceived(LPacket.id, LResponse);
            LReceivedParts.Remove(LPacket.id);
          end;
        except
          FWaitingRequests.Clear;
          DoOnExceptionCaught(Exception(AcquireExceptionObject));
          Break;
        end;
      finally
        LReceivedParts.Free;
        FExecCommandTask := nil;
      end;
    end);
end;

procedure Register;
begin
  RegisterComponents('RCon', [TRConClient, TRConAsyncClient]);
end;

end.

