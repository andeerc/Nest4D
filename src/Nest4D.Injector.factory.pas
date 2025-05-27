unit Nest4D.Injector.factory;

interface

uses
  Rtti,
  SysUtils,
  Nest4D.Injector.service;

type
  TInjectorFactory = class
  private
    function _FactoryInternal(const Args: TArray<TValue>): TServiceData;
  public
    function FactorySingleton<T: class, constructor>(): TServiceData; overload;
    function FactorySingleton(const AClass: TClass): TServiceData; overload; // Adicionado para aceitar TClass diretamente
    function FactoryInterface<I: IInterface>(const AClass: TClass;
      const AGuid: TGUID): TServiceData;
    function Factory<T: class, constructor>(): TServiceData;
  end;

implementation

{ TInjectorCore }

function TInjectorFactory.Factory<T>(): TServiceData;
var
  LArgs: TArray<TValue>;
begin
  SetLength(LArgs, 3);
  LArgs[0] := TValue.From<TClass>(T);
  LArgs[1] := TValue.From<TObject>(nil);
  LArgs[2] := TValue.From<TInjectionMode>(TInjectionMode.imFactory);
  Result := _FactoryInternal(LArgs);
end;

function TInjectorFactory.FactoryInterface<I>(const AClass: TClass;
  const AGuid: TGUID): TServiceData;
var
  LArgs: TArray<TValue>;
begin
  SetLength(LArgs, 4);
  LArgs[0] := TValue.From<TClass>(AClass);
  LArgs[1] := TValue.From<TGUID>(AGuid);
  LArgs[2] := TValue.From<TValue>(TValue.Empty);
  LArgs[3] := TValue.From<TInjectionMode>(TInjectionMode.imSingleton);
  Result := _FactoryInternal(LArgs);
end;

function TInjectorFactory.FactorySingleton<T>(): TServiceData;
var
  LArgs: TArray<TValue>;
begin
  SetLength(LArgs, 3);
  LArgs[0] := TValue.From<TClass>(T);
  LArgs[1] := TValue.From<TObject>(nil);
  LArgs[2] := TValue.From<TInjectionMode>(TInjectionMode.imSingleton);
  Result := _FactoryInternal(LArgs);
end;

function TInjectorFactory.FactorySingleton(const AClass: TClass): TServiceData; // Adicionado para aceitar TClass diretamente
var
  LArgs: TArray<TValue>;
begin
  SetLength(LArgs, 3);
  LArgs[0] := TValue.From<TClass>(AClass);
  LArgs[1] := TValue.From<TObject>(nil);
  LArgs[2] := TValue.From<TInjectionMode>(TInjectionMode.imSingleton);
  Result := _FactoryInternal(LArgs);
end;

function TInjectorFactory._FactoryInternal(const Args: TArray<TValue>): TServiceData;
var
  LContext: TRttiContext;
  LTypeService: TRttiType;
  LConstructorMethod: TRttiMethod;
  LInstance: TValue;
begin
  LContext := TRttiContext.Create;
  try
    LTypeService := LContext.GetType(TServiceData);
    if Length(Args) = 3 then
      LConstructorMethod := LTypeService.GetMethod('Create')
    else
      LConstructorMethod := LTypeService.GetMethod('CreateInterface');
    LInstance := LConstructorMethod.Invoke(LTypeService.AsInstance.MetaClassType, Args);
    Result := TServiceData(LInstance.AsObject);
  finally
    LContext.Free;
  end;
end;

end.
