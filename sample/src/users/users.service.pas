unit users.service;

interface

uses
  System.JSON,
  System.Generics.Collections,
  Nest4D.Attributes;

type
  [Injectable]
  TUsersService = Class
  private
  public
    function ListUsers(): TJSONArray;
  End;

implementation

{ TUsersService }

function TUsersService.ListUsers: TJSONArray;
begin
  Result := TJSONArray.Create()
    .Add(TJSONObject.Create.AddPair('user1', 'User1 Name'))
    .Add(TJSONObject.Create.AddPair('user2', 'User2 Name'));
end;

end.
