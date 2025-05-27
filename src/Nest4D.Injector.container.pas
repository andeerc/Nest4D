unit Nest4D.Injector.container;

interface

uses
  SysUtils,
  Generics.Collections,
  Nest4D.Injector.factory,
  Nest4D.Injector.service,
  Nest4D.Injector.abstract,
  Nest4D.Injector.events;

type
  TInjectorContainer = class(TInjectorAbstract)
  protected
    FInjectorFactory: TInjectorFactory;
    FRepositoryReference: TDictionary<string, TClass>;
    FRepositoryInterface: TDictionary<string, TPair<TClass, TGUID>>;
    FInstances: TObjectDictionary<string, TServiceData>;
    FInjectorEvents: TConstructorEvents;
  public
    constructor Create; virtual;
    destructor Destroy; override;
  end;

implementation

{ TInjectorFactory }

constructor TInjectorContainer.Create;
begin
  FInjectorFactory := TInjectorFactory.Create;
  FRepositoryReference := TDictionary<string, TClass>.Create;
  FRepositoryInterface := TDictionary<string, TPair<TClass, TGUID>>.Create;
  FInstances := TObjectDictionary<string, TServiceData>.Create([doOwnsValues]);
  FInjectorEvents := TConstructorEvents.Create([doOwnsValues]);
end;

destructor TInjectorContainer.Destroy;
begin
  FRepositoryReference.Free;
  FRepositoryInterface.Free;
  FInjectorEvents.Free;
  FInjectorFactory.Free;
  FInstances.Free;
  inherited;
end;

end.
