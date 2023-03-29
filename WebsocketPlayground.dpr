program WebsocketPlayground;

uses
  System.StartUpCopy,
  FMX.Forms,
  Skia.FMX,
  UnitWebsocket in 'UnitWebsocket.pas' {MainUnit};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TMainUnit, MainUnit);
  Application.Run;
end.
