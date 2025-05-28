unit Nest4D.Logger;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  Nest4D.Attributes;

type
  TLogLevel       = (llDebug, llInfo, llWarn, llError, llFatal);
  TLogDestination = (ldConsole, ldFile, ldBoth);

  TLoggerConfig = record
    MinLevel: TLogLevel;
    Destination: TLogDestination;
    LogFileName: String;
    DateTimeFormat: String;
    IncludeTimestamp: Boolean;
    IncludeLevel: Boolean;
    AutoFlush: Boolean;
    MaxFileSize: Int64; // Em bytes, 0 = sem limite
    class function Default: TLoggerConfig; static;
  end;

  INest4DLogger = interface
    ['{8B5A5678-9012-4678-9012-123456789012}']
    procedure Debug(const AMessage: String);
    procedure Info(const AMessage: String);
    procedure Warn(const AMessage: String);
    procedure Error(const AMessage: String);
    procedure Fatal(const AMessage: String);
    procedure Log(const ALevel: TLogLevel; const AMessage: String);
    procedure SetConfig(const AConfig: TLoggerConfig);
    function GetConfig: TLoggerConfig;
    procedure SetMinLevel(const ALevel: TLogLevel);
    procedure SetDestination(const ADestination: TLogDestination);
    procedure SetLogFile(const AFileName: String);
  end;

  [Injectable]
  TNest4DDefaultLogger = class(TInterfacedObject, INest4DLogger)
  private
    FConfig       : TLoggerConfig;
    FLogFile      : TextFile;
    FLogFileOpened: Boolean;
    function LevelToString(const ALevel: TLogLevel): String;
    function GetTimestamp: String;
    procedure WriteToConsole(const AMessage: String; const ALevel: TLogLevel);
    procedure WriteToFile(const AMessage: String);
    procedure OpenLogFile;
    procedure CloseLogFile;
    procedure CheckFileSize;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TLoggerConfig); overload;
    destructor Destroy; override;
    procedure Debug(const AMessage: String);
    procedure Info(const AMessage: String);
    procedure Warn(const AMessage: String);
    procedure Error(const AMessage: String);
    procedure Fatal(const AMessage: String);
    procedure Log(const ALevel: TLogLevel; const AMessage: String);
    procedure SetConfig(const AConfig: TLoggerConfig);
    function GetConfig: TLoggerConfig;
    procedure SetMinLevel(const ALevel: TLogLevel);
    procedure SetDestination(const ADestination: TLogDestination);
    procedure SetLogFile(const AFileName: String);
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

{ TLoggerConfig }

class function TLoggerConfig.Default: TLoggerConfig;
begin
  Result.MinLevel         := llDebug;
  Result.Destination      := ldConsole;
  Result.LogFileName      := 'application.log';
  Result.DateTimeFormat   := 'yyyy-mm-dd hh:nn:ss.zzz';
  Result.IncludeTimestamp := True;
  Result.IncludeLevel     := True;
  Result.AutoFlush        := True;
  Result.MaxFileSize      := 10 * 1024 * 1024; // 10MB
end;

{ TNest4DDefaultLogger }

constructor TNest4DDefaultLogger.Create;
begin
  inherited Create;
  FConfig        := TLoggerConfig.Default;
  FLogFileOpened := False;
end;

constructor TNest4DDefaultLogger.Create(const AConfig: TLoggerConfig);
begin
  inherited Create;
  FConfig        := AConfig;
  FLogFileOpened := False;
end;

destructor TNest4DDefaultLogger.Destroy;
begin
  CloseLogFile;
  inherited Destroy;
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
  parts     : TArray<String>;
begin
  // Verifica se o nível está acima do mínimo configurado
  if ALevel < FConfig.MinLevel then
    Exit;

  // Monta a mensagem de log
  SetLength(parts, 0);

  if FConfig.IncludeTimestamp then
  begin
    SetLength(parts, Length(parts) + 1);
    parts[High(parts)] := GetTimestamp;
  end;

  if FConfig.IncludeLevel then
  begin
    SetLength(parts, Length(parts) + 1);
    parts[High(parts)] := LevelToString(ALevel);
  end;

  SetLength(parts, Length(parts) + 1);
  parts[High(parts)] := AMessage;

  LogMessage := String.Join(' ', parts);

  // Escreve conforme o destino configurado
  case FConfig.Destination of
    ldConsole:
      WriteToConsole(LogMessage, ALevel);
    ldFile:
      WriteToFile(LogMessage);
    ldBoth:
      begin
        WriteToConsole(LogMessage, ALevel);
        WriteToFile(LogMessage);
      end;
  end;
end;

procedure TNest4DDefaultLogger.WriteToConsole(const AMessage: String; const ALevel: TLogLevel);
begin
  // Para Error e Fatal, escreve no stderr, caso contrário stdout
  if ALevel >= llError then
    Writeln(ErrOutput, AMessage)
  else
    Writeln(AMessage);
end;

procedure TNest4DDefaultLogger.WriteToFile(const AMessage: String);
begin
  try
    if not FLogFileOpened then
      OpenLogFile;

    if FLogFileOpened then
    begin
      Writeln(FLogFile, AMessage);

      if FConfig.AutoFlush then
        Flush(FLogFile);

      // Verifica o tamanho do arquivo se um limite foi definido
      if FConfig.MaxFileSize > 0 then
        CheckFileSize;
    end;
  except
    on E: Exception do
    begin
      // Em caso de erro ao escrever no arquivo, escreve no console
      Writeln(ErrOutput, 'Logger Error: ' + E.Message);
      WriteToConsole(AMessage, llError);
    end;
  end;
end;

procedure TNest4DDefaultLogger.OpenLogFile;
begin
  try
    AssignFile(FLogFile, FConfig.LogFileName);

    if FileExists(FConfig.LogFileName) then
      Append(FLogFile)
    else
      Rewrite(FLogFile);

    FLogFileOpened := True;
  except
    on E: Exception do
    begin
      FLogFileOpened := False;
      Writeln(ErrOutput, 'Failed to open log file: ' + E.Message);
    end;
  end;
end;

procedure TNest4DDefaultLogger.CloseLogFile;
begin
  if FLogFileOpened then
  begin
    try
      CloseFile(FLogFile);
    except
      // Ignora erros ao fechar o arquivo
    end;
    FLogFileOpened := False;
  end;
end;

procedure TNest4DDefaultLogger.CheckFileSize;
var
  FileStream    : TFileStream;
  FileSize      : Int64;
  BackupFileName: String;
begin
  try
    if not FileExists(FConfig.LogFileName) then
      Exit;

    FileStream := TFileStream.Create(FConfig.LogFileName, fmOpenRead or fmShareDenyNone);
    try
      FileSize := FileStream.Size;
    finally
      FileStream.Free;
    end;

    if FileSize >= FConfig.MaxFileSize then
    begin
      // Fecha o arquivo atual
      CloseLogFile;

      // Cria um backup com timestamp
      BackupFileName := ChangeFileExt(FConfig.LogFileName, '') + '_' + FormatDateTime('yyyymmdd_hhnnss', Now) +
        ExtractFileExt(FConfig.LogFileName);

      // Move o arquivo atual para o backup
      if RenameFile(FConfig.LogFileName, BackupFileName) then
      begin
        // Reabre o arquivo (será criado novo)
        OpenLogFile;
      end;
    end;
  except
    // Em caso de erro, continua normalmente
  end;
end;

procedure TNest4DDefaultLogger.SetConfig(const AConfig: TLoggerConfig);
begin
  // Fecha o arquivo atual se estiver aberto
  CloseLogFile;

  FConfig := AConfig;

  // Se o destino inclui arquivo, tenta abrir
  if FConfig.Destination in [ldFile, ldBoth] then
    OpenLogFile;
end;

function TNest4DDefaultLogger.GetConfig: TLoggerConfig;
begin
  Result := FConfig;
end;

procedure TNest4DDefaultLogger.SetMinLevel(const ALevel: TLogLevel);
begin
  FConfig.MinLevel := ALevel;
end;

procedure TNest4DDefaultLogger.SetDestination(const ADestination: TLogDestination);
begin
  if FConfig.Destination <> ADestination then
  begin
    // Se estava usando arquivo e não vai mais usar, fecha
    if (FConfig.Destination in [ldFile, ldBoth]) and (ADestination = ldConsole) then
      CloseLogFile;

    FConfig.Destination := ADestination;

    // Se agora vai usar arquivo e não estava usando, abre
    if (ADestination in [ldFile, ldBoth]) and not FLogFileOpened then
      OpenLogFile;
  end;
end;

procedure TNest4DDefaultLogger.SetLogFile(const AFileName: String);
begin
  if FConfig.LogFileName <> AFileName then
  begin
    CloseLogFile;
    FConfig.LogFileName := AFileName;

    if FConfig.Destination in [ldFile, ldBoth] then
      OpenLogFile;
  end;
end;

function TNest4DDefaultLogger.LevelToString(const ALevel: TLogLevel): String;
begin
  case ALevel of
    llDebug:
      Result := '[DEBUG]';
    llInfo:
      Result := '[INFO]';
    llWarn:
      Result := '[WARN]';
    llError:
      Result := '[ERROR]';
    llFatal:
      Result := '[FATAL]';
  end;
end;

function TNest4DDefaultLogger.GetTimestamp: String;
begin
  Result := FormatDateTime(FConfig.DateTimeFormat, Now);
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
