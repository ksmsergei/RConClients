object frmAsyncRCon: TfrmAsyncRCon
  Left = 0
  Top = 0
  Caption = 'Async RCon'
  ClientHeight = 442
  ClientWidth = 628
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  DesignSize = (
    628
    442)
  TextHeight = 15
  object lbledtHost: TLabeledEdit
    Left = 8
    Top = 24
    Width = 169
    Height = 23
    EditLabel.Width = 28
    EditLabel.Height = 15
    EditLabel.Caption = 'Host:'
    TabOrder = 0
    Text = ''
  end
  object lbledtPort: TLabeledEdit
    Left = 183
    Top = 24
    Width = 50
    Height = 23
    EditLabel.Width = 25
    EditLabel.Height = 15
    EditLabel.Caption = 'Port:'
    MaxLength = 5
    NumbersOnly = True
    TabOrder = 1
    Text = ''
  end
  object lbledtPassword: TLabeledEdit
    Left = 352
    Top = 24
    Width = 173
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    EditLabel.Width = 53
    EditLabel.Height = 15
    EditLabel.Caption = 'Password:'
    TabOrder = 2
    Text = ''
    ExplicitWidth = 169
  end
  object lbledtCommand: TLabeledEdit
    Left = 8
    Top = 72
    Width = 517
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    EditLabel.Width = 60
    EditLabel.Height = 15
    EditLabel.Caption = 'Command:'
    TabOrder = 3
    Text = ''
    ExplicitWidth = 513
  end
  object btnConnect: TButton
    Left = 239
    Top = 23
    Width = 75
    Height = 25
    Caption = 'Connect'
    TabOrder = 4
    OnClick = btnConnectClick
  end
  object btnAuth: TButton
    Left = 531
    Top = 23
    Width = 89
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Authenticate'
    TabOrder = 5
    OnClick = btnAuthClick
    ExplicitLeft = 527
  end
  object btnExec: TButton
    Left = 531
    Top = 71
    Width = 89
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'Execute'
    TabOrder = 6
    OnClick = btnExecClick
    ExplicitLeft = 527
  end
  object mmoLog: TMemo
    Left = 8
    Top = 112
    Width = 612
    Height = 322
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    TabOrder = 7
    ExplicitWidth = 608
    ExplicitHeight = 321
  end
  object RConAsyncClient: TRConAsyncClient
    ConnectTimeout = 0
    Host = 'localhost'
    Port = 27015
    ReadTimeout = -1
    OnConnected = RConAsyncClientConnected
    OnDisconnected = RConAsyncClientDisconnected
    OnAuthenticated = RConAsyncClientAuthenticated
    OnExceptionCaught = RConAsyncClientExceptionCaught
    OnPacketReceived = RConAsyncClientPacketReceived
    Left = 48
    Top = 120
  end
end
