unit Nest4D.Injector;

interface

uses
  Rtti,
  TypInfo,
  SysUtils,
  Generics.Collections,
  Nest4D.Injector.service,
  Nest4D.Injector.container,
  Nest4D.Injector.events;

type
  TConstructorParams = Nest4D.Injector.events.TConstructorParams;

  PN4DInjector = ^TN4DInjector;
  TN4DInjector = class(TInjectorContainer)
  strict private
    procedure _AddEvents<T>(const AClassName: string;
      const AOnCreate: TProc<T>;
      const AOnDestroy: TProc<T>;
      const AOnConstructorParams: TConstructorCallback = nil);
    function _ResolverInterfaceType(const AHandle: PTypeInfo;
      const AGUID: TGUID): TValue;
    function _ResolverParams(const AClass: TClass): TConstructorParams; overload;
  protected
    function GetTry<T: class, constructor>(const ATag: string = ''): T;
    function GetInterfaceTry<I: IInterface>(const ATag: string = ''): I;
  public
    procedure AddInjector(const ATag: string;
      const AInstance: TN4DInjector);
    procedure AddInstance<T: class>(const AInstance: TObject);    procedure Singleton<T: class, constructor>(
      const AOnCreate: TProc<T> = nil;
      const AOnDestroy: TProc<T> = nil;
      const AOnConstructorParams: TConstructorCallback = nil); overload;
    procedure Singleton(const ATypeInfo: PTypeInfo); overload;
    procedure Singleton(const AClass: TClass); overload;
    procedure Singleton(const AClass: TClass;
      const AOnConstructorParams: TConstructorCallback); overload;
    procedure SingletonLazy<T: class>(
      const AOnCreate: TProc<T> = nil;
      const AOnDestroy: TProc<T> = nil;
      const AOnConstructorParams: TConstructorCallback = nil);
    procedure SingletonInterface<I: IInterface; T: class, constructor>(
      const ATag: string = '';
      const AOnCreate: TProc<T> = nil;
      const AOnDestroy: TProc<T> = nil;
      const AOnConstructorParams: TConstructorCallback = nil);
    procedure Factory<T: class, constructor>(
      const AOnCreate: TProc<T> = nil;
      const AOnDestroy: TProc<T> = nil;
      const AOnConstructorParams: TConstructorCallback = nil);
    procedure Remove<T: class>(const ATag: string = '');
    function GetInstances: TObjectDictionary<string, TServiceData>;    function Get<T: class, constructor>(const ATag: String = ''): T; overload;
    function GetInterface<I: IInterface>(const ATag: String = ''): I; overload;
    function Get(const ATypeInfo: PTypeInfo): TObject; overload;
    function Get(const AClass: TClass): TObject; overload;
    function IsRegistered(const AClass: TClass): Boolean; overload;
    function IsRegistered(const AClassName: string): Boolean; overload;
  end;

function Injector: TN4DInjector;

var
  N4DInjector: PN4DInjector = nil;

implementation

{ TN4DInjector }

function Injector: TN4DInjector;
begin
  Result := N4DInjector^;
end;

procedure TN4DInjector.Singleton<T>(const AOnCreate: TProc<T>;
  const AOnDestroy: TProc<T>;
  const AOnConstructorParams: TConstructorCallback);
var
  LValue: TServiceData;
  LResult: TObject;
  LKey: string;
begin
  LKey := T.ClassName;
  if FRepositoryReference.ContainsKey(LKey) then
    exit;
  FRepositoryReference.Add(LKey, TServiceData);
  // Singleton
  LValue := FInjectorFactory.FactorySingleton<T>();
  FInstances.Add(LKey, LValue);
  // Events
  _AddEvents<T>(LKey, AOnCreate, AOnDestroy, AOnConstructorParams);
end;

procedure TN4DInjector.SingletonInterface<I, T>(const ATag: string;
  const AOnCreate: TProc<T>;
  const AOnDestroy: TProc<T>;
  const AOnConstructorParams: TConstructorCallback);
var
  LGuid: TGUID;
  LGuidstring: string;
begin
  LGuid := GetTypeData(TypeInfo(I)).Guid;
  LGuidstring := GUIDTostring(LGuid);
  if ATag <> '' then
    LGuidstring := ATag;
  if FRepositoryInterface.ContainsKey(LGuidstring) then
    raise Exception.Create(Format('Interface %s registered!', [T.ClassName]));
  FRepositoryInterface.Add(LGuidstring, TPair<TClass, TGUID>.Create(T, LGuid));
  // Events
  _AddEvents<T>(LGuidstring, AOnCreate, AOnDestroy, AOnConstructorParams);
end;

procedure TN4DInjector.SingletonLazy<T>(const AOnCreate: TProc<T>;
  const AOnDestroy: TProc<T>;
  const AOnConstructorParams: TConstructorCallback);
begin
  if FRepositoryReference.ContainsKey(T.ClassName) then
    raise Exception.Create(Format('Class %s registered!', [T.ClassName]));
  FRepositoryReference.Add(T.ClassName, TServiceData);
  // Events
  _AddEvents<T>(T.ClassName, AOnCreate, AOnDestroy, AOnConstructorParams);
end;

procedure TN4DInjector.AddInjector(const ATag: string;
  const AInstance: TN4DInjector);
var
  LValue: TServiceData;
begin
  if FRepositoryReference.ContainsKey(ATag) then
    raise Exception.Create(Format('Injector %s registered!', [ATag]));
  FRepositoryReference.Add(ATag, TServiceData);
  LValue := TServiceData.Create(TN4DInjector,
                                AInstance,
                                TInjectionMode.imSingleton);
  FInstances.Add(ATag, LValue);
end;

procedure TN4DInjector.AddInstance<T>(const AInstance: TObject);
var
  LValue: TServiceData;
begin
  if FRepositoryReference.ContainsKey(T.ClassName) then
    raise Exception.Create(Format('Instance %s registered!', [AInstance.ClassName]));
  FRepositoryReference.Add(T.ClassName, TServiceData);
  // Factory
  LValue := TServiceData.Create(T, AInstance, TInjectionMode.imSingleton);
  FInstances.Add(T.ClassName, LValue);
end;

procedure TN4DInjector.Singleton(const ATypeInfo: PTypeInfo);
var
  LValue: TServiceData;
  LClassName: string;
begin
  if ATypeInfo = nil then
    raise Exception.Create('TypeInfo não pode ser nil');

  LClassName := string(ATypeInfo.Name);

  if FRepositoryReference.ContainsKey(LClassName) then
    raise Exception.Create(Format('Class %s registered!', [LClassName]));

  FRepositoryReference.Add(LClassName, TServiceData);

  // Singleton
  LValue := FInjectorFactory.FactorySingleton(GetTypeData(ATypeInfo).ClassType);
  FInstances.Add(LClassName, LValue);
end;

procedure TN4DInjector.Singleton(const AClass: TClass);
var
  LValue: TServiceData;
  LClassName: string;
begin
  if AClass = nil then
    raise Exception.Create('Class não pode ser nil');

  LClassName := AClass.ClassName;

  if FRepositoryReference.ContainsKey(LClassName) then
    exit;
//    raise Exception.Create(Format('Class %s registered!', [LClassName]));

  FRepositoryReference.Add(LClassName, TServiceData);

  // Singleton
  LValue := FInjectorFactory.FactorySingleton(AClass);
  FInstances.Add(LClassName, LValue);
end;

procedure TN4DInjector.Singleton(const AClass: TClass;
  const AOnConstructorParams: TConstructorCallback);
var
  LValue: TServiceData;
  LClassName: string;
  LEvents: TInjectorEvents;
begin
  if AClass = nil then
    raise Exception.Create('Class não pode ser nil');

  LClassName := AClass.ClassName;

  if FRepositoryReference.ContainsKey(LClassName) then
    exit;
//    raise Exception.Create(Format('Class %s registered!', [LClassName]));

  FRepositoryReference.Add(LClassName, TServiceData);

  // Singleton
  LValue := FInjectorFactory.FactorySingleton(AClass);
  FInstances.Add(LClassName, LValue);

  // Events - Add constructor callback
  if Assigned(AOnConstructorParams) then
  begin
    if FInjectorEvents.ContainsKey(LClassName) then
      Exit;
    LEvents := TInjectorEvents.Create;
    LEvents.OnParams := AOnConstructorParams;
    FInjectorEvents.AddOrSetValue(LClassName, LEvents);
  end;
end;

procedure TN4DInjector.Factory<T>(const AOnCreate: TProc<T>;
  const AOnDestroy: TProc<T>;
  const AOnConstructorParams: TConstructorCallback);
var
  LValue: TServiceData;
begin
  if FRepositoryReference.ContainsKey(T.ClassName) then
    raise Exception.Create(Format('Class %s registered!', [T.ClassName]));
  FRepositoryReference.Add(T.ClassName, TServiceData);
  // Factory
  LValue := FInjectorFactory.Factory<T>();
  FInstances.Add(T.ClassName, LValue);
  // Events
  _AddEvents<T>(T.ClassName, AOnCreate, AOnDestroy, AOnConstructorParams);
end;

function TN4DInjector.GetInstances: TObjectDictionary<string, TServiceData>;
begin
  Result := FInstances;
end;

function TN4DInjector.Get<T>(const ATag: String): T;
var
  LItem: TServiceData;
begin
  Result := GetTry<T>(ATag);
  if Result <> nil then
    Exit;
  for LItem in GetInstances.Values do
  begin
    if LItem.AsInstance is TN4DInjector then
    begin
      Result := TN4DInjector(LItem.AsInstance).GetTry<T>(ATag);
      if Result <> nil then
        Exit;
    end;
  end;
end;

function TN4DInjector.Get(const ATypeInfo: PTypeInfo): TObject;
var
  LClassName: string;
  LItem: TServiceData;
  LResult: TObject;
  LParams: TConstructorParams;
  LTypeClass: TClass;
begin
  Result := nil;
  if ATypeInfo = nil then
    Exit;

  LClassName := string(ATypeInfo.Name);

  // Primeiro tenta buscar pelo nome do tipo
  if FInstances.TryGetValue(LClassName, LItem) then
  begin
    // Se a instância já está criada, retorne-a
    if LItem.AsInstance <> nil then
    begin
      Result := LItem.AsInstance;
      Exit;
    end;

    // Se não, crie uma nova instância
    LParams := [];
    if (LItem.AsInstance = nil) and (FInjectorEvents.Count = 0) then
      LParams := _ResolverParams(LItem.ServiceClass);

    Result := LItem.GetInstance(FInjectorEvents, LParams);
    Exit;
  end;

  // Tenta buscar no container pai/filhos
  for LItem in GetInstances.Values do
  begin
    if LItem.AsInstance is TN4DInjector then
    begin
      LResult := TN4DInjector(LItem.AsInstance).Get(ATypeInfo);
      if LResult <> nil then
      begin
        Result := LResult;
        Exit;
      end;
    end;
  end;

  // Se chegou aqui, o tipo não foi encontrado. Vamos tentar registrá-lo automaticamente
  try
    // Verificar se é um tipo de classe válido
    LTypeClass := GetTypeData(ATypeInfo).ClassType;
    if LTypeClass <> nil then
    begin
      // Registrar o tipo automaticamente como singleton
      Singleton(ATypeInfo);

      // Tentar obter a instância novamente
      if FInstances.TryGetValue(LClassName, LItem) then
      begin
        LParams := [];
        if (LItem.AsInstance = nil) and (FInjectorEvents.Count = 0) then
          LParams := _ResolverParams(LItem.ServiceClass);

        Result := LItem.GetInstance(FInjectorEvents, LParams);
      end;
    end;
  except
    on E: Exception do
    begin
      // Só registrar o erro, mas não repassar a exceção
      // para manter a compatibilidade com o comportamento anterior
      WriteLn('Erro ao registrar classe automaticamente: ' + E.Message);
    end;
  end;
end;

function TN4DInjector.Get(const AClass: TClass): TObject;
var
  LClassName: string;
  LItem: TServiceData;
  LResult: TObject;
  LParams: TConstructorParams;
begin
  Result := nil;
  if AClass = nil then
    Exit;

  LClassName := AClass.ClassName;

  // Primeiro tenta buscar pelo nome da classe
  if FInstances.TryGetValue(LClassName, LItem) then
  begin
    // Se a instância já está criada, retorne-a
    if LItem.AsInstance <> nil then
    begin
      Result := LItem.AsInstance;
      Exit;
    end;

    // Se não, crie uma nova instância
    LParams := [];
    if (LItem.AsInstance = nil) and (FInjectorEvents.Count = 0) then
      LParams := _ResolverParams(LItem.ServiceClass);

    Result := LItem.GetInstance(FInjectorEvents, LParams);
    Exit;
  end;

  // Tenta buscar no container pai/filhos
  for LItem in GetInstances.Values do
  begin
    if LItem.AsInstance is TN4DInjector then
    begin
      LResult := TN4DInjector(LItem.AsInstance).Get(AClass);
      if LResult <> nil then
      begin
        Result := LResult;
        Exit;
      end;
    end;
  end;

  // Se chegou aqui, o tipo não foi encontrado. Vamos tentar registrá-lo automaticamente
  try
    // Registrar o tipo automaticamente como singleton
    Singleton(AClass);

    // Tentar obter a instância novamente
    if FInstances.TryGetValue(LClassName, LItem) then
    begin
      LParams := [];
      if (LItem.AsInstance = nil) and (FInjectorEvents.Count = 0) then
        LParams := _ResolverParams(LItem.ServiceClass);

      Result := LItem.GetInstance(FInjectorEvents, LParams);
    end;
  except
    on E: Exception do
    begin
      // Só registrar o erro, mas não repassar a exceção
      // para manter a compatibilidade com o comportamento anterior
      WriteLn('Erro ao registrar classe automaticamente: ' + E.Message);
    end;
  end;
end;

function TN4DInjector.GetTry<T>(const ATag: string): T;
var
  LValue: TServiceData;
  LParams: TConstructorParams;
  LTag: string;
begin
  Result := nil;
  LTag := ATag;
  if LTag = '' then
    LTag := T.ClassName;
  if not FRepositoryReference.ContainsKey(LTag) then
    Exit;
  // Lazy
  LParams := [];
  if not FInstances.ContainsKey(LTag) then
  begin
    LValue := FInjectorFactory.FactorySingleton<T>;
    FInstances.Add(LTag, LValue);
  end;
  if (FInstances.Items[LTag].AsInstance = nil) and (FInjectorEvents.Count = 0) then
    LParams := _ResolverParams(FInstances.Items[LTag].ServiceClass);
  Result := T(FInstances.Items[LTag].GetInstance(FInjectorEvents, LParams));
end;

function TN4DInjector.GetInterface<I>(const ATag: String): I;
var
  LItem: TServiceData;
begin
  Result := GetInterfaceTry<I>(ATag);
  if Result <> nil then
    Exit;
  for LItem in GetInstances.Values do
  begin
    if LItem.AsInstance is TN4DInjector then
    begin
      Result := TN4DInjector(LItem.AsInstance).GetInterfaceTry<I>(ATag);
      if Result <> nil then
        Exit;
    end;
  end;
end;

function TN4DInjector.GetInterfaceTry<I>(const ATag: string): I;
var
  LServiceData: TServiceData;
  LParams: TConstructorParams;
  LGuid: TGUID;
  LGuidstring: string;
  LKey: TClass;
  LValue: TGUID;
begin
  Result := nil;
  LGuid := GetTypeData(TypeInfo(I)).Guid;
  LGuidstring := GUIDTostring(LGuid);
  if ATag <> '' then
    LGuidstring := ATag;
  if not FRepositoryInterface.ContainsKey(LGuidstring) then
    Exit;
  // SingletonLazy
  LParams := [];
  if not FInstances.ContainsKey(LGuidstring) then
  begin
    LKey := FRepositoryInterface.Items[LGuidstring].Key;
    LValue := FRepositoryInterface.Items[LGuidstring].Value;
    LServiceData := FInjectorFactory.FactoryInterface<I>(LKey, LValue);
    FInstances.Add(LGuidstring, LServiceData);
  end;
  if (FInstances.Items[LGuidstring].AsInstance = nil) and (FInjectorEvents.Count = 0) then
    LParams := _ResolverParams(FInstances.Items[LGuidstring].ServiceClass);
  Result := FInstances.Items[LGuidstring].GetInterface<I>(LGuidstring, FInjectorEvents, LParams);
end;

function TN4DInjector.IsRegistered(const AClass: TClass): Boolean;
begin
  Result := False;
  if AClass = nil then
    Exit;
  Result := FRepositoryReference.ContainsKey(AClass.ClassName);
end;

function TN4DInjector.IsRegistered(const AClassName: string): Boolean;
begin
  Result := FRepositoryReference.ContainsKey(AClassName);
end;

procedure TN4DInjector.Remove<T>(const ATag: string);
var
  LTag: string;
  LOnDestroy: TProc<T>;
begin
  LTag := ATag;
  if LTag = '' then
    LTag := T.ClassName;
  // OnDestroy
  if FInjectorEvents.ContainsKey(LTag) then
  begin
    LOnDestroy := TProc<T>(FInjectorEvents.Items[LTag].OnDestroy);
    if Assigned(LOnDestroy) then
      LOnDestroy(T(FInstances.Items[LTag].AsInstance));
  end;
  if FRepositoryReference.ContainsKey(LTag) then
    FRepositoryReference.Remove(LTag);
  if FRepositoryInterface.ContainsKey(LTag) then
    FRepositoryInterface.Remove(LTag);
  if FInjectorEvents.ContainsKey(LTag) then
    FInjectorEvents.Remove(LTag);
  if FInstances.ContainsKey(LTag) then
    FInstances.Remove(LTag);
end;

procedure TN4DInjector._AddEvents<T>(const AClassName: string;
  const AOnCreate: TProc<T>;
  const AOnDestroy: TProc<T>;
  const AOnConstructorParams: TConstructorCallback);
var
  LEvents: TInjectorEvents;
begin
  if (not Assigned(AOnDestroy)) and (not Assigned(AOnCreate)) and
     (not Assigned(AOnConstructorParams)) then
    Exit;
  if FInjectorEvents.ContainsKey(AClassname) then
    Exit;
  LEvents := TInjectorEvents.Create;
  LEvents.OnDestroy := TProc<TObject>(AOnDestroy);
  LEvents.OnCreate := TProc<TObject>(AOnCreate);
  LEvents.OnParams := AOnConstructorParams;
  //
  FInjectorEvents.AddOrSetValue(AClassname, LEvents);
end;

function TN4DInjector._ResolverInterfaceType(const AHandle: PTypeInfo;
  const AGUID: TGUID): TValue;
var
  LValue: TValue;
  LResult: TValue;
  LInterface: IInterface;
begin
  Result := TValue.From(nil);
  LValue := TValue.From(GetInterface<IInterface>(GUIDToString(AGUID)));
  if Supports(LValue.AsInterface, AGUID, LInterface) then
  begin
    TValue.Make(@LInterface, AHandle, LResult);
    Result := LResult;
  end;
end;

function TN4DInjector._ResolverParams(const AClass: TClass): TConstructorParams;

  function ToStringParams(const AValues: TArray<TValue>): string;
  var
    LIndex: Integer;
  begin
    Result := '';
    for LIndex := 0 to High(AValues) do
    begin
      Result := Result + AValues[LIndex].ToString;
      if LIndex < High(AValues) then
        Result := Result + ', ';
    end;
  end;

var
  LRttiContext: TRttiContext;
  LRttiType: TRttiType;
  LRttiMethod: TRttiMethod;
  LParameter: TRttiParameter;
  LParameterType: TRttiType;
  LInterfaceType: TRttiInterfaceType;
  LParameters: TArray<TRttiParameter>;
  LParameterValues: TArray<TValue>;
  LFor: integer;
begin
  Result := [];
  LRttiContext := TRttiContext.Create;
  try
    LRttiType := LRttiContext.GetType(AClass);
    if not Assigned(LRttiType) then
      exit;
    LRttiMethod := LRttiType.GetMethod('Create');
    LParameters := LRttiMethod.GetParameters;
    SetLength(LParameterValues, Length(LParameters));
    try
      for LFor := 0 to High(LParameters) do
      begin
        LParameter := LParameters[LFor];
        LParameterType := LParameter.ParamType;
        case LParameterType.TypeKind of
          tkClass, tkClassRef:
          begin
            LParameterValues[LFor] := TValue.From(Get<TObject>(String(LParameterType.Handle.Name)))
                                            .Cast(LParameterType.Handle);
          end;
          tkInterface:
          begin
            LInterfaceType := LRttiContext.GetType(LParameterType.Handle) as TRttiInterfaceType;
            LParameterValues[LFor] := _ResolverInterfaceType(LParameterType.Handle,
                                                             LInterfaceType.GUID);
          end;
          else
            LParameterValues[LFor] := TValue.From(nil);
        end;
      end;
    except
      on E: Exception do
        raise Exception.Create(E.Message + ' => ' + ToStringParams(LParameterValues));
    end;
    Result := LParameterValues;
  finally
    LRttiContext.Free;
  end;
end;

initialization
  New(N4DInjector);
  N4DInjector^ := TN4DInjector.Create;

finalization
  if Assigned(N4DInjector) then
  begin
    N4DInjector^.Free;
    Dispose(N4DInjector);
  end;

end.
