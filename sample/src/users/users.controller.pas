unit users.controller;

interface

uses
  System.Json,
  System.Generics.Collections,
  Nest4D.Attributes,
  Nest4D.Logger,
  users.service;

type
  [controller('/users')]
  TUsersController = Class
  private
    FLogger: INest4DLogger;
    FService: TUsersService;
  public
    [Get()]
    function getUsers: TJsonArray;

    constructor Create(ALogger: INest4DLogger; AService: TUsersService);
  End;

implementation

{ TUsersController }

constructor TUsersController.Create(ALogger: INest4DLogger; AService: TUsersService);
begin
  FLogger := ALogger;
  FService := AService;
end;

function TUsersController.getUsers: TJsonArray;
begin
  FLogger.Debug('Getting users');
  Result := FService.ListUsers;
end;

end.
