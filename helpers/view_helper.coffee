deps = [
    'application'
    {node: 'handlebars', common: '!Handlebars', amd: 'handlebars'}
    {node: 'lodash', common: '!_', amd: 'lodash'}
    'umd-stdlib/core/i18next'
    {node: 'moment', common: '!moment', amd: 'moment'}
]
factory = (require, application, Handlebars, _, i18n, moment)->
    slice = Array::slice

    # http://i18next.com/pages/doc_features.html
    Handlebars.registerHelper 't', ->
        args = arguments
        if typeof args[0] is 'undefined'
            return ''

        options = args[args.length - 1].hash
        result = i18n.t args[0], options
        new Handlebars.SafeString result

    Handlebars.registerHelper 'url', (type, name, urlParams, queryParams) ->
        if arguments.length is 3
            urlParams = arguments[arguments.length - 1].hash
            queryParams = false
        else if arguments.length is 4
            queryParams = arguments[arguments.length - 1].hash

        application.getUrl type, name, urlParams, query: queryParams

    operate = (operator, left, middle, right)->
        if /^(?:eq|equal|equals|=)$/.test operator
            bool = left is middle
        else if /^(?:gt|greater|>)$/.test operator
            bool = left > middle
        else if /^(?:gte|>=)$/.test operator
            bool = left >= middle
        else if /^(?:lt|less|<)$/.test operator
            bool = left < middle
        else if /^(?:lte|<=)$/.test operator
            bool = left <= middle
        else if 'between' is operator
            bool = left >= middle and left <= right
        bool

    Handlebars.registerHelper 'operate', ->
        options = arguments[arguments.length - 1]
        if arguments.length > 1
            argv = slice.call arguments, 0, arguments.length - 1
            bool = operate.apply null, argv 
        if bool then options.fn @ else options.inverse @

    Handlebars.registerHelper 'template', (fn, context)->
        type = typeof fn

        if 'function' is type
            return new Handlebars.SafeString fn context

        # Asynchronous require within an handlebar's template is ticky to handle
        # Path must be absolute because relative path will be relative to this file
        if 'string' is type
            fn = require fn
            if 'function' is typeof fn
                return new Handlebars.SafeString fn context

    Handlebars.registerHelper 'date', (date, sourceFormat, destinationFormat)->
        date = moment.utc date, sourceFormat
        moment(date.toDate()).format destinationFormat

    Handlebars.registerHelper 'isIE', ->
        options = arguments[arguments.length - 1]
        if document.documentMode
            if arguments.length is 1
                # no number given
                bool = true
            else if arguments.length is 2
                # no operator given
                bool = document.documentMode is arguments[0]
            else
                # operator given
                operator = arguments[0]
                number = arguments[1]
                right = if arguments.length is 3 then null else arguments[2]
                bool = operate operator, document.documentMode, number, right

            if bool then options.fn @ else options.inverse @
        else
            options.inverse @

    Handlebars.registerHelper 'result', (context, prop)->
        _.result context, prop

    Handlebars.registerHelper 'apply', (context, prop)->
        args = slice.call arguments, 2, -1
        context[prop].apply context, args

    Handlebars.registerHelper 'debugger', (context)->
        debugger
        return

    Handlebars.registerHelper 'htmlAttr', (attributes)->
        if not _.isObject attributes
            return ''

        attrs = []
        str = []

        for own attr, value of attributes
            type = typeof value
            if value is null or value is true
                str[str.length] = ' ' if str.length is 0
                str[str.length] = attr
            else if type is 'string' or type is 'number'
                str[str.length] = ' ' if str isnt ''
                str[str.length] = "#{attr}=\"#{value}\""

        ' ' + str.join ''

    Handlebars.registerHelper 'baseUrl', ->
        application.get('baseUrl')

    Handlebars.registerHelper 'pick', (context)->
        args = slice.call arguments, 1, -1
        options = arguments[arguments.length - 1]
        options.fn _.pick context, args

    Handlebars.registerHelper 'variables', (number)->
        args = []
        options = arguments[arguments.length - 1]
        
        for i in [0...number] by 1
            args[i] = {}
        
        options.fn @, data: options.data, blockParams: args

    Handlebars.registerHelper 'extend', (context)->
        _.extend context, arguments[arguments.length - 1].hash
        return

    Handlebars.registerHelper 'stringify', (context)->
        JSON.stringify context

    return