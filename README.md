# Boutique

Looking for the best fashion for your [MSON AST](https://github.com/apiaryio/mson-ast)? Boutique offers the finest quality, luxury representations to emphasize natural beauty of your AST.

![illustration](https://github.com/apiaryio/boutique/blob/master/assets/boutique.png?raw=true)

## Usage

Having following AST...

```coffeescript
ast =
  name: null
  base:
    typeSpecification:
      name: "object"

  sections: [
    type: "member"
    content: [
      type: "property"
      content:
        name:
          literal: "id"

        valueDefinition:
          values: [literal: "1"]
          typeDefinition:
            attributes: ["required"]
    ,
      type: "property"
      content:
        name:
          literal: "name"

        valueDefinition:
          values: [literal: "A green door"]
    ,
      type: "property"
      content:
        name:
          literal: "price"

        valueDefinition:
          values: [literal: "12.50"]
          typeDefinition:
            typeSpecification:
              name: "number"
    ,
      type: "property"
      content:
        name:
          literal: "tags"

        valueDefinition:
          values: [
            literal: "home"
          ,
            literal: "green"
          ]
    ,
      type: "property"
      content:
        name:
          literal: "vector"

        valueDefinition:
          typeDefinition:
            typeSpecification:
              name: "array"

        sections: [
          type: "member"
          content: [
            type: "value"
            content:
              valueDefinition:
                values: [literal: "1"]
          ,
            type: "value"
            content:
              valueDefinition:
                values: [literal: "2"]
          ,
            type: "value"
            content:
              valueDefinition:
                values: [literal: "3"]
          ]
        ]
    ]
  ]
```

...we can convert it by Boutique to a representation:

```coffeescript
boutique = require 'boutique'
boutique.represent
    ast: ast,
    contentType: 'application/json'
  , (err, body) ->
    # body contains following string:
    # '{"id":"1","name":"A green door","price":12.50,"tags":["home","green"],"vector":["1","2","3"]}'

boutique.represent
    ast: ast,
    contentType: 'application/schema+json'
  , (err, body) ->
    # body contains following string:
    # '{"type":"object","properties":"id":{"type":"string"},"name":{"type":"string"},"price":{"type":"number"},"tags":{"type":"array"},"vector":{"type":"array"}}'
```

It's also possible to pass format options:

```coffeescript
boutique = require 'boutique'

options =
  skipOptional: false

boutique.represent
    ast: ast
    contentType: 'application/json'
    options: options
  , (err, body) ->
    ...
```

## API

> **NOTE:** Refer to the [MSON Specification](https://github.com/apiaryio/mson/blob/master/MSON%20Specification.md) for the explanation of terms used throughout this documentation.

### Represent (function)
Generate representation for given content type from given MSON AST.

#### Signature

```coffeescript
boutique.represent({ast, contentType, options}, cb)
```

#### Parameters

-   `ast` (object) - MSON AST in form of tree of plain JavaScript objects.
-   `contentType`: `application/json` (string, default)

    Smart matching takes place. For example, if following formats are implemented and provided by Boutique...

    -   `application/json`
    -   `application/xml`
    -   `application/schema+json`

    ...then matching will work like this:

    -   `image/svg+xml; charset=utf-8` → `application/xml`
    -   `application/schema+json` → `application/schema+json`
    -   `application/hal+json` → `application/json`

    > **NOTE:** Distinguishing JSON Schema draft versions by matching according to `profile` parameter is [not implemented yet](https://github.com/apiaryio/boutique/issues/14).

-   `options` (object) - optional set of settings, which are passed to the selected format (*to be documented*)
-   `cb` ([Represent Callback](#represent-callback-function), required) - callback function

### Represent Callback (function)

#### Signature

```coffeescript
callback(err, repr, contentType)
```

#### Parameters

-   `err`: `null` (object, default) - Exception object in case of error
-   `repr` (string) - final string representation of given AST in given format
-   `contentType` (string) - selected content type, which was actually used for rendering the representation
