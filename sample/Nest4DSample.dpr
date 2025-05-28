program Nest4DSample;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Rtti,
  Nest4D.Application in '..\src\Nest4D.Application.pas',
  Nest4D.Attributes in '..\src\Nest4D.Attributes.pas',
  Nest4D.Interfaces in '..\src\Nest4D.Interfaces.pas',
  Nest4D.Logger in '..\src\Nest4D.Logger.pas',
  app.module in 'src\app.module.pas',
  app.service in 'src\app.service.pas',
  app.controller in 'src\app.controller.pas',
  Nest4D.Injector in '..\src\Nest4D.Injector.pas',
  Nest4D.Injector.abstract in '..\src\Nest4D.Injector.abstract.pas',
  Nest4D.Injector.container in '..\src\Nest4D.Injector.container.pas',
  Nest4D.Injector.events in '..\src\Nest4D.Injector.events.pas',
  Nest4D.Injector.factory in '..\src\Nest4D.Injector.factory.pas',
  Nest4D.Injector.service.abstract in '..\src\Nest4D.Injector.service.abstract.pas',
  Nest4D.Injector.service in '..\src\Nest4D.Injector.service.pas';

var
  loggerConfig: TLoggerConfig;
begin
  try
    // Configuração avançada do logger
    loggerConfig                  := TLoggerConfig.Default;
    loggerConfig.MinLevel         := llDebug;          // Mostra todos os logs em desenvolvimento
    loggerConfig.Destination      := ldBoth;           // Saída no console E arquivo
    loggerConfig.LogFileName      := 'nest4d_app.log'; // Nome do arquivo de log
    loggerConfig.MaxFileSize      := 5 * 1024 * 1024;  // 5MB - rotação automática
    loggerConfig.IncludeTimestamp := True;
    loggerConfig.IncludeLevel     := True;
    loggerConfig.AutoFlush        := True; // Flush imediato para debug

    N4DInjector.SingletonInterface<INest4DLogger, TNest4DDefaultLogger>('', nil, nil,
      function: TArray<TValue>
      var
        params: TValue;
      begin
        params := TValue.From(loggerConfig);
        SetLength(Result, 1);
        Result[0] := params
      end);

    TNest4DApplication.NewApplication(TAppModule,
      procedure(app: TNest4DApplication)
      begin
        app.Start();
      end);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
