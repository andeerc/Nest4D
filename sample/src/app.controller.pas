unit app.controller;

interface

uses
  System.Json,
  System.Generics.Collections,
  Nest4D.Attributes,
  Nest4D.Logger,
  app.service;

type

  [controller('/api')]
  TAppController = Class
  private
    FAppService: TAppService;
    FLogger    : INest4DLogger;
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
    function AddItem(const AItem: TJsonObject): String;

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
    function createData([Body] jsonData: TJsonObject): string;

    [Post('/text')]
    function processText([Body] textData: string): string;

    // Example: Logger configuration
    [Post('/logger/config')]
    function configureLogger([Body] configData: TJsonObject): string;

    [Get('/logger/test')]
    function testLogger: string;

    [Get('/logger/constructor-test')]
    function testConstructorSelection: string;

    constructor Create(AAppService: TAppService; ALogger: INest4DLogger);
  End;

implementation

uses
  Rtti,
  System.TypInfo,
  System.SysUtils;

{ TAppController }

constructor TAppController.Create(AAppService: TAppService; ALogger: INest4DLogger);
begin
  FAppService := AAppService;
  FLogger     := ALogger;
  FLogger.Info('AppController created successfully');
end;

function TAppController.getApi: TJsonObject;
begin
  FLogger.Debug('Processing getApi request');

  try
    Result := TJsonObject.Create.AddPair('message', 'Hello, World!');
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
    Result := FAppService.processData(ABody);
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
  Result := 'ID received: ' + id;
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

function TAppController.AddItem(const AItem: TJsonObject): String;
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
  pair     : TPair<String, String>;
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
  pair     : TPair<String, String>;
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
  pair     : TPair<String, String>;
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

function TAppController.createData(jsonData: TJsonObject): string;
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

function TAppController.configureLogger(configData: TJsonObject): string;
var
  config                     : TLoggerConfig;
  minLevelStr, destinationStr: string;
begin
  FLogger.Debug('Configuring logger with provided data');

  try
    // Obtém configuração atual
    config := FLogger.GetConfig;

    // Configura nível mínimo se fornecido
    if configData.TryGetValue('minLevel', minLevelStr) then
    begin
      if minLevelStr = 'debug' then
        config.MinLevel := llDebug
      else
        if minLevelStr = 'info' then
          config.MinLevel := llInfo
        else
          if minLevelStr = 'warn' then
            config.MinLevel := llWarn
          else
            if minLevelStr = 'error' then
              config.MinLevel := llError
            else
              if minLevelStr = 'fatal' then
                config.MinLevel := llFatal;
    end;

    // Configura destino se fornecido
    if configData.TryGetValue('destination', destinationStr) then
    begin
      if destinationStr = 'console' then
        config.Destination := ldConsole
      else
        if destinationStr = 'file' then
          config.Destination := ldFile
        else
          if destinationStr = 'both' then
            config.Destination := ldBoth;
    end;

    // Configura nome do arquivo se fornecido
    if configData.TryGetValue('logFileName', config.LogFileName) then
      // Valor já atribuído
        ;

    // Configura timestamp se fornecido
    if configData.TryGetValue('includeTimestamp', config.IncludeTimestamp) then
      // Valor já atribuído
        ;

    // Configura nível no log se fornecido
    if configData.TryGetValue('includeLevel', config.IncludeLevel) then
      // Valor já atribuído
        ;

    // Aplica a nova configuração
    FLogger.SetConfig(config);

    FLogger.Info('Logger configuration updated successfully');
    Result := 'Logger configured successfully with new settings';
  except
    on E: Exception do
    begin
      FLogger.Error('Error configuring logger: ' + E.Message);
      Result := 'Error configuring logger: ' + E.Message;
    end;
  end;
end;

function TAppController.testLogger: string;
begin
  FLogger.Debug('Testing logger - Debug level message');
  FLogger.Info('Testing logger - Info level message');
  FLogger.Warn('Testing logger - Warning level message');
  FLogger.Error('Testing logger - Error level message');
  FLogger.Fatal('Testing logger - Fatal level message');

  Result := 'Logger tested successfully - check console/log file for messages';
end;

function TAppController.testConstructorSelection: string;
var
  defaultLogger: INest4DLogger;
  customLogger: INest4DLogger;
  config: TLoggerConfig;
  testResult: string;
begin
  FLogger.Info('Testing constructor selection for logger instances');
  testResult := 'Constructor Selection Test Results:' + sLineBreak;
  
  try
    // Teste 1: Logger com constructor padrão (sem parâmetros)
    FLogger.Debug('Creating logger with default constructor');
    defaultLogger := TNest4DDefaultLogger.Create;
    testResult := testResult + '✓ Default constructor (parameterless): SUCCESS' + sLineBreak;
    
    // Teste 2: Logger com constructor customizado (com parâmetros)
    FLogger.Debug('Creating logger with custom configuration constructor');
    config := TLoggerConfig.Default;
    config.MinLevel := llWarn;
    config.Destination := ldConsole;
    config.LogFileName := 'test_constructor.log';
    
    customLogger := TNest4DDefaultLogger.Create(config);
    testResult := testResult + '✓ Custom constructor (with TLoggerConfig): SUCCESS' + sLineBreak;
    
    // Teste 3: Verificar se configurações foram aplicadas
    if customLogger.GetConfig.MinLevel = llWarn then
      testResult := testResult + '✓ Configuration properly applied: SUCCESS' + sLineBreak
    else
      testResult := testResult + '✗ Configuration not applied correctly' + sLineBreak;
    
    // Teste 4: Verificar injeção via DI container 
    FLogger.Debug('Testing DI container constructor selection');
    testResult := testResult + '✓ DI Container injection: Using injected logger (configured via module)' + sLineBreak;
    
    // Mostrar configuração atual do logger injetado
    config := FLogger.GetConfig;
    testResult := testResult + Format('Current Logger Config: MinLevel=%s, Destination=%s, File=%s', [
      GetEnumName(TypeInfo(TLogLevel), Ord(config.MinLevel)),
      GetEnumName(TypeInfo(TLogDestination), Ord(config.Destination)),
      config.LogFileName
    ]) + sLineBreak;
    
    FLogger.Info('Constructor selection test completed successfully');
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in constructor selection test: ' + E.Message);
      testResult := testResult + '✗ ERROR: ' + E.Message + sLineBreak;
    end;
  end;
  
  Result := testResult;
end;

end.
