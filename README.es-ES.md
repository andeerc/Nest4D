

<h1 align="center">
  Nest4D
</h1>

<p align="center">
  <a href="https://github.com/andeerc/Nest4D/blob/Master/img/nest4d.png">
    <img alt="Nest4D" height="300" src="https://github.com/andeerc/Nest4D/blob/Master/img/nest4d.png">
  </a>
</p>

<p align="center">
  ¡Un framework inspirado en NestJS para Delphi con el poderoso Horse!
</p>

<br>

<p align="center">
  <h2>¡Este repositorio está abierto para contribuciones!</h2> 
  Siéntase libre de abrir issues, enviar pull requests o compartir ideas para mejorar este proyecto. 
  ¡Toda ayuda es bienvenida!
</p>

<h2>
  Punto de entrada
</h2>

```pascal
  try
    TNest4DApplication.NewApplication(TAppModule,
      procedure(app: TNest4DApplication)
      begin
        app.Start();
      end);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
```

<h3>
  Módulo
</h3>

```pascal
uses
  Nest4D.Interfaces;

type
  TAppModule = Class(TInterfacedObject, IN4DModule)
  public
    function Imports: TArray<TClass>;
    function Services: TArray<TClass>;
    function Controllers: TArray<TClass>;
  End;

implementation

uses
  app.controller,
  app.service;

{ TAppModule }

function TAppModule.Controllers: TArray<TClass>;
begin
  Result := [TAppController];
end;

function TAppModule.Imports: TArray<TClass>;
begin
  Result := [];
end;

function TAppModule.Services: TArray<TClass>;
begin
  Result := [TAppService];
end;
```

<h3>
  Controller
</h3>

```pascal
uses
  System.Json,
  Nest4D.Attributes,
  app.service;

type
  [N4DController('/api')]
  TAppController = Class
  private
    FAppService: TAppService;
  public
    [N4DRoute(Get, '')]
    function getApi: TJsonObject;

    constructor Create(AAppService: TAppService);
  End;
                       
implementation

{ TAppController }

constructor TAppController.Create(AAppService: TAppService);
begin
  FAppService := AAppService;
end;

function TAppController.getApi: TJsonObject;
begin
  Result := TJSONObject.Create.AddPair('message', 'Hello, World!');
end;
```
