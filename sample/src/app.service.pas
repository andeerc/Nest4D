unit app.service;

interface

uses
  Nest4D.Attributes,
  Nest4D.Logger;

type
  [Injectable]
  TAppService = Class
  private
    FLogger: INest4DLogger;  public
    constructor Create();
    function GetWelcomeMessage: String;
    function ProcessData(const AData: String): String;
  End;

implementation

uses
  System.SysUtils,
  Nest4D.Injector;

{ TAppService }

constructor TAppService.Create();
begin
  // Try to get logger from DI container, fallback to default if not available
  try
    FLogger := N4DInjector.GetInterface<INest4DLogger>;
  except
    // Fallback to a default logger implementation
    FLogger := TNest4DDefaultLogger.Create;
  end;
  
  if Assigned(FLogger) then
    FLogger.Info('AppService created successfully (parameterless constructor)');
end;

function TAppService.GetWelcomeMessage: String;
begin
  if Assigned(FLogger) then
    FLogger.Debug('Getting welcome message');
  Result := 'Welcome to Nest4D Framework!';
  if Assigned(FLogger) then
    FLogger.Info('Welcome message returned');
end;

function TAppService.ProcessData(const AData: String): String;
begin
  if Assigned(FLogger) then
    FLogger.Debug('Processing data: ' + AData);
  try
    // Simulate some processing
    Result := 'Processed: ' + AData;
    if Assigned(FLogger) then
      FLogger.Info('Data processed successfully');
  except
    on E: Exception do
    begin
      if Assigned(FLogger) then
        FLogger.Error('Error processing data: ' + E.Message);
      raise;
    end;
  end;
end;

end.
