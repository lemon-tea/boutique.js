
async = require 'async'
{resolveType} = require '../typeresolution'


# Takes object type node and lists its property nodes.
listProperties = (objectType, cb) ->
  props = []
  for member in (objectType.sections or []) when member.type is 'member'
    for prop in member.content when prop.type is 'property'
      props.push prop
  cb null, props


# Turns property node into a 'resolved property' object with both
# representation in JSON Schema and also additional info, such as property
# name, attributes, etc.
resolveProperty = (prop, options, cb) ->
  async.waterfall [
    (next) -> handleType prop.content, options, next
    (schema, next) ->
      next null,
        name: prop.content.name.literal
        schema: schema
        required: 'required' in (prop.content?.valueDefinition?.typeDefinition?.attributes or [])
  ], cb


# Turns multiple property nodes into 'resolved properties', i.e. objects
# carrying both representations of those properties in JSON Schema
# and also additional info, such as property names, attributes, etc.
resolveProperties = (props, options, cb) ->
  async.map props, (prop, next) ->
    resolveProperty prop, options, next
  , cb


# Takes 'resolved properties' and generates JSON Schema
# for their wrapper object type node.
buildObjectSchema = (resolvedProps, options, cb) ->
  schemaProps = {}
  schemaRequired = []

  for {name, schema, required} in resolvedProps
    schemaProps[name] = schema
    schemaRequired.push name if required

  schema =
    type: 'object'
    properties: schemaProps
  schema.required = schemaRequired if schemaRequired.length > 0

  cb null, schema


# Generates JSON Schema representation for given object type node.
handleObject = (objectType, resolvedType, options, cb) ->
  async.waterfall [
    (next) -> listProperties objectType, next
    (props, next) -> resolveProperties props, options, next
    (resolvedProps, next) -> buildObjectSchema resolvedProps, options, next
  ], cb


# Takes object type node and lists its value nodes.
listValues = (objectType, cb) ->
  vals = []
  for member in (objectType.sections or []) when member.type is 'member'
    for val in member.content when val.type is 'value'
      vals.push val
  cb null, vals


# Turns value node into a 'resolved value' object with both
# representation in JSON Schema and also possible additional info.
resolveValue = (val, options, cb) ->
  async.waterfall [
    (next) ->
      async.parallel
        resolvedType: (done) -> resolveType val, done
        schema: (done) -> handleType val.content, options, done
      , next
    ({resolvedType, schema}, next) ->
      next null,
        typeName: resolvedType.name
        schema: schema
  ], cb


# Turns multiple property nodes into 'resolved values', i.e. objects
# carrying both representations of those values in JSON Schema
# and also possible additional info.
resolveValues = (vals, options, cb) ->
  async.map vals, (val, next) ->
    resolveValue val, options, next
  , cb


# Takes 'resolved values' and generates JSON Schema
# for their wrapper array type node.
buildArraySchema = (resolvedVals, resolvedType, options, cb) ->
  cb null,
    type: 'array'
    # TODO, WIP - will I'll continue in subsequent PRs
    # items: (rv.schema for rv in resolvedVals)


# Generates JSON Schema representation for given array type node.
handleArray = (arrayType, resolvedType, options, cb) ->
  async.waterfall [
    (next) -> listValues arrayType, next
    (vals, next) -> resolveValues vals, options, next
    (resolvedVals, next) -> buildArraySchema resolvedVals, resolvedType, options, next
  ], cb


# Generates JSON Schema representation for given base
# type node (string, number, etc.).
handlePrimitiveType = (baseType, resolvedType, options, cb) ->
  cb null, type: resolvedType.name


# Generates JSON Schema representation for given type node.
handleType = (type, options, cb) ->
  resolveType type, (err, resolvedType) ->
    return cb err if err
    switch resolvedType.name
      when 'object'
        handleObject type, resolvedType, options, cb
      when 'array'
        handleArray type, resolvedType, options, cb
      else
        handlePrimitiveType type, resolvedType, options, cb


# Adds JSON Schema declaration to given schema object.
addSchemaDeclaration = (schema, cb) ->
  schema["$schema"] = "http://json-schema.org/draft-04/schema#"
  cb null, schema


# Transforms given MSON AST into JSON Schema.
transform = (ast, options, cb) ->
  async.waterfall [
    (next) -> handleType ast, options, next
    addSchemaDeclaration
  ], cb


module.exports = {
  transform
}
