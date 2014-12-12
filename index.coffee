
async = require 'async'

serializers = require './lib/serializers'
{selectFormat} = require './lib/formatselection'


jsonSchemaV4 =
  lib: require './lib/formats/jsonschema-v4'
  serialize: serializers.json

formats =
  'application/schema+json': jsonSchemaV4
  'application/schema+json; profile="http://json-schema.org/schema"': jsonSchemaV4
  'application/schema+json; profile="http://json-schema.org/draft-04/schema"': jsonSchemaV4


represent = ({ast, contentType, options}, cb) ->
  ast ?= {}
  contentType ?= 'application/schema+json'
  options ?= {}

  selectFormat contentType, Object.keys formats, (err, selectedContentType) ->
    return cb err if err
    return cb new Error "Content-Type '#{contentType}' is not implemented." unless selectedContentType

    {lib, serialize} = formats[selectedContentType]

    async.waterfall [
        (next) ->
          lib.transform ast, options, next
      ,
        (obj, next) ->
          serialize obj, next

    ], (err, repr) ->
      cb err, repr, selectedContentType


module.exports = {
  represent
}
