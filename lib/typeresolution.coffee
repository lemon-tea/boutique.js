
async = require 'async'


# Listing of all base types as defined in MSON AST spec.
baseTypes = ['boolean', 'string', 'number', 'array', 'enum', 'object']


# Calls given function with an error in case given type name is not one
# of base types.
ensureBaseType = (type, cb) ->
  if type not in baseTypes
    cb new Error "Unable to resolve type: #{type}"
  else
    cb null


# Turns *typeSpecification* object as described in
# https://github.com/apiaryio/mson-ast#type-definition into something simpler:
#
#     name: ...
#     nested: [...]
#
# In case it isn't able to resolve this *typeSpecification* object with
# base types only, ends with an error (Boutique builds no symbol table,
# so it can't resolve any possible inheritance).
simplifyTypeSpecification = (typeSpec, cb) ->
  type = typeSpec?.name?.name
  return cb null, null if not type  # no type? return null...

  ensureBaseType type, (err) ->
    return cb err if err  # non-base type results in error
    return cb null, {name: type} if (typeSpec?.nestedTypes?.length or 0) < 1  # no nested types

    # just playing safe, this should be already ensured by MSON parser
    if type not in ['array', 'enum']
      return cb new Error "Nested types are allowed only for array and enum types."

    nested = (typeName.name for typeName in typeSpec.nestedTypes)
    async.map nested, ensureBaseType, (err) ->
      return cb err if err  # again, non-base types result in error
      cb null, {name: type, nested}


# Helps to identify whether given node is an implicit array.
isArray = (node) ->
  (node.valueDefinition?.values?.length or 0) > 1  # has multiple values?


# Helps to identify whether given node is an implicit object.
#
# There are two ways how to say whether there are "nested member types".
# First way is to count individual member types one by one, second way is
# to count whether there are "containers" for these nested types.
#
# The second approach makes more sense, because counting individual
# nested objects would cause problems with empty "containers", which
# are probably sufficient proof of nested members, but contain zero of them.
#
# However, this 'race condition' probably can't happen anyway, so these
# approaches shouldn't(tm) make a difference.
isObject = (node) ->
  sections = node.sections or []
  memberSections = sections.filter (section) ->
    section.type is 'member'
  memberSections.length > 0


# Resolves implicit type for given *Named Type* or *Property Member*
# or *Value Member* tree node.
resolveImplicitType = (node, cb) ->
  isArr = isArray node
  isObj = isObject node

  if isObj and isArr
    # just playing safe, this should be already ensured by MSON parser
    cb new Error "Unable to resolve type. Ambiguous implicit type (seems to be both object and inline array)."
  else
    type = ('array' if isArr) or ('object' if isObj) or 'string'
    cb null, type


# Finds *typeSpecification* object for given *Named Type* or *Property Member*
# or *Value Member* tree node.
findTypeSpecification = (node) ->
  if node.base?.typeSpecification?
    # Top-level *Named Type* node.
    node.base.typeSpecification
  else
    # *Property Member* or *Value Member* node
    node.valueDefinition?.typeDefinition?.typeSpecification


# Takes top-level *Named Type* or *Property Member* or *Value Member* tree node.
# Provides a sort of 'simple type specification object':
#
#     name: ...
#     nested: [...]
#
# In case it isn't able to resolve this *typeSpecification* object with
# base types only, ends with an error (Boutique builds no symbol table,
# so it can't resolve any possible inheritance).
resolveType = (node, cb) ->
  typeSpec = findTypeSpecification node
  simplifyTypeSpecification typeSpec, (err, simpleTypeSpec) ->
    if err
      cb err
    else if not simpleTypeSpec
      resolveImplicitType node, (err, implicitType) ->
        cb err, name: implicitType
    else
      cb null, simpleTypeSpec


module.exports = {
  resolveType
}
