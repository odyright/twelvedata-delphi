unit UnitWebsocket;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Rtti, System.Math, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Memo.Types, Skia.FMX, FMX.ScrollBox, FMX.Memo, System.IOUtils, Bird.Socket.Client,
  FMX.WebBrowser, System.Threading, System.Net.HttpClientComponent,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  FMX.ListView, System.NetEncoding, System.JSON.Types, System.Generics.Collections,
  System.JSON.Builders, System.JSON.Readers;

const
   API   = 'wss://ws.twelvedata.com/v1/quotes/price?apikey=ac88548045e5404f9bf092dc3cd5ea25';
//   API_1 = 'https://api.twelvedata.com/time_series?symbol=ETH/BTC,BTC/USD&interval=1day&outputsize=1&apikey=ac88548045e5404f9bf092dc3cd5ea25';
   API_1 = 'https://api.twelvedata.com/time_series?symbol=ETH/BTC,BTC/USD&interval=1day&outputsize=1&apikey=demo&source=docs';
//   API_2 ='https://api.twelvedata.com/time_series?symbol=EUR/USD, BTC/USD&interval=1min&outputsize=1&format=JSON&timezone=Africa/Abidjan&previous_close=true&apikey=ac88548045e5404f9bf092dc3cd5ea25';

type
  TMainUnit = class(TForm)
    Rectangle1: TRectangle;
    GridPanelLayout1: TGridPanelLayout;
    GridPanelLayout2: TGridPanelLayout;
    GridPanelLayout3: TGridPanelLayout;
    Connection: TLabel;
    OpenConnection: TCornerButton;
    CloseConnection: TCornerButton;
    Messages: TLabel;
    Subscribe: TCornerButton;
    Unsubscribe: TCornerButton;
    Reset: TCornerButton;
    Layout1: TLayout;
    Memo1: TMemo;
    Send: TCornerButton;
    Timer1: TTimer;
    GridPanelLayout4: TGridPanelLayout;
    GridPanelLayout5: TGridPanelLayout;
    Price: TLabel;
    Layout2: TLayout;
    DisplayMemo: TMemo;
    Splitter1: TSplitter;
    Beautify: TCornerButton;
    FlowLayoutPrices: TFlowLayout;
    Memo2: TMemo;
    procedure SubscribeClick(Sender: TObject);
    procedure UnsubscribeClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure SendClick(Sender: TObject);
    procedure CloseConnectionClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OpenConnectionClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Déclarations privées }
    FBirdSocket: TBirdSocketClient;
    FRect: TRectangle;
    FGridP: TGridPanelLayout;
    LSymbolLabel, LPriceLabel, LPercLabel, LDiffLabel: TLabel;
    LSymbol, LSymb: string;
    OpenValueString: String;
    LPrice, FOpenValue: Double;
    FRequest: TNetHTTPRequest;
    FResponse: TMemoryStream;
    FContent: TStringList;
    FSymbolLabels: TDictionary<string, TLabel>;
    FPercentLabels: TDictionary<string, TLabel>;
    FDifferenceLabels: TDictionary<string, TLabel>;
    FOpenValues: TDictionary<String, Double>;
    procedure StartCourcesFuture(iText: String);
    procedure Display(Msg : String);
    procedure Timer1Timer(Sender: TObject);
    procedure AuxPrice;
    function GetJSONIterator(const URL: string): TJSONIterator;
    procedure CreateSymbolUI(NObjJSON: Integer; const Symbol: String);
    function UpdatePriceLabel(const Symbol: String; Price: Double; OpenPrice: Double): TLabel;
  public
    { Déclarations publiques }
    property OpenValue: Double read FOpenValue write FOpenValue;
  end;

var
  MainUnit: TMainUnit;

implementation

{$R *.fmx}


{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Display a message in our display memo. Delete lines to be sure to not     }
{ overflow the memo which may have a limited capacity.                      }
procedure TMainUnit.Display(Msg : String);
var
  I : Integer;
begin
  DisplayMemo.Lines.BeginUpdate;
  try
    if DisplayMemo.Lines.Count > 200 then begin
      for I := 1 to 50 do
        DisplayMemo.Lines.Delete(0);
    end;
    DisplayMemo.Lines.Add(Format('%s <== %s', [FormatDateTime('dd/mm/yyyy hh:mm:ss', Now), Msg + sLineBreak]));
  finally
    DisplayMemo.Lines.EndUpdate;
    DisplayMemo.GoToTextEnd;
  end;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
{ Cette fonction renvoie un TJSONIterator à partir d'une URL                }
function TMainUnit.GetJSONIterator(const URL: string): TJSONIterator;
var
  StringReader: TStringReader;
  TextReader: TJsonTextReader;
begin
  FRequest := TNetHTTPRequest.Create(nil);
  FResponse := TMemoryStream.Create;
  FContent := TStringList.Create;
  try
    FRequest.Client := TNetHTTPClient.Create(FRequest);
    FResponse.Clear;
    FRequest.Get(URL, FResponse);
    FContent.LoadFromStream(FResponse, TEncoding.UTF8);
    StringReader := TStringReader.Create(FContent.Text);
    TextReader := TJsonTextReader.Create(StringReader);
    Result := TJSONIterator.Create(TextReader);
  finally
    FreeAndNil(FContent);
    FreeAndNil(FResponse);
    FreeAndNil(FRequest);
  end;
end;

procedure TMainUnit.AuxPrice;
var
  Iterator: TJSONIterator;
//  CustomFormatSettings: TFormatSettings;
begin
//  CustomFormatSettings := TFormatSettings.Create;
//  CustomFormatSettings.DecimalSeparator := '.';
  Iterator := GetJSONIterator(API_1); // appel de la fonction qui renvoie un TJSONIterator

  var NObj := Iterator.AsInteger;
  try
    while True do
    begin
      while Iterator.Next do // boucle while sur le TJSONIterator
      begin
        if Iterator.&Type in [TJsonToken.StartObject, TJsonToken.StartArray] then // si l'élément est un objet ou un tableau JSON, on entre dedans avec Recurse
        begin
          if (Iterator.Depth = 1) then // si on est au premier niveau de profondeur, on récupère le symbole comme clé
            LSymb := Iterator.Key;
          Memo2.Lines.Add(Iterator.Key);
          Iterator.Recurse;
        end
        else if (Iterator.Path = LSymb+'.values['+NObj.ToString+'].open') then // si on est au chemin qui correspond à la valeur d'ouverture du symbole, on l'affiche
        begin
          OpenValueString := Iterator.AsString;
          OpenValueString := StringReplace(OpenValueString, '.', FormatSettings.DecimalSeparator, [rfReplaceAll]);
          FOpenValue := StrToCurr(OpenValueString);
          FOpenValues.AddOrSetValue(LSymb, FOpenValue);                         // add FOpenValue to the FOpenValues dictionary
          Memo2.Lines.Add(OpenValueString + sLineBreak);
        end;
      end;
      if Iterator.InRecurse then
        Iterator.Return
      else
        Break;
    end;
 finally
   FreeAndNil(Iterator);
 end;
end;

procedure TMainUnit.CreateSymbolUI(NObjJSON: Integer; const Symbol: String);
begin
  // Create and setup the UI elements for the given symbol and NObjJSON here
  var i: integer;
  // create the rectangle control
  FRect := TRectangle.Create(Self);
  with FRect do
  begin
    Parent := FlowLayoutPrices;
    Align := TAlignLayout.Top;
    Visible := True;
    Name := 'FTick' + IntToStr(NObjJSON);
    Fill.Color := TAlphaColorRec.White;
    Margins.Rect := TRectF.Create(1, 1, 1, 1);
    Stroke.Color := $FFE5E4E3;
    Stroke.Thickness := 0.7;
    Height := 40;
    Width := 191;
    XRadius := 7;
    YRadius := 7;
  end;
  // create the GridPanelLayout control
  FGridP := TGridPanelLayout.Create(Self);
  with FGridP do
  begin
    Parent := FRect;
    Align := TAlignLayout.Client;
    Margins.Left := 3;

    RowCollection.BeginUpdate;
    ColumnCollection.BeginUpdate;

    ControlCollection.Clear;
    RowCollection.Clear;
    ColumnCollection.Clear;
    try
      if FGridP.ControlsCount >= NObjJSON then
      begin
        for i := NObjJSON to FGridP.ControlsCount - 1 do
        begin
          if Assigned(FGridP.ControlCollection.Controls[i, 0]) then
            FGridP.ControlCollection.Controls[i, 0].DisposeOf;
        end;
      end;
      for i := 1 to 2 do
        with FGridP.RowCollection.Add do
        begin
          SizeStyle := TGridPanelLayout.TSizeStyle.Percent;
          Value := 100 / 2; //have cells evenly distributed
        end;
      for i := 1 to 2 do
        with FGridP.ColumnCollection.Add do
        begin
          SizeStyle := TGridPanelLayout.TSizeStyle.Percent;
        end;
        // Specify the column values
        FGridP.ColumnCollection[0].Value := 60;
        FGridP.ColumnCollection[1].Value := 40;
    finally
      FGridP.RowCollection.EndUpdate;
      FGridP.ColumnCollection.EndUpdate;
    end;
  end;
  // Display the symbol information
  LSymbolLabel := TLabel.Create(Self);
  with LSymbolLabel do
  begin
    Parent := FGridP;
    Align :=  TAlignLayout.Client;
    AutoSize :=  true;
    Margins.Right := 3;
    Margins.Left := 3;
    Margins.Top := 3;
    Margins.Bottom := 3;
    StyledSettings := StyledSettings - [TStyledSetting.Style];
    TextSettings.Font.Style := TextSettings.Font.Style + [TFontStyle.fsBold];
    Text := Symbol;
  end;
  // Display the Perc information
  LPercLabel := TLabel.Create(Self);
  with LPercLabel do
  begin
    Parent := FGridP;
    Align :=  TAlignLayout.Client;
    AutoSize :=  true;
    Margins.Right := 3;
    Margins.Left := 3;
    Margins.Top := 3;
    Margins.Bottom := 3;
    Name := 'FPerc' + IntToStr(NObjJSON);
    FPercentLabels.Add(LSymbolLabel.Text, LPercLabel);                  // Store the percentage-label pair in the dictionary
    StyledSettings := StyledSettings - [TStyledSetting.Style];
//    Text := '0.00';
  end;
  // Display the Current price information
  LPriceLabel := TLabel.Create(Self);
  with LPriceLabel do
  begin
    Parent := FGridP;
    Align :=  TAlignLayout.Client;
    AutoSize :=  true;
    Margins.Right := 3;
    Margins.Left := 3;
    Margins.Top := 3;
    Margins.Bottom := 3;
    Name := 'FPrice' + IntToStr(NObjJSON);
    FSymbolLabels.Add(LSymbolLabel.Text, LPriceLabel);                  // Store the symbol-label pair in the dictionary
    StyledSettings := StyledSettings - [TStyledSetting.Style];
  end;
  // Display the Diff information
  LDiffLabel := TLabel.Create(Self);
  with LDiffLabel do
  begin
    Parent := FGridP;
    Align :=  TAlignLayout.Client;
    AutoSize :=  true;
    Margins.Right := 3;
    Margins.Left := 3;
    Margins.Top := 3;
    Margins.Bottom := 3;
    Name := 'FDIff' + IntToStr(NObjJSON);
    FDifferenceLabels.Add(LSymbolLabel.Text, LDiffLabel);                  // Store the difference-label pair in the dictionary
    StyledSettings := StyledSettings - [TStyledSetting.Style];
//    Text := '0.00';
  end;
  // Add the labels to the grid panel layout
  FGridP.ControlCollection.AddControl(LSymbolLabel, 0, 0);
  FGridP.ControlCollection.AddControl(LPercLabel, 0, 1);
  FGridP.ControlCollection.AddControl(LPriceLabel, 1, 0);
  FGridP.ControlCollection.AddControl(LDiffLabel, 1, 1);
end;

function TMainUnit.UpdatePriceLabel(const Symbol: String; Price: Double; OpenPrice: Double): TLabel;
var
  PriceDifference, PricePercentage: Double;
begin
  // Update the TLabel with the new price for the given symbol
  if FSymbolLabels.TryGetValue(Symbol, LPriceLabel) and
     FPercentLabels.TryGetValue(Symbol, LPercLabel) and
     FDifferenceLabels.TryGetValue(Symbol, LDiffLabel) then
  begin
    // Update the TLabel's Text property with the new price
    if LPriceLabel.Text <> LPrice.ToString then
      LPriceLabel.Text := Format('%.4f', [Price]);
    // Calculate the difference and percentage change
    PriceDifference := Price - OpenPrice;
    PricePercentage := (PriceDifference) / OpenPrice * 100;
    // Update the TLabel with the calculated percentage and difference
    LPercLabel.Text := FormatFloat('0.00', PricePercentage) + '%';
    Memo2.Lines.Add('Updating percentage label for ' + Symbol + ' with value: ' + LPercLabel.Text); // Debug message

    LDiffLabel.Text := FormatFloat('0.00', PriceDifference);
    Memo2.Lines.Add('Updating difference label for ' + Symbol + ' with value: ' + LDiffLabel.Text); // Debug message
  end
  else
  begin
    // Handle the case when the symbol is not found in the dictionary, if necessary
    raise Exception.CreateFmt('UI for symbol %s not found', [Symbol]);
  end;
end;

procedure TMainUnit.StartCourcesFuture(iText: String);
begin
  var NObjJSON: Integer;
  var LIterator: TJSONIterator;
  var LJsonTextReader: TJsonTextReader;
  var LStringReader: TStringReader;
  LStringReader := TStringReader.Create(iText);
  LJsonTextReader := TJsonTextReader.Create(LStringReader);
  LIterator := TJSONIterator.Create(LJsonTextReader);
  NObjJSON := LIterator.AsInteger;
  {$REGION 'Region JSONIterator'}
  try
    while True do
    begin
      while LIterator.Next do
      begin
        if LIterator.&Type in [TJsonToken.StartObject, TJsonToken.StartArray] then
        begin
          Memo2.Lines.Add(LIterator.Key);
          LIterator.Recurse;
        end
        else if (LIterator.Path = 'success['+NObjJSON.ToString+'].symbol') and (LIterator.&Type = TJsonToken.String) then
        begin
          Memo2.Lines.Add('Object #' + NObjJSON.ToString + ' ' + LIterator.AsValue.ToString + ' ');
          // create the rectangle control
          CreateSymbolUI(NObjJSON, LIterator.AsString);
          // increment the object counter
          Inc(NObjJSON);
        end
        else if (LIterator.Path = 'event') and (LIterator.AsString = 'price') then
        begin
          while LIterator.Next do
          begin
            if LIterator.Path = 'symbol' then
            begin
              // Get the symbol name
              LSymbol := LIterator.AsString;
            end else
            if LIterator.Path = 'price' then
            begin
              // Update the last price information using the dictionary
              var LPriceT: String := LIterator.AsDouble.ToString;
              LPriceT := StringReplace(LPriceT, '.', FormatSettings.DecimalSeparator, [rfReplaceAll]);
              LPrice := StrToCurr(LPriceT);
              TTask.Run(
                procedure
                begin
                  TThread.Queue(nil,
                    procedure
                    begin
                      UpdatePriceLabel(LSymbol, LPrice, FOpenValue);
                    end);
                end);
            end;
          end;
        end;
      end;
      if LIterator.InRecurse then
        LIterator.Return
      else
        Break;
    end;
  finally
    LIterator.Free;
    LJsonTextReader.Free;
    lStringReader.Free;
  end;
  {$ENDREGION 'Region JSONIterator'}
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TMainUnit.FormCreate(Sender: TObject);
begin
  {$IFDEF MSWINDOWS}
    ReportMemoryLeaksOnShutdown := (DebugHook <> 1);
  {$ENDIF}
  FBirdSocket := TBirdSocketClient.Create(nil);
  FBirdSocket.ConnectTimeout := 5000;  //5 sec
  FSymbolLabels := TDictionary<string, TLabel>.Create;
  FPercentLabels := TDictionary<string, TLabel>.Create;
  FDifferenceLabels := TDictionary<string, TLabel>.Create;
  FOpenValues := TDictionary<String, Double>.Create;
  Timer1 := TTimer.Create(Self);
  Timer1.Interval := 10000;
  Timer1.OnTimer := Timer1Timer;
  Timer1.Enabled := False;
  CloseConnection.Enabled := False;
  Send.Enabled := False;
end;

procedure TMainUnit.FormDestroy(Sender: TObject);
begin
  Timer1.DisposeOf;
  Memo2.Lines.Clear;
  FOpenValues.Free;
  FSymbolLabels.Free;
  FPercentLabels.Free;
  FDifferenceLabels.Free;
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TMainUnit.OpenConnectionClick(Sender: TObject);
begin
  AuxPrice;
  try
    if API= EmptyWideStr then
    begin
      ShowMessage('Register to TwelveDate and paste API key');
      Exit;
    end
    else
      FBirdSocket := TBirdSocketClient.New(API);

    FBirdSocket.AddEventListener(TEventType.MESSAGE,
      procedure(const AText: string)
      begin
        Display(AText);
        StartCourcesFuture(AText);
      end);
    FBirdSocket.Connect;
    FBirdSocket.AutoCreateHandler := True;
    DisplayMemo.Lines.Add('Websocket connection opened!');

    OpenConnection.Enabled := False;
    CloseConnection.Enabled := True;
    Timer1.Enabled := True;

  except
    on E:Exception do
    begin
      FBirdSocket.Disconnect;
      FreeAndNil(FBirdSocket);
      Display(E.Message);
    end;
  end
end;

procedure TMainUnit.CloseConnectionClick(Sender: TObject);
begin
  try
    if not Assigned(FBirdSocket) then
      Exit;
    if FBirdSocket.Connected then
      FBirdSocket.Disconnect;
    DisplayMemo.Lines.Add('Websocket connection closed!');
    FreeAndNil(FBirdSocket);
    FreeAndNil(Timer1);
//    Timer1.Enabled := False;
    CloseConnection.Enabled := False;
    Send.Enabled := False;
    OpenConnection.Enabled := True;
  except
    on E:Exception do
      Display(E.Message);
  end
end;

{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}
procedure TMainUnit.ResetClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Text := '   {' +  sLineBreak +
                      '       "action": "reset"' +  sLineBreak +
                      '   }' ;
  Send.Enabled := True;
end;

procedure TMainUnit.SubscribeClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Text := '   {' +  sLineBreak +
                      '       "action": "subscribe",' +  sLineBreak +
                      '       "params": {' +  sLineBreak +
                      '          "symbols": "ETH/BTC,BTC/USD"' +  sLineBreak +
                      '       }' +  sLineBreak +
                      '   }';
  Send.Enabled := True;
end;

procedure TMainUnit.UnsubscribeClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo1.Lines.Text := '   {' +  sLineBreak +
                      '       "action": "unsubscribe",' +  sLineBreak +
                      '       "params": {' +  sLineBreak +
                      '          "symbols": "EUR/USD"' +  sLineBreak +
                      '       }' +  sLineBreak +
                      '   }';
  Send.Enabled := True;
end;

procedure TMainUnit.SendClick(Sender: TObject);
begin
  FBirdSocket.Send(Memo1.lines.Text);
end;

procedure TMainUnit.Timer1Timer(Sender: TObject);
begin
  FBirdSocket.Send('{"action": "heartbeat"}');
  DisplayMemo.Lines.Add(Format('%s ==> %s', [FormatDateTime('dd/mm/yyyy hh:mm:ss', Now), '{"action": "heartbeat"}']));
end;

end.
