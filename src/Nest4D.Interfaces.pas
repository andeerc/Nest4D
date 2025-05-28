unit Nest4D.Interfaces;

interface

uses
  System.Generics.Collections;

type  IN4DModule = Interface
    ['{58388937-2DC9-46B6-8CFB-2D819662B519}']

    function Imports: TArray<TClass>;
    function Services: TArray<TClass>;
    function Controllers: TArray<TClass>;
    procedure Configure; // Método para configurações customizadas do módulo
  End;

implementation

end.
