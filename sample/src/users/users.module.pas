unit users.module;

interface

uses
  Nest4D.Interfaces,
  Nest4D.Logger;

type
  TUsersModule = Class(TInterfacedObject, IN4DModule)
  public
    function Imports: TArray<TClass>;
    function Services: TArray<TClass>;
    function Controllers: TArray<TClass>;
    procedure Configure;
  End;

implementation

uses
  users.controller,
  users.service;

{ TUsersModule }

procedure TUsersModule.Configure;
begin
end;

function TUsersModule.Controllers: TArray<TClass>;
begin
  Result := [TUsersController];
end;

function TUsersModule.Imports: TArray<TClass>;
begin
  Result := [];
end;

function TUsersModule.Services: TArray<TClass>;
begin
  Result := [TUsersService];
end;

end.
