unit app.module;

interface

uses
  Nest4D.Interfaces,
  Nest4D.Logger;

type
  TAppModule = Class(TInterfacedObject, IN4DModule)
  public
    function Imports: TArray<TClass>;
    function Services: TArray<TClass>;
    function Controllers: TArray<TClass>;
    procedure Configure;
  End;

implementation

uses
  app.controller,
  app.service,
  users.module;

{ TAppModule }

function TAppModule.Controllers: TArray<TClass>;
begin
  Result := [TAppController];
end;

function TAppModule.Imports: TArray<TClass>;
begin
  Result := [TUsersModule];
end;

function TAppModule.Services: TArray<TClass>;
begin
  Result := [TAppService];
end;

procedure TAppModule.Configure;
begin
end;

end.
