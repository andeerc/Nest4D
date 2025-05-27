unit Nest4D.Attributes;

interface

uses
  System.Generics.Collections;

type
  TN4DMethod = (mGet, mPost, mPut, mPatch, mDelete);

  // Modern attribute for controllers
  Controller = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(const APath: String);
  end;

  // Modern attributes for HTTP methods
  Get = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(const APath: String = '');
  end;

  Post = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(const APath: String = '');
  end;

  Put = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(const APath: String = '');
  end;

  Patch = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(const APath: String = '');
  end;

  Delete = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(const APath: String = '');
  end;
  // Injectable attribute for services
  Injectable = class(TCustomAttribute)
  end;
  // Parameter injection attributes
  Param = class(TCustomAttribute)
  private
    FName: String;
    FAllParams: Boolean;
  public
    property Name: String read FName;
    property AllParams: Boolean read FAllParams;
    constructor Create(const AName: String = ''); // Empty string means all params
  end;

  Query = class(TCustomAttribute)
  private
    FName: String;
    FAllParams: Boolean;
  public
    property Name: String read FName;
    property AllParams: Boolean read FAllParams;
    constructor Create(const AName: String = ''); // Empty string means all query params
  end;

  Header = class(TCustomAttribute)
  private
    FName: String;
    FAllHeaders: Boolean;
  public
    property Name: String read FName;
    property AllHeaders: Boolean read FAllHeaders;
    constructor Create(const AName: String = ''); // Empty string means all headers
  end;

  Body = class(TCustomAttribute)
  private
    FContentType: String;
  public
    property ContentType: String read FContentType;
    constructor Create(const AContentType: String = 'application/json');
  end;

  // Legacy attributes (for backward compatibility)
  N4DController = class(TCustomAttribute)
  private
    FPath: String;
  public
    property Path: String read FPath;
    constructor Create(APath: String);
  end;

  N4DRoute = class(TCustomAttribute)
  private
    FPath: String;
    FMethod: TN4DMethod;
  public
    property Path: String read FPath;
    property Method: TN4DMethod read FMethod;
    constructor Create(AMethod: TN4DMethod; APath: String);
  end;

implementation

{ Controller }

constructor Controller.Create(const APath: String);
begin
  FPath := APath;
end;

{ Get }

constructor Get.Create(const APath: String);
begin
  FPath := APath;
end;

{ Post }

constructor Post.Create(const APath: String);
begin
  FPath := APath;
end;

{ Put }

constructor Put.Create(const APath: String);
begin
  FPath := APath;
end;

{ Patch }

constructor Patch.Create(const APath: String);
begin
  FPath := APath;
end;

{ Delete }

constructor Delete.Create(const APath: String);
begin
  FPath := APath;
end;

{ Param }

constructor Param.Create(const AName: String);
begin
  FName := AName;
  FAllParams := (AName = ''); // If no name specified, return all params
end;

{ Query }

constructor Query.Create(const AName: String);
begin
  FName := AName;
  FAllParams := (AName = ''); // If no name specified, return all query params
end;

{ Header }

constructor Header.Create(const AName: String);
begin
  FName := AName;
  FAllHeaders := (AName = ''); // If no name specified, return all headers
end;

{ Body }

constructor Body.Create(const AContentType: String);
begin
  FContentType := AContentType;
end;

{ N4DController - Legacy }

constructor N4DController.Create(APath: String);
begin
  FPath := APath;
end;

{ N4DRoute - Legacy }

constructor N4DRoute.Create(AMethod: TN4DMethod; APath: String);
begin
  FMethod := AMethod;
  FPath := APath;
end;

end.
