unit Nest4D.Injector.service;

interface

uses
  Rtti,
  TypInfo,
  SysUtils,
  Generics.Collections,
  Nest4D.Injector.events;

type
  TInjectionMode     = (imSingleton, imFactory);
  TConstructorEvents = TObjectDictionary<string, TInjectorEvents>;

  TServiceData = class
  private
    FServiceClass : TClass;
    FInjectionMode: TInjectionMode;
    FInstance     : TObject;
    FInterface    : TValue;
    FGuid         : TGUID;
    function _FactoryInstance<T: class>(const AInjectorEvents: TConstructorEvents;
      const AParams: TConstructorParams = nil): T;
    function _FactoryInterface<I: IInterface>(const AKey: string; const AInjectorEvents: TConstructorEvents;
      const AParams: TConstructorParams = nil): TValue;
    function _Factory(const AParams: TConstructorParams): TValue;
    function FindBestConstructor(ATypeObject: TRttiType; const AParams: TConstructorParams): TRttiMethod;
    function ParametersMatch(AMethodParams: TArray<TRttiParameter>; const ASuppliedParams: TConstructorParams): Boolean;
    function IsParameterCompatible(AParam: TRttiParameter; AValue: TValue): Boolean;
  public
    constructor Create(const AServiceClass: TClass; const AInstance: TObject;
      const AInjectionMode: TInjectionMode); overload;
    constructor CreateInterface(const AServiceClass: TClass; const AGuid: TGUID; const AInterface: TValue;
      const AInjectionMode: TInjectionMode); overload;
    destructor Destroy; override;
    function ServiceClass: TClass;
    function InjectionMode: TInjectionMode;
    function AsInstance: TObject; overload;
    function GetInstance<T: class>(const AInjectorEvents: TConstructorEvents; const AParams: TConstructorParams)
      : T; overload;
    function GetInstance(const AInjectorEvents: TConstructorEvents; const AParams: TConstructorParams)
      : TObject; overload;
    function GetInterface<I: IInterface>(const AKey: string; const AInjectorEvents: TConstructorEvents;
      const AParams: TConstructorParams): I;
  end;

implementation

constructor TServiceData.Create(const AServiceClass: TClass; const AInstance: TObject;
  const AInjectionMode: TInjectionMode);
begin
  FServiceClass  := AServiceClass;
  FInstance      := AInstance;
  FInjectionMode := AInjectionMode;
end;

constructor TServiceData.CreateInterface(const AServiceClass: TClass; const AGuid: TGUID; const AInterface: TValue;
  const AInjectionMode: TInjectionMode);
begin
  FServiceClass  := AServiceClass;
  FGuid          := AGuid;
  FInterface     := AInterface;
  FInjectionMode := AInjectionMode;
end;

destructor TServiceData.Destroy;
begin
  FInterface := nil;
  if Assigned(FInstance) then
    FInstance.Free;
  inherited;
end;

function TServiceData._Factory(const AParams: TConstructorParams): TValue;
var
  LContext          : TRttiContext;
  LTypeObject       : TRttiType;
  LMetaClass        : TClass;
  LConstructorMethod: TRttiMethod;
  LValue            : TValue;
begin
  Result   := nil;
  LContext := TRttiContext.Create;
  try
    LTypeObject := LContext.GetType(FServiceClass);
    LMetaClass  := LTypeObject.AsInstance.MetaClassType;

    // Find the best matching constructor based on parameters
    LConstructorMethod := FindBestConstructor(LTypeObject, AParams);

    if LConstructorMethod = nil then
      raise Exception.CreateFmt('No suitable constructor found for class %s with %d parameters',
        [FServiceClass.ClassName, Length(AParams)]);

    LValue := LConstructorMethod.Invoke(LMetaClass, AParams);
    Result := LValue;
  finally
    LContext.Free;
  end;
end;

function TServiceData.FindBestConstructor(ATypeObject: TRttiType; const AParams: TConstructorParams): TRttiMethod;
var
  LMethods       : TArray<TRttiMethod>;
  LMethod        : TRttiMethod;
  LParameters    : TArray<TRttiParameter>;
  LParameterCount: Integer;
  LBestMatch     : TRttiMethod;
  I              : Integer;
begin
  Result          := nil;
  LBestMatch      := nil;
  LParameterCount := Length(AParams);

  // Get all methods (including constructors)
  LMethods := ATypeObject.GetMethods;

  for LMethod in LMethods do
  begin
    // Only consider constructors
    if not LMethod.IsConstructor then
      Continue;

    LParameters := LMethod.GetParameters;

    // Exact parameter count match
    if Length(LParameters) = LParameterCount then
    begin
      // If we have parameters, try to match types
      if LParameterCount > 0 then
      begin
        if ParametersMatch(LParameters, AParams) then
        begin
          Result := LMethod;
          Exit; // Exact match found
        end;
      end
      else
      begin
        // Parameterless constructor
        Result := LMethod;
        Exit;
      end;
    end
    // Keep track of parameterless constructor as fallback
    else
      if (Length(LParameters) = 0) and (LBestMatch = nil) then
      begin
        LBestMatch := LMethod;
      end;
  end;

  // If no exact match, use parameterless constructor if available
  if (Result = nil) and (LBestMatch <> nil) and (LParameterCount = 0) then
    Result := LBestMatch;
end;

function TServiceData.ParametersMatch(AMethodParams: TArray<TRttiParameter>;
  const ASuppliedParams: TConstructorParams): Boolean;
var
  I: Integer;
begin
  Result := False;

  if Length(AMethodParams) <> Length(ASuppliedParams) then
    Exit;

  for I := 0 to High(AMethodParams) do
  begin
    // Basic type compatibility check
    if not IsParameterCompatible(AMethodParams[I], ASuppliedParams[I]) then
      Exit;
  end;

  Result := True;
end;

function TServiceData.IsParameterCompatible(AParam: TRttiParameter; AValue: TValue): Boolean;
var
  LParamType: TRttiType;
  outCast: TValue;
begin
  Result := False;

  if not AValue.IsEmpty then
  begin
    LParamType := AParam.ParamType;

    // Check if types are directly compatible
    if AValue.TypeInfo = LParamType.Handle then
    begin
      Result := True;
      Exit;
    end;

    // Check for common type conversions
    case LParamType.TypeKind of
      tkClass:
        begin
          // For class types, check if value is assignable
          if AValue.IsObject and AValue.AsObject.InheritsFrom(LParamType.AsInstance.MetaClassType) then
            Result := True;
        end;
      tkInterface:
        begin
          // For interface types, try to cast
          if AValue.IsObject and Supports(AValue.AsObject, TRttiInterfaceType(LParamType).GUID) then
            Result := True;
        end;
      tkRecord:
        begin
          // For record types, check exact type match
          Result := AValue.TypeInfo = LParamType.Handle;
        end;
    else
      begin
        // For other types, try TValue conversion
        try
          AValue.TryCast(LParamType.Handle, outCast);
        except
          Result := False;
        end;
      end;
    end;
  end;
end;

function TServiceData._FactoryInstance<T>(const AInjectorEvents: TConstructorEvents;
  const AParams: TConstructorParams): T;
var
  LResult      : TValue;
  LOnCreate    : TProc<T>;
  LOnParams    : TFunc<TConstructorParams>;
  LResultParams: TConstructorParams;
begin
  Result        := nil;
  LResultParams := [];
  if AInjectorEvents.ContainsKey(T.ClassName) then
  begin
    LOnParams := TFunc<TConstructorParams>(AInjectorEvents.Items[T.ClassName].OnParams);
    if Assigned(LOnParams) then
      LResultParams := LOnParams();
  end
  else
  begin
    if Length(AParams) > 0 then
      LResultParams := AParams;
  end;
  LResult := _Factory(LResultParams);
  if not LResult.IsObjectInstance then
    Exit;
  Result := LResult.AsType<T>;
  // OnCreate
  if AInjectorEvents.ContainsKey(T.ClassName) then
  begin
    LOnCreate := TProc<T>(AInjectorEvents.Items[T.ClassName].OnCreate);
    if Assigned(LOnCreate) then
      LOnCreate(Result);
  end;
end;

function TServiceData._FactoryInterface<I>(const AKey: string; const AInjectorEvents: TConstructorEvents;
  const AParams: TConstructorParams): TValue;
var
  LResult      : TValue;
  LOnCreate    : TProc<I>;
  LOnParams    : TFunc<TConstructorParams>;
  LResultParams: TConstructorParams;
begin
  Result        := nil;
  LResultParams := [];
  if AInjectorEvents.ContainsKey(AKey) then
  begin
    LOnParams := TFunc<TConstructorParams>(AInjectorEvents.Items[AKey].OnParams);
    if Assigned(LOnParams) then
      LResultParams := LOnParams();
  end
  else
  begin
    if Length(AParams) > 0 then
      LResultParams := AParams;
  end;
  LResult := _Factory(LResultParams);
  if not LResult.IsObjectInstance then
    Exit;
  // OnCreate
  if AInjectorEvents.ContainsKey(AKey) then
  begin
    LOnCreate := TProc<I>(AInjectorEvents.Items[AKey].OnCreate);
    if Assigned(LOnCreate) then
      LOnCreate(Result.AsType<I>);
  end;
  Result := LResult;
end;

function TServiceData.AsInstance: TObject;
begin
  Result := FInstance;
end;

function TServiceData.GetInstance<T>(const AInjectorEvents: TConstructorEvents; const AParams: TConstructorParams): T;
begin
  Result := nil;
  case FInjectionMode of
    imSingleton:
      begin
        if not Assigned(FInstance) then
          FInstance := _FactoryInstance<T>(AInjectorEvents, AParams);
        Result      := FInstance as T;
      end;
    imFactory:
      Result := _FactoryInstance<T>(AInjectorEvents, AParams);
  end;
end;

function TServiceData.GetInstance(const AInjectorEvents: TConstructorEvents; const AParams: TConstructorParams)
  : TObject;
var
  LResult      : TValue;
  LOnCreate    : TProc<TObject>;
  LOnParams    : TFunc<TConstructorParams>;
  LResultParams: TConstructorParams;
begin
  Result := nil;
  case FInjectionMode of
    imSingleton:
      begin
        if not Assigned(FInstance) then
        begin
          // Use the same parameter resolution mechanism as the generic version
          LResultParams := [];
          if AInjectorEvents.ContainsKey(FServiceClass.ClassName) then
          begin
            LOnParams := TFunc<TConstructorParams>(AInjectorEvents.Items[FServiceClass.ClassName].OnParams);
            if Assigned(LOnParams) then
              LResultParams := LOnParams();
          end
          else
          begin
            if Length(AParams) > 0 then
              LResultParams := AParams;
          end;

          LResult := _Factory(LResultParams);
          if LResult.IsObjectInstance then
          begin
            FInstance := LResult.AsObject;

            // OnCreate
            if AInjectorEvents.ContainsKey(FServiceClass.ClassName) then
            begin
              LOnCreate := TProc<TObject>(AInjectorEvents.Items[FServiceClass.ClassName].OnCreate);
              if Assigned(LOnCreate) then
                LOnCreate(FInstance);
            end;
          end;
        end;
        Result := FInstance;
      end;
    imFactory:
      begin
        // Use parameter resolution for factory instances too
        LResultParams := [];
        if AInjectorEvents.ContainsKey(FServiceClass.ClassName) then
        begin
          LOnParams := TFunc<TConstructorParams>(AInjectorEvents.Items[FServiceClass.ClassName].OnParams);
          if Assigned(LOnParams) then
            LResultParams := LOnParams();
        end
        else
        begin
          if Length(AParams) > 0 then
            LResultParams := AParams;
        end;

        LResult := _Factory(LResultParams);
        if LResult.IsObjectInstance then
        begin
          Result := LResult.AsObject;

          // OnCreate
          if AInjectorEvents.ContainsKey(FServiceClass.ClassName) then
          begin
            LOnCreate := TProc<TObject>(AInjectorEvents.Items[FServiceClass.ClassName].OnCreate);
            if Assigned(LOnCreate) then
              LOnCreate(Result);
          end;
        end;
      end;
  end;
end;

function TServiceData.GetInterface<I>(const AKey: string; const AInjectorEvents: TConstructorEvents;
  const AParams: TConstructorParams): I;
begin
  Result := nil;
  if not FInterface.IsObjectInstance then
  begin
    try
      FInterface := _FactoryInterface<I>(AKey, AInjectorEvents, AParams);
    except
      FInterface := TValue.From(nil);
      raise;
    end;
  end;
  Result := FInterface.AsType<I>;
end;

function TServiceData.InjectionMode: TInjectionMode;
begin
  Result := FInjectionMode;
end;

function TServiceData.ServiceClass: TClass;
begin
  Result := FServiceClass;
end;

end.
