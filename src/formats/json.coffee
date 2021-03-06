# JSON format


async = require 'async'
inspect = require '../inspect'
{detectSuccessful} = require '../utils'
{resolveType} = require '../typeresolution'
{coerceLiteral, coerceNestedLiteral} = require '../jsonutils'


# Turns *Element* node containing object property into a 'resolved property'
# object with both representation in JSON and optionally also
# some additional info.
resolveProperty = (prop, inherited, cb) ->
  handleElement prop, inherited, (err, repr) ->
    return cb err if err

    cb null,
      name: inspect.findPropertyName prop
      repr: repr

# Turns *Element* node containing oneOf into an array
# of 'resolved property' objects with both representation in JSON and
# optionally also some additional info.
resolveOneOf = (oneofElement, inherited, cb) ->
  element = oneofElement.content[0]
  if element.class is 'group'
    resolveOneOfGroup element, inherited, cb
  else
    resolveProperty element, inherited, (err, resolvedProp) ->
      cb err, ([resolvedProp] unless err)


# Turns *Element* node containing a group of properties into an array
# of 'resolved property' objects with both representation in JSON and
# optionally also some additional info.
resolveOneOfGroup = (groupElement, inherited, cb) ->
  async.mapSeries groupElement.content, (prop, next) ->
    resolveProperty prop, inherited, next
  , cb


# Turns a list of *Element* nodes containing object properties into an array
# of 'resolved property' objects with both representation in JSON and
# optionally also some additional info.
resolveProperties = (props, inherited, cb) ->
  results = []
  async.eachSeries props, (prop, next) ->
    if prop.class is 'oneOf'
      return next() if !prop.content.length

      # oneOf can result in multiple properties
      resolveOneOf prop, inherited, (err, resolvedProps) ->
        results = results.concat resolvedProps
        next err
    else
      resolveProperty prop, inherited, (err, resolvedProp) ->
        results.push resolvedProp
        next err
  , (err) ->
    cb err, results


# Takes 'resolved properties' and generates JSON for their wrapper
# object *Element* node.
buildObjectRepr = ({resolvedProps}, cb) ->
  repr = {}
  repr[rp.name] = rp.repr for rp in resolvedProps
  cb null, repr


# Generates JSON representation for given *Element* node containing
# an object type.
handleObjectElement = (objectElement, resolvedType, inherited, cb) ->
  fixed = inspect.isOrInheritsFixed objectElement, inherited
  heritage = inspect.getHeritage fixed, resolvedType
  props = inspect.listProperties objectElement

  resolveProperties props, heritage, (err, resolvedProps) ->
    return cb err if err

    buildObjectRepr {resolvedProps}, cb


# Turns *Element* node containing array or enum item into a 'resolved item'
# object with both representation in JSON and optionally also
# some additional info.
resolveItem = (item, inherited, cb) ->
  handleElement item, inherited, (err, repr) ->
    return cb err if err

    cb null, {repr}

# Turns a list of *Element* nodes containing array items into an array
# of 'resolved item' objects with both representation in JSON and
# optionally also some additional info.
resolveArrayItems = (items, multipleInherited, cb) ->
  if multipleInherited.length is 1
    # single nested type definition, e.g. array[number]
    inherited = multipleInherited[0]
    async.mapSeries items, (item, next) ->
      resolveItem item, inherited, next
    , cb
  else
    # multiple nested type definitions, e.g. array[number,string]
    async.mapSeries items, (item, next) ->
      # we iterate over types and render the first one, which can be
      # successfully applied to given value (e.g. for array[number,string],
      # if coercing to `number` fails, this algorithm skips it and tries
      # to coerce with `string`).
      detectSuccessful multipleInherited, (inherited, done) ->
        resolveItem item, inherited, done
      , next
    , cb


# Takes 'resolved items' and generates JSON for their wrapper
# array *Element* node.
buildArrayRepr = ({arrayElement, resolvedItems, resolvedType, fixed}, cb) ->
  # ordinary arrays
  if resolvedItems.length
    if fixed
      repr = (ri.repr for ri in resolvedItems)
    else
      repr = (ri.repr for ri in resolvedItems when ri.repr isnt null)
    return cb null, repr

  # inline arrays
  if fixed
    return cb new Error "Multiple nested types for fixed array." if resolvedType.nested.length > 1
    vals = inspect.listValues arrayElement
  else
    vals = inspect.listValuesOrSamples arrayElement

  async.mapSeries vals, (val, next) ->
    coerceNestedLiteral val.literal, resolvedType.nested, next
  , cb


# Generates JSON representation for given *Element* node containing
# an array type.
handleArrayElement = (arrayElement, resolvedType, inherited, cb) ->
  fixed = inspect.isOrInheritsFixed arrayElement, inherited
  heritages = inspect.listPossibleHeritages fixed, resolvedType
  items = inspect.listItems arrayElement

  resolveArrayItems items, heritages, (err, resolvedItems) ->
    return cb err if err

    buildArrayRepr {arrayElement, resolvedItems, resolvedType, fixed}, cb


# Resolves items as enum values. Produces only one 'resolved item' object or
# 'falsy' value, which indicates that there are no items to be resolved.
resolveEnumItems = (items, inherited, cb) ->
  item = items?[0]
  return cb null, null unless item  # 'falsy' resolvedItem
  resolveItem item, inherited, cb


# Takes 'resolved items' and generates JSON for their wrapper
# enum *Element* node.
buildEnumRepr = ({enumElement, resolvedItem, resolvedType}, cb) ->
  # ordinary enums
  return cb null, resolvedItem.repr if resolvedItem

  # inline enums
  return cb new Error "Multiple nested types for enum." if resolvedType.nested.length > 1
  vals = inspect.listValuesOrSamples enumElement
  if vals.length
    coerceLiteral vals[0].literal, resolvedType.nested[0], cb
  else
    cb null, null  # empty representation is null


# Generates JSON representation for given *Element* node containing
# an enum type.
handleEnumElement = (enumElement, resolvedType, inherited, cb) ->
  fixed = inspect.isOrInheritsFixed enumElement, inherited
  heritage = inspect.getHeritage fixed, resolvedType
  items = inspect.listItems enumElement

  resolveEnumItems items, heritage, (err, resolvedItem) ->
    return cb err if err

    buildEnumRepr {enumElement, resolvedItem, resolvedType}, cb


# Generates JSON representation for given *Element* node containing a primitive
# type (string, number, etc.).
handlePrimitiveElement = (primitiveElement, resolvedType, inherited, cb) ->
  vals = inspect.listValues primitiveElement
  if vals.length
    return cb new Error "Primitive type can't have multiple values." if vals.length > 1
    return coerceLiteral vals[0].literal, resolvedType.name, cb
  cb null, null  # empty representation is null


# *Element* handler factory.
createElementHandler = (resolvedType) ->
  switch resolvedType.name
    when 'object'
      handleObjectElement
    when 'array'
      handleArrayElement
    when 'enum'
      handleEnumElement
    else
      handlePrimitiveElement


# Generates JSON representation for given *Element* node.
handleElement = (element, inherited, cb) ->
  resolveType element, inherited.typeName, (err, resolvedType) ->
    return cb err if err

    handle = createElementHandler resolvedType
    handle element, resolvedType, inherited, cb


# Transforms given MSON AST into JSON.
transform = (ast, cb) ->
  handleElement inspect.getAsElement(ast), {}, cb


module.exports = {
  transform
}
