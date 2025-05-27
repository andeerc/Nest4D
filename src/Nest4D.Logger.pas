unit Nest4D.Logger;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  Nest4D.Attributes;

type
  TLogLevel = (llDebug, llInfo, llWarn, llError, llFatal);

  INest4DLogger = interface
    ['{8B5A5678-9012-4678-9012-123456789012}']
    procedure Debug(const AMessage: String);
    procedure Info(const AMessage: String);
    procedure Warn(const AMessage: String);
    procedure Error(const AMessage: String);
    procedure Fatal(const AMessage: String);
    procedure Log(const ALevel: TLogLevel; const AMessage: String);
  end;

  [Injectable]
  TNest4DDefaultLogger = class(TInterfacedObject, INest4DLogger)
  private
    FMinLevel: TLogLevel;
    function LevelToString(const ALevel: TLogLevel): String;
    function GetTimestamp: String;
  public
    constructor Create;
    procedure Debug(const AMessage: String);
    procedure Info(const AMessage: String);
    procedure Warn(const AMessage: String);
    procedure Error(const AMessage: String);
    procedure Fatal(const AMessage: String);
    procedure Log(const ALevel: TLogLevel; const AMessage: String);
  end;

  // Classe de utilidade para acesso fácil ao logger default
  TLogger = class
  private
    class var FInstance: INest4DLogger;
  public
    class function GetInstance: INest4DLogger;
    class procedure Debug(const AMessage: String);
    class procedure Info(const AMessage: String);
    class procedure Warn(const AMessage: String);
    class procedure Error(const AMessage: String);
    class procedure Fatal(const AMessage: String);
  end;

implementation

uses
  Nest4D.Injector;

{ TNest4DDefaultLogger }

constructor TNest4DDefaultLogger.Create;
begin
  inherited Create;
  FMinLevel := llDebug; // Por padrão, mostra todos os logs
end;

procedure TNest4DDefaultLogger.Debug(const AMessage: String);
begin
  Log(llDebug, AMessage);
end;

procedure TNest4DDefaultLogger.Info(const AMessage: String);
begin
  Log(llInfo, AMessage);
end;

procedure TNest4DDefaultLogger.Warn(const AMessage: String);
begin
  Log(llWarn, AMessage);
end;

procedure TNest4DDefaultLogger.Error(const AMessage: String);
begin
  Log(llError, AMessage);
end;

procedure TNest4DDefaultLogger.Fatal(const AMessage: String);
begin
  Log(llFatal, AMessage);
end;

procedure TNest4DDefaultLogger.Log(const ALevel: TLogLevel; const AMessage: String);
var
  LogMessage: String;
begin
  if ALevel < FMinLevel then
    Exit;

  LogMessage := Format('[%s] %s: %s', [GetTimestamp, LevelToString(ALevel), AMessage]);
  
  // Para Error e Fatal, escreve no stderr, caso contrário stdout
  if ALevel >= llError then
    Writeln(ErrOutput, LogMessage)
  else
    Writeln(LogMessage);
end;

function TNest4DDefaultLogger.LevelToString(const ALevel: TLogLevel): String;
begin
  case ALevel of
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  end;
end;

function TNest4DDefaultLogger.GetTimestamp: String;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
end;

{ TLogger }

class function TLogger.GetInstance: INest4DLogger;
begin
  if FInstance = nil then
  begin
    try
      // Tenta obter do container de injeção
      FInstance := N4DInjector.GetInterface<INest4DLogger>;
    except
      // Se falhar, cria uma instância padrão
      FInstance := TNest4DDefaultLogger.Create;
    end;
  end;
  Result := FInstance;
end;

class procedure TLogger.Debug(const AMessage: String);
begin
  GetInstance.Debug(AMessage);
end;

class procedure TLogger.Info(const AMessage: String);
begin
  GetInstance.Info(AMessage);
end;

class procedure TLogger.Warn(const AMessage: String);
begin
  GetInstance.Warn(AMessage);
end;

class procedure TLogger.Error(const AMessage: String);
begin
  GetInstance.Error(AMessage);
end;

class procedure TLogger.Fatal(const AMessage: String);
begin
  GetInstance.Fatal(AMessage);
end;

end.
