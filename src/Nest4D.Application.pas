unit Nest4D.Application;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.RTTI,
  System.TypInfo,
  Nest4D.Injector,
  Nest4D.Logger,
  Horse;

type
  // Simplified method record with cleaner structure
  TMethodInfo = record
    ControllerType: TRttiType;
    ControllerClass: TClass;
    MethodName: String;
    Path: String;
    HTTPMethod: String;
  end;

  THTTPMethodType = (mtGet, mtPost, mtPut, mtPatch, mtDelete);

  TNest4DApplication = class
  private
    FAppModule: TClass;
    FCallback: TProc<TNest4DApplication>;
    FMethodsDictionary: TDictionary<String, TMethodInfo>;
    FRttiContext: TRttiContext;
    FLogger: INest4DLogger;

    // Core initialization
    procedure InternalStart;    // Module and dependency registration
    procedure RegisterModule(AModule: TClass);
    procedure RegisterDependencies(AType: TRttiType);
    procedure RegisterService(AService: TClass);
    procedure RegisterController(AController: TClass);
    procedure RegisterControllerWithDependencies(AController: TClass);    // Route registration helpers
    procedure RegisterControllerRoutes(AController: TClass; AControllerType: TRttiType; const AControllerPath: String);
    procedure RegisterSingleRoute(const AHTTPMethod, AControllerPath, ARoutePath, AMethodName: String;
      AControllerClass: TClass; AControllerType: TRttiType);

    // Constructor parameter resolution
    function ResolveConstructorParameters(const AClass: TClass): TConstructorParams;

    // Request processing
    procedure ProcessRequest(req: THorseRequest; res: THorseResponse; const MethodType: THTTPMethodType);
    function GetControllerInstance(const AMethodInfo: TMethodInfo): TObject;
    function CreateInstanceWithDependencies(const AClass: TClass): TObject;
    function ResolveMethodParameters(const AMethod: TRttiMethod; ARequest: THorseRequest; AResponse: THorseResponse): TArray<TValue>;

    // Utility methods
    function BuildRouteKey(const AHTTPMethod, APath: String): String;
    function NormalizePath(const APath: String): String;
    function FindRouteMatch(const ARequestedPath: String): String;
    procedure LogRouteRegistration(const AHTTPMethod, APath, AControllerName: String);

    constructor Create(AAppModule: TClass; ACallback: TProc<TNest4DApplication>);
  public
    procedure Start(APort: Integer = 3030; ACallback: TProc = nil);
    class procedure NewApplication(AAppModule: TClass; ACallback: TProc<TNest4DApplication>);
    destructor Destroy; override;
  end;

implementation

uses
  System.Diagnostics,
  System.JSON,
  Nest4D.Interfaces,
  Nest4D.Attributes;

{ TNest4DApplication }

constructor TNest4DApplication.Create(AAppModule: TClass; ACallback: TProc<TNest4DApplication>);
begin
  Self.FAppModule    := AAppModule;
  Self.FCallback     := ACallback;
  FMethodsDictionary := TDictionary<String, TMethodInfo>.Create;
  FRttiContext := TRttiContext.Create;

  // Initialize logger - register default logger service
  try
    N4DInjector.SingletonInterface<INest4DLogger, TNest4DDefaultLogger>;
    FLogger := N4DInjector.GetInterface<INest4DLogger>;
  except
    FLogger := TNest4DDefaultLogger.Create;
  end;

  InternalStart();
end;

destructor TNest4DApplication.Destroy;
begin
  FMethodsDictionary.Free;
  inherited;
end;

procedure TNest4DApplication.InternalStart;
var
  moduleStopwatch: TStopwatch;
begin
  try
    moduleStopwatch := TStopwatch.StartNew;
    try
      FLogger.Info('Starting Nest4D application initialization...');
      RegisterModule(FAppModule);
    finally
      FLogger.Info(Format('Total load time: %d ms', [moduleStopwatch.ElapsedMilliseconds]));
    end;

    if Assigned(FCallback) then
      FCallback(Self);
  except
    on E: Exception do
    begin
      FLogger.Error('Error during application initialization: ' + E.Message);
      raise;
    end;
  end;
end;

class procedure TNest4DApplication.NewApplication(AAppModule: TClass; ACallback: TProc<TNest4DApplication>);
begin
  TNest4DApplication.Create(AAppModule, ACallback);
end;

procedure TNest4DApplication.RegisterModule(AModule: TClass);
var
  moduleType: TRttiType;
begin
  FLogger.Debug('Registering module: ' + AModule.ClassName);

  moduleType := FRttiContext.GetType(AModule);
  if moduleType = nil then
  begin
    FLogger.Error('Could not get RTTI type for module: ' + AModule.ClassName);
    Exit;
  end;

  RegisterDependencies(moduleType);
  FLogger.Info('Module registered successfully: ' + AModule.ClassName);
end;

procedure TNest4DApplication.RegisterDependencies(AType: TRttiType);
var
  moduleInstance: TObject;
  module: IN4DModule;
  service, controller: TClass;
begin
  // Try to create an instance of the module to get its configuration
  try
    moduleInstance := AType.AsInstance.MetaclassType.Create;
    try
      if Supports(moduleInstance, IN4DModule, module) then
      begin
        // Register services
        for service in module.Services do
        begin
          RegisterService(service);
        end;

        // Register controllers
        for controller in module.Controllers do
        begin
          RegisterController(controller);
        end;

        // Register imported modules
        for service in module.Imports do
        begin
          RegisterModule(service);
        end;
      end
      else
      begin
        FLogger.Warn('Module does not implement IN4DModule interface: ' + AType.Name);
      end;
    finally
      //moduleInstance.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error processing module dependencies: ' + E.Message);
    end;
  end;
end;

procedure TNest4DApplication.RegisterService(AService: TClass);
begin
  FLogger.Debug('Registering service: ' + AService.ClassName);
  try
    N4DInjector.Singleton(AService);
    FLogger.Info('Service registered: ' + AService.ClassName);
  except
    on E: Exception do
      FLogger.Error('Failed to register service ' + AService.ClassName + ': ' + E.Message);
  end;
end;

procedure TNest4DApplication.RegisterController(AController: TClass);
var
  controllerType: TRttiType;
  controllerPath: String;
  attr: TCustomAttribute;
begin
  FLogger.Debug('Registering controller: ' + AController.ClassName);

  controllerType := FRttiContext.GetType(AController);
  if controllerType = nil then
  begin
    FLogger.Error('Could not get RTTI type for controller: ' + AController.ClassName);
    Exit;
  end;

  // Register controller dependencies first
  RegisterControllerWithDependencies(AController);

  // Register controller as a service with custom constructor callback
  try
    N4DInjector.Singleton(AController,
      function: TConstructorParams
      begin
        Result := ResolveConstructorParameters(AController);
      end);
    FLogger.Info('Controller registered: ' + AController.ClassName);
  except
    on E: Exception do
      FLogger.Error('Failed to register controller ' + AController.ClassName + ': ' + E.Message);
  end;

  // Get controller base path
  controllerPath := '';
  for attr in controllerType.GetAttributes do
  begin
    if attr is Controller then
    begin
      controllerPath := Controller(attr).Path;
      Break;
    end;
  end;

  RegisterControllerRoutes(AController, controllerType, controllerPath);
end;

procedure TNest4DApplication.RegisterControllerRoutes(AController: TClass;
  AControllerType: TRttiType; const AControllerPath: String);
var
  method: TRttiMethod;
  attr: TCustomAttribute;
  httpMethod, routePath: String;
begin
  for method in AControllerType.GetMethods do
  begin
    for attr in method.GetAttributes do
    begin
      httpMethod := '';
      routePath := '';

      if attr is Get then
      begin
        httpMethod := 'GET';
        routePath := Get(attr).Path;
      end
      else if attr is Post then
      begin
        httpMethod := 'POST';
        routePath := Post(attr).Path;
      end
      else if attr is Put then
      begin
        httpMethod := 'PUT';
        routePath := Put(attr).Path;
      end
      else if attr is Patch then
      begin
        httpMethod := 'PATCH';
        routePath := Patch(attr).Path;
      end
      else if attr is Delete then
      begin
        httpMethod := 'DELETE';
        routePath := Delete(attr).Path;
      end;

      if httpMethod <> '' then
      begin
        RegisterSingleRoute(httpMethod, AControllerPath, routePath,
          method.Name, AController, AControllerType);
      end;
    end;
  end;
end;

procedure TNest4DApplication.RegisterSingleRoute(const AHTTPMethod, AControllerPath,
  ARoutePath, AMethodName: String; AControllerClass: TClass; AControllerType: TRttiType);
var
  fullPath, routeKey: String;
  methodInfo: TMethodInfo;
begin
  fullPath := NormalizePath(AControllerPath + ARoutePath);
  routeKey := BuildRouteKey(AHTTPMethod, fullPath);

  methodInfo.ControllerType := AControllerType;
  methodInfo.ControllerClass := AControllerClass;
  methodInfo.MethodName := AMethodName;
  methodInfo.Path := fullPath;
  methodInfo.HTTPMethod := AHTTPMethod;

  FMethodsDictionary.Add(routeKey, methodInfo);

  // Register with Horse
  if AHTTPMethod = 'GET' then
    THorse.Get(fullPath,
      procedure(req: THorseRequest; res: THorseResponse)
      begin
        ProcessRequest(req, res, mtGet);
      end)
  else if AHTTPMethod = 'POST' then
    THorse.Post(fullPath,
      procedure(req: THorseRequest; res: THorseResponse)
      begin
        ProcessRequest(req, res, mtPost);
      end)
  else if AHTTPMethod = 'PUT' then
    THorse.Put(fullPath,
      procedure(req: THorseRequest; res: THorseResponse)
      begin
        ProcessRequest(req, res, mtPut);
      end)
  else if AHTTPMethod = 'PATCH' then
    THorse.Patch(fullPath,
      procedure(req: THorseRequest; res: THorseResponse)
      begin
        ProcessRequest(req, res, mtPatch);
      end)
  else if AHTTPMethod = 'DELETE' then
    THorse.Delete(fullPath,
      procedure(req: THorseRequest; res: THorseResponse)
      begin
        ProcessRequest(req, res, mtDelete);
      end);

  LogRouteRegistration(AHTTPMethod, fullPath, AControllerClass.ClassName);
end;

function TNest4DApplication.GetControllerInstance(const AMethodInfo: TMethodInfo): TObject;
begin
  Result := nil;

  try
    // Try to get from injector
    Result := N4DInjector.Get(AMethodInfo.ControllerClass);

    if Result <> nil then
    begin
      FLogger.Debug('Controller instance obtained from injector: ' + AMethodInfo.ControllerClass.ClassName);
      Exit;
    end;

    // Fallback: register controller with dependency analysis and get
    FLogger.Debug('Attempting to register controller with dependencies on-demand: ' + AMethodInfo.ControllerClass.ClassName);
    RegisterControllerWithDependencies(AMethodInfo.ControllerClass);
    Result := N4DInjector.Get(AMethodInfo.ControllerClass);

    if Result <> nil then
    begin
      FLogger.Debug('Controller instance obtained after dependency-aware registration');
      Exit;
    end;

    // Last resort: manual creation with dependency resolution
    FLogger.Warn('Creating controller instance manually: ' + AMethodInfo.ControllerClass.ClassName);
    Result := CreateInstanceWithDependencies(AMethodInfo.ControllerClass);

  except
    on E: Exception do
    begin
      FLogger.Error('Failed to create controller instance: ' + E.Message);
      raise;
    end;
  end;
end;

function TNest4DApplication.BuildRouteKey(const AHTTPMethod, APath: String): String;
begin
  Result := AHTTPMethod + ':' + APath;
end;

function TNest4DApplication.NormalizePath(const APath: String): String;
begin
  Result := APath;

  // Remove double slashes
  while Pos('//', Result) > 0 do
    Result := StringReplace(Result, '//', '/', [rfReplaceAll]);

  // Ensure it starts with /
  if not Result.StartsWith('/') then
    Result := '/' + Result;

  // Remove trailing slash (except for root)
  if (Length(Result) > 1) and Result.EndsWith('/') then
    Result := Copy(Result, 1, Length(Result) - 1);
end;

function TNest4DApplication.FindRouteMatch(const ARequestedPath: String): String;
var
  pair: TPair<String, TMethodInfo>;
  requestSegments, patternSegments: TArray<String>;
  i: Integer;
  isMatch: Boolean;
  httpMethod: String;
begin
  Result := '';

  // Try exact match first
  for pair in FMethodsDictionary do
  begin
    if pair.Value.Path = ARequestedPath then
    begin
      Result := pair.Key;
      Exit;
    end;
  end;

  // Try parameter matching (/users/:id)
  for pair in FMethodsDictionary do
  begin
    // Extract HTTP method from route key (format: "GET:/api/users/:id")
    httpMethod := Copy(pair.Key, 1, Pos(':', pair.Key) - 1);

    // Check if this route has parameters (contains ':')
    if Pos(':', pair.Value.Path) > 0 then
    begin
      // Split paths into segments
      requestSegments := ARequestedPath.Split(['/']);
      patternSegments := pair.Value.Path.Split(['/']);

      // Check if segment count matches
      if Length(requestSegments) = Length(patternSegments) then
      begin
        isMatch := True;

        // Compare each segment
        for i := 0 to High(patternSegments) do
        begin
          // Skip parameter segments (start with ':')
          if not patternSegments[i].StartsWith(':') then
          begin
            // Must be exact match for non-parameter segments
            if requestSegments[i] <> patternSegments[i] then
            begin
              isMatch := False;
              Break;
            end;
          end;
        end;

        if isMatch then
        begin
          Result := pair.Key;

          // Extract and set route parameters for Horse
          for i := 0 to High(patternSegments) do
          begin
            if patternSegments[i].StartsWith(':') then
            begin
              // Extract parameter name (remove ':')
              FLogger.Debug(Format('Extracted route parameter: %s = %s',
                [Copy(patternSegments[i], 2, Length(patternSegments[i])), requestSegments[i]]));
            end;
          end;

          Exit;
        end;
      end;
    end;
  end;
end;

procedure TNest4DApplication.LogRouteRegistration(const AHTTPMethod, APath, AControllerName: String);
begin
  FLogger.Info(Format('Route registered: %s %s -> %s', [AHTTPMethod, APath, AControllerName]));
end;

procedure MakeResponse(method: TRttiMethod; response: THorseResponse; resultValue: TValue);
begin
  if resultValue.IsType<TJSONObject>() then
  begin
    response.ContentType('application/json').Send(resultValue.AsType<TJSONObject>.ToJSON);
    exit;
  end;

  if resultValue.IsType<String>() then
  begin
    response.Send(resultValue.AsString);
    exit;
  end;
end;

procedure TNest4DApplication.ProcessRequest(req: THorseRequest; res: THorseResponse; const MethodType: THTTPMethodType);
var
  requestPath, routeKey: String;
  methodInfo: TMethodInfo;
  instance: TObject;
  method: TRttiMethod;
  methodResult: TValue;
  methodParams: TArray<TValue>;
begin
  try
    requestPath := req.RawWebRequest.PathInfo;
    if requestPath = '' then
      requestPath := '/';

    // Build route key based on HTTP method
    case MethodType of
      mtGet: routeKey := BuildRouteKey('GET', requestPath);
      mtPost: routeKey := BuildRouteKey('POST', requestPath);
      mtPut: routeKey := BuildRouteKey('PUT', requestPath);
      mtPatch: routeKey := BuildRouteKey('PATCH', requestPath);
      mtDelete: routeKey := BuildRouteKey('DELETE', requestPath);
    end;

    // Log request processing
    case MethodType of
      mtGet: FLogger.Debug(Format('Processing GET request for path: %s', [requestPath]));
      mtPost: FLogger.Debug(Format('Processing POST request for path: %s', [requestPath]));
      mtPut: FLogger.Debug(Format('Processing PUT request for path: %s', [requestPath]));
      mtPatch: FLogger.Debug(Format('Processing PATCH request for path: %s', [requestPath]));
      mtDelete: FLogger.Debug(Format('Processing DELETE request for path: %s', [requestPath]));
    end;

    if not FMethodsDictionary.TryGetValue(routeKey, methodInfo) then
    begin
      // Try to find a matching route with parameters
      routeKey := FindRouteMatch(requestPath);
      if routeKey = '' then
      begin
        FLogger.Warn('Route not found: ' + requestPath);
        res.Status(404).Send('Route not found');
        Exit;
      end;
      methodInfo := FMethodsDictionary[routeKey];
    end;

    // Get controller instance
    instance := GetControllerInstance(methodInfo);
    if instance = nil then
    begin
      FLogger.Error('Could not create controller instance for: ' + methodInfo.ControllerClass.ClassName);
      res.Status(500).Send('Internal server error');
      Exit;
    end;

    // Get method
    method := methodInfo.ControllerType.GetMethod(methodInfo.MethodName);
    if method = nil then
    begin
      FLogger.Error('Method not found: ' + methodInfo.MethodName);
      res.Status(500).Send('Internal server error');
      Exit;
    end;    // Prepare method parameters using RTTI and DI resolution
    methodParams := ResolveMethodParameters(method, req, res);

    // Invoke method
    FLogger.Debug(Format('Invoking method %s on controller %s',
      [methodInfo.MethodName, methodInfo.ControllerClass.ClassName]));

    methodResult := method.Invoke(instance, methodParams);

    // Process response
    MakeResponse(method, res, methodResult);

  except
    on E: Exception do
    begin
      FLogger.Error('Error processing request: ' + E.Message);
      res.Status(500).Send('Internal server error: ' + E.Message);
    end;
  end;
end;

procedure TNest4DApplication.Start(APort: Integer; ACallback: TProc);
begin
  FLogger.Info(Format('Starting Nest4D application on port %d', [APort]));
  try
    THorse.Listen(APort, ACallback);
  except
    on E: Exception do
    begin
      FLogger.Fatal('Failed to start application: ' + E.Message);
      raise;
    end;
  end;
end;

function TNest4DApplication.ResolveMethodParameters(const AMethod: TRttiMethod; ARequest: THorseRequest; AResponse: THorseResponse): TArray<TValue>;
var
  parameters: TArray<TRttiParameter>;
  paramValues: TArray<TValue>;
  i: Integer;
  methodParam: TRttiParameter;
  paramType: TRttiType;
  paramTypeInfo: PTypeInfo;
  paramValue: TValue;
  interfaceService: TObject;
  jsonBody: TJSONValue;
  attr: TCustomAttribute;
  paramAttr, queryAttr, headerAttr, bodyAttr: TCustomAttribute;
  paramName, queryName, headerName: String;
  isParamResolved: Boolean;
  paramDict: TDictionary<String, String>;
  queryDict: TDictionary<String, String>;
  headerDict: TDictionary<String, String>;
  j: Integer;
begin
  parameters := AMethod.GetParameters;
  SetLength(paramValues, Length(parameters));

  for i := 0 to High(parameters) do
  begin
    methodParam := parameters[i];
    paramType := methodParam.ParamType;
    paramTypeInfo := paramType.Handle;
    isParamResolved := False;

    // Look for parameter attributes
    paramAttr := nil;
    queryAttr := nil;
    headerAttr := nil;
    bodyAttr := nil;

    for attr in methodParam.GetAttributes do
    begin
      if attr is Param then
        paramAttr := attr
      else if attr is Query then
        queryAttr := attr
      else if attr is Header then
        headerAttr := attr
      else if attr is Body then
        bodyAttr := attr;
    end;

    FLogger.Debug(Format('Resolving parameter %s of type %s', [methodParam.Name, paramType.Name]));

    try
      // Handle @Body attribute
      if bodyAttr <> nil then
      begin
        if paramType.TypeKind in [tkUString, tkString, tkLString, tkWString] then
        begin
          paramValues[i] := TValue.From<String>(ARequest.Body);
          FLogger.Debug(Format('Resolved body parameter %s as raw string', [methodParam.Name]));
          isParamResolved := True;
        end
        else if paramType.QualifiedName = 'System.JSON.TJSONObject' then
        begin
          if ARequest.Body <> '' then
          begin
            jsonBody := TJSONObject.ParseJSONValue(ARequest.Body);
            if jsonBody is TJSONObject then
            begin
              paramValues[i] := TValue.From<TJSONObject>(jsonBody as TJSONObject);
              FLogger.Debug(Format('Resolved body parameter %s as TJSONObject', [methodParam.Name]));
              isParamResolved := True;
            end;
          end;
        end;
      end

      // Handle @Param attribute
      else if paramAttr <> nil then
      begin
        // Check if we want all parameters or a specific one
        if Param(paramAttr).AllParams then
        begin
          // Return all route parameters as TDictionary<String, String>
          if paramType.QualifiedName = 'System.Generics.Collections.TDictionary<System.string,System.string>' then
          begin
            paramDict := TDictionary<String, String>.Create;
            try
              // Add all route parameters to dictionary
              for j := 0 to ARequest.Params.Count - 1 do
              begin
                paramDict.Add(ARequest.Params.Dictionary.Keys.ToArray[j], ARequest.Params.Dictionary.Keys.ToArray[j]);
              end;
              paramValues[i] := TValue.From<TDictionary<String, String>>(paramDict);
              FLogger.Debug(Format('Resolved all route parameters as TDictionary for %s', [methodParam.Name]));
              isParamResolved := True;
            except
              paramDict.Free;
              raise;
            end;
          end;
        end
        else
        begin
          // Get specific parameter
          paramName := Param(paramAttr).Name;
          if paramName = '' then
            paramName := methodParam.Name; // Use parameter name if attribute name is empty

          if ARequest.Params.Field(paramName).AsString <> '' then
          begin
            case paramType.TypeKind of
              tkInteger:
                begin
                  paramValues[i] := TValue.From<Integer>(StrToIntDef(ARequest.Params.Field(paramName).AsString, 0));
                  FLogger.Debug(Format('Resolved param %s from route parameter', [paramName]));
                  isParamResolved := True;
                end;
              tkUString, tkString, tkLString, tkWString:
                begin
                  paramValues[i] := TValue.From<String>(ARequest.Params.Field(paramName).AsString);
                  FLogger.Debug(Format('Resolved param %s from route parameter', [paramName]));
                  isParamResolved := True;
                end;
              tkFloat:
                begin
                  paramValues[i] := TValue.From<Double>(StrToFloatDef(ARequest.Params.Field(paramName).AsString, 0.0));
                  FLogger.Debug(Format('Resolved param %s from route parameter', [paramName]));
                  isParamResolved := True;
                end;
            end;
          end;
        end;
      end

      // Handle @Query attribute
      else if queryAttr <> nil then
      begin        // Check if we want all query parameters or a specific one
        if Query(queryAttr).AllParams then
        begin
          // Return all query parameters as TDictionary<String, String>
          if paramType.QualifiedName = 'System.Generics.Collections.TDictionary<System.string,System.string>' then
          begin
            queryDict := TDictionary<String, String>.Create;
            try
              // Add all query parameters to dictionary
              for j := 0 to ARequest.Query.Count - 1 do
              begin
                queryDict.Add(ARequest.Query.Dictionary.Keys.ToArray[j], ARequest.Query.Dictionary.Values.ToArray[j]);
              end;
              paramValues[i] := TValue.From<TDictionary<String, String>>(queryDict);
              FLogger.Debug(Format('Resolved all query parameters as TDictionary for %s', [methodParam.Name]));
              isParamResolved := True;
            except
              queryDict.Free;
              raise;
            end;
          end;
        end
        else
        begin
          // Get specific query parameter
          queryName := Query(queryAttr).Name;
          if queryName = '' then
            queryName := methodParam.Name; // Use parameter name if attribute name is empty

          if ARequest.Query.Field(queryName).AsString <> '' then
          begin
            case paramType.TypeKind of
              tkInteger:
                begin
                  paramValues[i] := TValue.From<Integer>(StrToIntDef(ARequest.Query.Field(queryName).AsString, 0));
                  FLogger.Debug(Format('Resolved query %s from query parameter', [queryName]));
                  isParamResolved := True;
                end;
              tkUString, tkString, tkLString, tkWString:
                begin
                  paramValues[i] := TValue.From<String>(ARequest.Query.Field(queryName).AsString);
                  FLogger.Debug(Format('Resolved query %s from query parameter', [queryName]));
                  isParamResolved := True;
                end;
              tkFloat:
                begin
                  paramValues[i] := TValue.From<Double>(StrToFloatDef(ARequest.Query.Field(queryName).AsString, 0.0));
                  FLogger.Debug(Format('Resolved query %s from query parameter', [queryName]));
                  isParamResolved := True;
                end;
            end;
          end;
        end;
      end

      // Handle @Header attribute
      else if headerAttr <> nil then
      begin        // Check if we want all headers or a specific one
        if Header(headerAttr).AllHeaders then
        begin
          // Return all headers as TDictionary<String, String>
          if paramType.QualifiedName = 'System.Generics.Collections.TDictionary<System.string,System.string>' then
          begin
            headerDict := TDictionary<String, String>.Create;
            try
              // Add all headers to dictionary
              for j := 0 to ARequest.Headers.Count - 1 do
              begin
                headerDict.Add(ARequest.Headers.Dictionary.Keys.ToArray[j], ARequest.Headers.Dictionary.Values.ToArray[j]);
              end;
              paramValues[i] := TValue.From<TDictionary<String, String>>(headerDict);
              FLogger.Debug(Format('Resolved all headers as TDictionary for %s', [methodParam.Name]));
              isParamResolved := True;
            except
              headerDict.Free;
              raise;
            end;
          end;
        end
        else
        begin
          // Get specific header
          headerName := Header(headerAttr).Name;
          if headerName = '' then
            headerName := methodParam.Name; // Use parameter name if attribute name is empty

          if ARequest.Headers[headerName] <> '' then
          begin
            case paramType.TypeKind of
              tkUString, tkString, tkLString, tkWString:
                begin
                  paramValues[i] := TValue.From<String>(ARequest.Headers[headerName]);
                  FLogger.Debug(Format('Resolved header %s from request header', [headerName]));
                  isParamResolved := True;
                end;
            end;
          end;
        end;
      end

      // Handle special framework types without attributes
      else if paramType.QualifiedName = 'Horse.THorseRequest' then
      begin
        paramValues[i] := TValue.From<THorseRequest>(ARequest);
        FLogger.Debug('Injected THorseRequest parameter');
        isParamResolved := True;
      end
      else if paramType.QualifiedName = 'Horse.THorseResponse' then
      begin
        paramValues[i] := TValue.From<THorseResponse>(AResponse);
        FLogger.Debug('Injected THorseResponse parameter');
        isParamResolved := True;
      end

      // Handle dependency injection for interfaces and classes
      else if paramType.TypeKind = tkInterface then
      begin
        try
          if paramType.QualifiedName = 'Nest4D.Logger.INest4DLogger' then
          begin
            paramValues[i] := TValue.From<INest4DLogger>(N4DInjector.GetInterface<INest4DLogger>);
            FLogger.Debug(Format('Resolved interface parameter %s via DI', [paramType.Name]));
            isParamResolved := True;
          end
          else
          begin
            interfaceService := N4DInjector.Get(paramTypeInfo);
            if interfaceService <> nil then
            begin
              paramValues[i] := TValue.From(interfaceService);
              FLogger.Debug(Format('Resolved interface parameter %s via DI as object', [paramType.Name]));
              isParamResolved := True;
            end;
          end;
        except
          on E: Exception do
            FLogger.Warn(Format('Could not resolve interface %s via DI: %s', [paramType.Name, E.Message]));
        end;
      end
      else if paramType.TypeKind = tkClass then
      begin
        try
          interfaceService := N4DInjector.Get(paramType.AsInstance.MetaclassType);
          if interfaceService <> nil then
          begin
            paramValues[i] := TValue.From(interfaceService);
            FLogger.Debug(Format('Resolved class parameter %s via DI', [paramType.Name]));
            isParamResolved := True;
          end;
        except
          on E: Exception do
            FLogger.Debug(Format('Could not resolve class %s via DI: %s', [paramType.Name, E.Message]));
        end;
      end

      // Fallback: try legacy parameter resolution (JSON body, form fields, route params)
      else if not isParamResolved then
      begin
        // Try JSON body or form fields
        if (ARequest.ContentFields.Count > 0) or (ARequest.Body <> '') then
        begin
          case paramType.TypeKind of
            tkInteger:
              begin
                if ARequest.Body <> '' then
                begin
                  jsonBody := TJSONObject.ParseJSONValue(ARequest.Body);
                  try                    if (jsonBody is TJSONObject) and (TJSONObject(jsonBody).GetValue(methodParam.Name) <> nil) then
                    begin
                      paramValues[i] := TValue.From<Integer>(TJSONObject(jsonBody).GetValue<Integer>(methodParam.Name));
                      FLogger.Debug(Format('Resolved integer parameter %s from JSON body', [methodParam.Name]));
                      isParamResolved := True;
                    end;
                  finally
                    if Assigned(jsonBody) then
                      jsonBody.Free;
                  end;
                end;                if not isParamResolved and (ARequest.ContentFields.Field(methodParam.Name).AsString <> '') then
                begin
                  paramValues[i] := TValue.From<Integer>(StrToIntDef(ARequest.ContentFields.Field(methodParam.Name).AsString, 0));
                  FLogger.Debug(Format('Resolved integer parameter %s from form field', [methodParam.Name]));
                  isParamResolved := True;
                end;
              end;

            tkUString, tkString, tkLString, tkWString:
              begin
                if ARequest.Body <> '' then
                begin
                  jsonBody := TJSONObject.ParseJSONValue(ARequest.Body);
                  try                    if (jsonBody is TJSONObject) and (TJSONObject(jsonBody).GetValue(methodParam.Name) <> nil) then
                    begin
                      paramValues[i] := TValue.From<String>(TJSONObject(jsonBody).GetValue<String>(methodParam.Name));
                      FLogger.Debug(Format('Resolved string parameter %s from JSON body', [methodParam.Name]));
                      isParamResolved := True;
                    end;
                  finally
                    if Assigned(jsonBody) then
                      jsonBody.Free;
                  end;
                end;                if not isParamResolved and (ARequest.ContentFields.Field(methodParam.Name).AsString <> '') then
                begin
                  paramValues[i] := TValue.From<String>(ARequest.ContentFields.Field(methodParam.Name).AsString);
                  FLogger.Debug(Format('Resolved string parameter %s from form field', [methodParam.Name]));
                  isParamResolved := True;
                end;
              end;

            tkFloat:
              begin
                if ARequest.Body <> '' then
                begin
                  jsonBody := TJSONObject.ParseJSONValue(ARequest.Body);
                  try
                    if (jsonBody is TJSONObject) and (TJSONObject(jsonBody).GetValue(methodParam.Name) <> nil) then
                    begin
                      paramValues[i] := TValue.From<Double>(TJSONObject(jsonBody).GetValue<Double>(methodParam.Name));
                      FLogger.Debug(Format('Resolved float parameter %s from JSON body', [methodParam.Name]));
                      isParamResolved := True;
                    end;
                  finally
                    if Assigned(jsonBody) then
                      jsonBody.Free;
                  end;
                end;

                if not isParamResolved and (ARequest.ContentFields.Field(methodParam.Name).AsString <> '') then
                begin
                  paramValues[i] := TValue.From<Double>(StrToFloatDef(ARequest.ContentFields.Field(methodParam.Name).AsString, 0.0));
                  FLogger.Debug(Format('Resolved float parameter %s from form field', [methodParam.Name]));
                  isParamResolved := True;
                end;
              end;
          end;
        end;

        // Try route parameters
        if not isParamResolved and (ARequest.Params.Field(methodParam.Name).AsString <> '') then
        begin
          case paramType.TypeKind of
            tkInteger:
              begin
                paramValues[i] := TValue.From<Integer>(StrToIntDef(ARequest.Params.Field(methodParam.Name).AsString, 0));
                FLogger.Debug(Format('Resolved integer parameter %s from route param', [methodParam.Name]));
                isParamResolved := True;
              end;
            tkUString, tkString, tkLString, tkWString:
              begin
                paramValues[i] := TValue.From<String>(ARequest.Params.Field(methodParam.Name).AsString);
                FLogger.Debug(Format('Resolved string parameter %s from route param', [methodParam.Name]));
                isParamResolved := True;
              end;
          end;
        end;
      end;

      // Default value for unresolved parameters
      if not isParamResolved then
      begin
        FLogger.Warn(Format('Could not resolve parameter %s of type %s, using default value', [methodParam.Name, paramType.Name]));
        paramValues[i] := TValue.Empty;
      end;

    except
      on E: Exception do
      begin
        FLogger.Error(Format('Error resolving parameter %s: %s', [methodParam.Name, E.Message]));
        paramValues[i] := TValue.Empty;
      end;
    end;
  end;

  Result := paramValues;
end;

procedure TNest4DApplication.RegisterControllerWithDependencies(AController: TClass);
var
  controllerType: TRttiType;
  constructorMethod: TRttiMethod;
  constructorParam: TRttiParameter;
  paramType: TRttiType;
  serviceClass: TClass;
begin
  FLogger.Debug('Analyzing dependencies for controller: ' + AController.ClassName);
  
  controllerType := FRttiContext.GetType(AController);
  if controllerType = nil then
    Exit;

  // Find constructor
  for constructorMethod in controllerType.GetMethods do
  begin
    if constructorMethod.IsConstructor and (constructorMethod.Name = 'Create') then
    begin
      // Analyze constructor parameters
      for constructorParam in constructorMethod.GetParameters do
      begin
        paramType := constructorParam.ParamType;

        // Register class dependencies
        if paramType.TypeKind = tkClass then
        begin
          serviceClass := paramType.AsInstance.MetaclassType;
          try
            if not N4DInjector.IsRegistered(serviceClass) then
            begin
              FLogger.Debug('Registering dependency service: ' + serviceClass.ClassName);
              N4DInjector.Singleton(serviceClass);
            end;
          except
            on E: Exception do
              FLogger.Warn('Could not register dependency ' + serviceClass.ClassName + ': ' + E.Message);
          end;
        end;

        // Interface dependencies are assumed to be already registered
        if paramType.TypeKind = tkInterface then
        begin
          FLogger.Debug('Interface dependency found: ' + paramType.Name);
        end;
      end;
      Break; // Only process first Create constructor
    end;
  end;
end;

function TNest4DApplication.ResolveConstructorParameters(const AClass: TClass): TConstructorParams;
var
  classType: TRttiType;
  constructorMethod: TRttiMethod;
  constructorParam: TRttiParameter;
  paramType: TRttiType;
  service: TObject;
  i: Integer;
begin
  SetLength(Result, 0);
  
  classType := FRttiContext.GetType(AClass);
  if classType = nil then
    Exit;

  // Find constructor
  for constructorMethod in classType.GetMethods do
  begin
    if constructorMethod.IsConstructor and (constructorMethod.Name = 'Create') then
    begin
      SetLength(Result, Length(constructorMethod.GetParameters));
      
      // Resolve each parameter
      for i := 0 to High(constructorMethod.GetParameters) do
      begin
        constructorParam := constructorMethod.GetParameters[i];
        paramType := constructorParam.ParamType;

        try
          if paramType.TypeKind = tkClass then
          begin
            service := N4DInjector.Get(paramType.AsInstance.MetaclassType);
            if service <> nil then
            begin
              Result[i] := TValue.From(service);
              FLogger.Debug(Format('Resolved constructor parameter %s via DI', [constructorParam.Name]));
            end
            else
            begin
              FLogger.Warn(Format('Could not resolve constructor parameter %s', [constructorParam.Name]));
              Result[i] := TValue.Empty;
            end;
          end
          else if paramType.TypeKind = tkInterface then
          begin
            // Try to get interface service
            service := N4DInjector.Get(paramType.Handle);
            if service <> nil then
            begin
              Result[i] := TValue.From(service);
              FLogger.Debug(Format('Resolved interface constructor parameter %s via DI', [constructorParam.Name]));
            end
            else
            begin
              FLogger.Warn(Format('Could not resolve interface constructor parameter %s', [constructorParam.Name]));
              Result[i] := TValue.Empty;
            end;
          end
          else
          begin
            FLogger.Warn(Format('Unsupported constructor parameter type: %s', [paramType.Name]));
            Result[i] := TValue.Empty;
          end;
        except
          on E: Exception do
          begin
            FLogger.Error(Format('Error resolving constructor parameter %s: %s', [constructorParam.Name, E.Message]));
            Result[i] := TValue.Empty;
          end;
        end;
      end;
      Break; // Only process first Create constructor
    end;
  end;
end;

function TNest4DApplication.CreateInstanceWithDependencies(const AClass: TClass): TObject;
var
  classType: TRttiType;
  constructorMethod: TRttiMethod;
  constructorParams: TArray<TValue>;
begin
  Result := nil;

  classType := FRttiContext.GetType(AClass);
  if classType = nil then
    Exit;

  // Find constructor
  for constructorMethod in classType.GetMethods do
  begin
    if constructorMethod.IsConstructor and (constructorMethod.Name = 'Create') then
    begin
      try
        if Length(constructorMethod.GetParameters) = 0 then
        begin
          // Parameterless constructor
          Result := constructorMethod.Invoke(classType.AsInstance.MetaclassType, []).AsObject;
        end
        else
        begin
          // Constructor with parameters - resolve them
          constructorParams := ResolveConstructorParameters(AClass);
          Result := constructorMethod.Invoke(classType.AsInstance.MetaclassType, constructorParams).AsObject;
        end;

        if Result <> nil then
        begin
          FLogger.Debug('Successfully created instance of: ' + AClass.ClassName);
          Exit;
        end;
      except
        on E: Exception do
          FLogger.Error('Failed to create instance of ' + AClass.ClassName + ': ' + E.Message);
      end;
      Break; // Only try first Create constructor
    end;
  end;

  if Result = nil then
    FLogger.Error('Could not find suitable constructor for: ' + AClass.ClassName);
end;

end.
