unit app.controller;

interface

uses
  System.Json,
  System.Generics.Collections,
  Nest4D.Attributes,
  Nest4D.Logger,
  app.service;

type
  [Controller('/api')]
  TAppController = Class
  private
    FAppService: TAppService;
    FLogger: INest4DLogger;
  public
    [Get('')]
    function getApi: TJsonObject;

    [Get('/health')]
    function getHealth: String;

    [Post('/process')]
    function processData([Body] const ABody: String): String;

    [Get('/teste/:id')]
    function processTeste([Param('id')] id: string): string;

    [Get('/items')]
    function GetItems: TJSONArray;

    [Post('/items')]
    function AddItem(const AItem: TJSONObject): String;

    // Example: Get specific query parameter
    [Get('/search')]
    function searchData([Query('term')] searchTerm: string; [Query('limit')] limit: Integer): string;

    // Example: Get all query parameters
    [Get('/info')]
    function getInfo([Query()] allQueryParams: TDictionary<String, String>): string;

    // Example: Get specific header
    [Get('/auth')]
    function checkAuth([Header('Authorization')] authToken: string): string;

    // Example: Get all headers
    [Get('/debug')]
    function debugRequest([Header()] allHeaders: TDictionary<String, String>): string;

    // Example: Get all route parameters
    [Get('/users/:userId/posts/:postId')]
    function getUserPost([Param()] allParams: TDictionary<String, String>): string;

    // Example: Using body with different types
    [Post('/data')]
    function createData([Body] jsonData: TJSONObject): string;

    [Post('/text')]
    function processText([Body] textData: string): string;

    constructor Create(AAppService: TAppService; ALogger: INest4DLogger);
  End;
                       
implementation

uses
  System.SysUtils;

{ TAppController }

constructor TAppController.Create(AAppService: TAppService; ALogger: INest4DLogger);
begin
  FAppService := AAppService;
  FLogger := ALogger;
  FLogger.Info('AppController created successfully');
end;

function TAppController.getApi: TJsonObject;
begin
  FLogger.Debug('Processing getApi request');
  
  try
    Result := TJSONObject.Create.AddPair('message', 'Hello, World!');
    FLogger.Info('getApi request processed successfully');
  except
    on E: Exception do
    begin
      FLogger.Error('Error in getApi: ' + E.Message);
      raise;
    end;
  end;
end;

function TAppController.getHealth: String;
begin
  FLogger.Debug('Health check requested');
  Result := 'OK';
  FLogger.Info('Health check completed');
end;

function TAppController.processData(const ABody: String): String;
begin
  FLogger.Debug('Processing data request');
  try
    Result := FAppService.ProcessData(ABody);
    FLogger.Info('Data processing request completed');
  except
    on E: Exception do
    begin
      FLogger.Error('Error in processData endpoint: ' + E.Message);
      raise;
    end;
  end;
end;

function TAppController.processTeste(id: string): string;
begin
  FLogger.Debug('Processing teste with ID: ' + id);
  result := 'ID received: ' + id;
end;

function TAppController.GetItems: TJSONArray;
begin
  FLogger.Debug('Fetching items');
  try
    // Here you would fetch the items from the service or database
    Result := TJSONArray.Create;
    Result.Add('Item 1');
    Result.Add('Item 2');
    FLogger.Info('Items fetched successfully');
  except
    on E: Exception do
    begin
      FLogger.Error('Error fetching items: ' + E.Message);
      raise;
    end;
  end;
end;

function TAppController.AddItem(const AItem: TJSONObject): String;
begin
  FLogger.Debug('Adding new item');
  try
    // Here you would add the item to the service or database
    Result := 'Item added successfully';
    FLogger.Info('Item added successfully');
  except
    on E: Exception do
    begin
      FLogger.Error('Error adding item: ' + E.Message);
      raise;
    end;
  end;
end;

function TAppController.searchData(searchTerm: string; limit: Integer): string;
begin
  FLogger.Debug(Format('Searching for: %s with limit: %d', [searchTerm, limit]));
  Result := Format('Search results for "%s" (limit: %d)', [searchTerm, limit]);
end;

function TAppController.getInfo(allQueryParams: TDictionary<String, String>): string;
var
  pair: TPair<String, String>;
  resultMsg: string;
begin
  FLogger.Debug('Getting all query parameters');
  resultMsg := 'Query parameters: ';
  
  if allQueryParams <> nil then
  begin
    for pair in allQueryParams do
    begin
      resultMsg := resultMsg + Format('%s=%s; ', [pair.Key, pair.Value]);
    end;
  end
  else
  begin
    resultMsg := resultMsg + 'none';
  end;
  
  Result := resultMsg;
end;

function TAppController.checkAuth(authToken: string): string;
begin
  FLogger.Debug('Checking authorization with token: ' + authToken);
  if authToken <> '' then
    Result := 'Authorized with token: ' + authToken
  else
    Result := 'No authorization token provided';
end;

function TAppController.debugRequest(allHeaders: TDictionary<String, String>): string;
var
  pair: TPair<String, String>;
  resultMsg: string;
begin
  FLogger.Debug('Getting all request headers');
  resultMsg := 'Headers: ';
  
  if allHeaders <> nil then
  begin
    for pair in allHeaders do
    begin
      resultMsg := resultMsg + Format('%s=%s; ', [pair.Key, pair.Value]);
    end;
  end
  else
  begin
    resultMsg := resultMsg + 'none';
  end;
  
  Result := resultMsg;
end;

function TAppController.getUserPost(allParams: TDictionary<String, String>): string;
var
  pair: TPair<String, String>;
  resultMsg: string;
begin
  FLogger.Debug('Getting user post with all route parameters');
  resultMsg := 'Route parameters: ';
  
  if allParams <> nil then
  begin
    for pair in allParams do
    begin
      resultMsg := resultMsg + Format('%s=%s; ', [pair.Key, pair.Value]);
    end;
  end
  else
  begin
    resultMsg := resultMsg + 'none';
  end;
  
  Result := resultMsg;
end;

function TAppController.createData(jsonData: TJSONObject): string;
begin
  FLogger.Debug('Creating data from JSON body');
  
  if jsonData <> nil then
  begin
    Result := 'Data created from JSON: ' + jsonData.ToJSON;
  end
  else
  begin
    Result := 'No JSON data provided';
  end;
end;

function TAppController.processText(textData: string): string;
begin
  FLogger.Debug('Processing text data: ' + textData);
  Result := 'Text processed: ' + textData;
end;

end.
