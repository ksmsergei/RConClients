# RConClients
In this library, there are 2 components for convenient receiving and sending of Source RCon requests:
- **TRConClient** - Synchronous requests that will block the program until the task is completed.
- **TRConAsyncClient** - Asynchronous operations won't block the program, and there are specific events to retrieve the results.

# Installation
Simply download all the files and open **RConClients.dproj**. In the right-hand side of the IDE, you should see **RConClients.bpl**. Right-click on it and select "**Install**". If everything went without errors, you should be able to find the new components in the **RConClients** palette. Also, don't forget to add the path to the components in your IDE's **Library path**.

# Usage
## TRConClient
### Connecting
Just drag the component onto the form or create it at runtime. To connect to the RCon server, do the following:
```delphi
RConClient.Host := 'localhost';
RConClient.Port := 27015;
RConClient.Connect;
```
or just:
```delphi
RConClient.Connect('localhost', 27015);
```
By the way, the host and port, if not specified, will be the same as mentioned above by default.

### Authenticating
After you have successfully connected, before sending commands, you need to authenticate:
```delphi
RConClient.Password := 'password';
RConClient.Authenticate;
```
or:
```delphi
RConClient.Authenticate('password');
```
There is no default password, and furthermore, if no password is set on the RCon server as well, it will be impossible to connect to it.

Also, please note that a large number of unsuccessful authentication attempts, as well as attempts to send commands without being authenticated, can lead to an IP ban from the RCon server.

### Executing commands
After successful connection and authentication, you can send requests for commands:
```delphi
var
  LAnswer: string;

...

LAnswer := RConClient.ExecCommand('echo test');
ShowMessage('Answer: ' + LAnswer); // Answer: test
```
Note that not all commands return a response. In such cases, the function will return an empty string.

### Additional settings
You can set a timeout for connection and command retrieval. Just set the desired value (in milliseconds) for the component properties **ConnectTimeout** and **ReadTimeout**:
```delphi
  RConClient.ConnectTimeout := 1000;
  RConClient.ReadTimeout := 1000;
```
Please note that even if you set the value to 0 or a negative number, the wait won't be infinite because there is a limit of around 2 minutes.

## TRConAsyncClient
Everything shown above is applicable to this component as well, but keep in mind a few things:
### Executing commands

Instead of returning the result, the **ExecCommand** function now returns the ID of the request just sent:
```delphi
var
  LID: Integer;

...

LID := RConAsyncClient.ExecCommand('echo test');
```
Later, you can compare it in the **OnPacketReceived** event, which will be explained below.

### Events
Keep in mind that you need to handle the results of the requests in separate events, as the code is executed asynchronously:
- OnAuthenticated
- OnConnected
- OnDisconnected
- OnExceptionCaught
- OnPacketReceived

The names of these events are self-explanatory, but I'll still explain some of them.

#### OnExceptionCaught
This event is only triggered when an exception has been raised in another thread. So, if the exception was raised before the thread was started, you can handle it as usual. The parameter AException of the event is the raised exception itself.  In the simplest case, you can re-raise the exception, but this time in the main thread:
```delphi
procedure TfrmAsyncRCon.OnExceptionCaught(ASender: TObject; const AException: Exception);
begin
  raise AException;
end;
```

#### OnPacketReceived
The event is triggered when a response is received for a previously sent request. The parameter AID points to the ID, matching the ID of the earlier sent request. The AResponse parameter is the response itself. You can use the event like this:
```delphi
procedure TfrmAsyncRCon.OnPacketReceived(ASender: TObject; const AID: Integer; const AResponse: string);
begin
  ShowMessage('ID: ' + AID.ToString + sLineBreak + 'Response: ' + AResponse);
end;
```

# Examples
Two examples come with the component in the **Examples** folder: **Async** and **Sync**. Both projects demonstrate the basic capabilities of these components. To compile them, you need to install the components beforehand.
