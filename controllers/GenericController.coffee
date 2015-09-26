deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {node: 'events', common: '!EventEmitter', amd: 'eventEmitter'}
    'umd-stdlib/core/GenericUtil'
    'umd-stdlib/core/QueryString'
]
factory = (require, _, events, GenericUtil, QueryString)->
    EventEmitter = events.EventEmitter or events

    # Base class for all controllers
    # 
    # @example How to subclass a GenericController
    #   class CustomController extends GenericController
    #     must return on execution success
    #     run: (): ->
    # 
    return class GenericController extends EventEmitter

        # Constructor
        # @params attributes [Object] instance attributes
        # @option engine [Object] mandatory parameters
        # @option params [Object] mandatory parameters
        #   @option module [String]
        #   @option controller [String]
        #   @option action [String]
        # @params options [Object] instance  options
        constructor: (attributes, options)->
            @attributes = {}
            @options = {}

            if attributes instanceof GenericController
                controller = attributes
                attributes = controller.attributes
                @setOption controller.options

            @set attributes
            @setOption options
            return
        get: (key)->
            @attributes[key]
        set: (key, value)->
            if _.isObject(key) and typeof value is 'undefined'
                for _key, _value of key
                    @set _key, _value
                return
            return if typeof key isnt 'string' or key.length is 0
            method = 'set' + GenericUtil.StringUtil.firstUpper key
            if typeof @[method] is 'function'
                @[method] value
            else
                @attributes[key] = value
            return @
        getOption: (key)->
            @options[key]
        setOption: (key, value)->
            if _.isObject(key) and typeof value is 'undefined'
                for _key, _value of key
                    @setOption _key, _value
                return
            return if typeof key isnt 'string' or key.length is 0
            method = 'setOption' + GenericUtil.StringUtil.firstUpper key
            if typeof @[method] is 'function'
                @[method] value
            else
                @options[key] = value
            return @

        getMethod: (params)->

        # Default run method. Call method @params.action
        # @return [Boolean] true|undefined
        run: (params)->
            if _.isObject params
                @set 'params', params
            else
                params = @get 'urlParams'

            if not _.isObject params
                # console.warn 'Controller has no params attribute'
                return

            method = @getMethod params
            if typeof @[method] isnt 'function'
                error = new Error 'Method [' + method + '] is not valid for controller [' + @constructor.name + ']'
                error.code = 'METHOD_NOT_EXISTS'
                # console.warn error.message
                return error
            @[method]()
            return true

        getUrl: (params, options)->
            newParams = {}
            if 'boolean' is typeof options and options or (_.isObject(options) and options.reset)
                newParams = params
            else
                _.extend newParams, @get('urlParams'), params

            if not options.reset
                query = @get('queryParams')
            @get('engine').getUrl newParams, _.extend {query: query}, options

        getShortUrl: (params, options)->
            newParams = {}
            if 'boolean' is typeof options and options or (_.isObject(options) and options.reset)
                newParams = params
            else
                _.extend newParams, @get('urlParams'), params

            @get('engine').getShortUrl newParams

        # Destroy the controller
        destroy: ->
            @emit 'destroy'
            @removeAllListeners()
            for own prop of @
                @[prop] = null
            return