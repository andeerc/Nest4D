# Nest4D Parameter Injection Guide - Sistema Completo

Este guia explica como usar o sistema completo de injeção de parâmetros do Nest4D, incluindo dependency injection automática e anotações de parâmetros para extrair dados de requests HTTP de forma elegante e tipada.

## ✅ Recursos Implementados

- ✅ Dependency Injection automática no construtor de controllers
- ✅ Anotações @Param, @Query, @Header, @Body para injeção de parâmetros
- ✅ Suporte para extrair parâmetros específicos ou todos os parâmetros
- ✅ Conversão automática de tipos (String, Integer, Double, TJSONObject)
- ✅ Roteamento dinâmico com parâmetros (ex: `/users/:id`)
- ✅ Verificação e registro automático de dependências
- ✅ Sistema robusto de logging e debug

## Anotações Disponíveis

### @Param - Parâmetros de Rota

Extrai parâmetros de rota definidos na URL (ex: `/users/:id`).

```pascal
// Extrair um parâmetro específico
[Get('/users/:id')]
function getUser([Param('id')] userId: string): string;

// Extrair todos os parâmetros de rota
[Get('/users/:userId/posts/:postId')]
function getUserPost([Param()] allParams: TDictionary<String, String>): string;
```

### @Query - Parâmetros de Query String

Extrai parâmetros da query string (ex: `?search=termo&limit=10`).

```pascal
// Extrair parâmetros específicos
[Get('/search')]
function searchData([Query('term')] searchTerm: string; [Query('limit')] limit: Integer): string;

// Extrair todos os parâmetros de query
[Get('/info')]
function getInfo([Query()] allQueryParams: TDictionary<String, String>): string;
```

### @Header - Headers HTTP

Extrai headers da requisição HTTP.

```pascal
// Extrair um header específico
[Get('/protected')]
function getProtectedData([Header('Authorization')] authToken: string): string;

// Extrair todos os headers
[Get('/debug')]
function debugRequest([Header()] allHeaders: TDictionary<String, String>): string;
```

### @Body - Corpo da Requisição

Extrai o corpo da requisição HTTP.

```pascal
// Corpo como JSON
[Post('/data')]
function createData([Body] jsonData: TJSONObject): string;

// Corpo como string
[Post('/text')]
function processText([Body] textData: string): string;
```

## Tipos Suportados

### Tipos Primitivos
- `string` - Para valores de texto
- `Integer` - Para valores numéricos inteiros
- `Double` - Para valores numéricos com ponto flutuante

### Tipos de Coleção
- `TDictionary<String, String>` - Para obter todos os valores de uma categoria (params, query, headers)
- `TJSONObject` - Para dados JSON estruturados

## Exemplos Práticos

### 1. API de Usuários

```pascal
[Controller('/api/users')]
TUserController = class
  // GET /api/users?page=1&limit=10
  [Get('')]
  function getUsers([Query('page')] page: Integer; [Query('limit')] limit: Integer): string;

  // GET /api/users/123
  [Get('/:id')]
  function getUser([Param('id')] userId: string): string;

  // POST /api/users
  [Post('')]
  function createUser([Body] userData: TJSONObject): string;

  // PUT /api/users/123
  [Put('/:id')]
  function updateUser([Param('id')] userId: string; [Body] userData: TJSONObject): string;
end;
```

### 2. API com Autenticação

```pascal
[Controller('/api/secure')]
TSecureController = class
  [Get('/profile')]
  function getProfile([Header('Authorization')] token: string): string;

  [Post('/upload')]
  function uploadFile([Header('Content-Type')] contentType: string; [Body] fileData: string): string;
end;
```

### 3. API de Debug/Monitoramento

```pascal
[Controller('/api/debug')]
TDebugController = class
  // Mostra todos os parâmetros recebidos
  [Get('/request-info')]
  function getRequestInfo([Query()] queries: TDictionary<String, String>;
                         [Header()] headers: TDictionary<String, String>): string;

  // Analisa rotas complexas
  [Get('/analyze/:category/:subcategory')]
  function analyzeRoute([Param()] allParams: TDictionary<String, String>): string;
end;
```

## Funcionamento Interno

O sistema de resolução de parâmetros funciona com a seguinte prioridade:

1. **Anotações específicas** - @Body, @Param, @Query, @Header têm prioridade máxima
2. **Tipos do framework** - THorseRequest, THorseResponse são injetados automaticamente
3. **Injeção de dependência** - Interfaces e classes registradas no container
4. **Resolução legacy** - Sistema antigo para compatibilidade

## Características Especiais

### Conversão Automática de Tipos
O sistema converte automaticamente strings para tipos apropriados:
- String para Integer usando `StrToIntDef`
- String para Double usando `StrToFloatDef`
- JSON string para TJSONObject usando `ParseJSONValue`

### Tratamento de Erros
- Parâmetros não encontrados recebem valores padrão (0 para números, '' para strings)
- Logs detalhados são gerados para debug
- Erros de conversão são tratados graciosamente

### Performance
- Coleções (TDictionary) são criadas sob demanda
- Resolução de parâmetros é feita usando RTTI de forma otimizada
- Cache de métodos e tipos para melhor performance

## Migração do Sistema Antigo

O sistema mantém compatibilidade com o código existente. Controllers antigos continuam funcionando, mas podem ser migrados gradualmente:

```pascal
// Antes (sistema legacy)
function getUser(id: string): string;

// Depois (com anotações)
function getUser([Param('id')] id: string): string;
```

## Exemplos de Uso Real

Veja o arquivo `sample/src/app.controller.pas` para exemplos completos de como usar cada tipo de anotação.
