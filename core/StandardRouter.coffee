deps = [
    'application'
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    'umd-stdlib/core/ClientUtil'
    'umd-stdlib/core/i18next'
    'umd-stdlib/core/StackArray'
    'umd-stdlib/core/QueryString'
]

factory = (require, application, _, Backbone, ClientUtil, i18n, StackArray, QueryString)->
    currentController = null
    popinContainer = null

    getMainContainer = ->
        content =  application.layout.regions.content
        (content and content.$el) or $ document.body

    notifyError = (msg, err, container)->
        $().toastmessage 'showToast',
            text     : i18n.t msg
            position : 'top-right'
            type     : 'error'
            sticky   : true
        throw err if err
        return

    onRender = (view, container)->
        application.trigger 'render', view, container
        return

    onBeforeRender = (view, container)->
        apptitle = application.get 'title'

        title = _.result view, 'title' if view

        if typeof title is 'string'
            document.title = "#{i18n.t(title)} - #{apptitle}"
        else
            document.title = apptitle

        application.trigger 'before:render', view, container
        return

    ensurePopin = ->
        if popinContainer is null
            popinContainer = document.createElement 'div'
            popinContainer.className = 'page-popin'
            document.body.appendChild popinContainer

            $popinContainer = $(popinContainer)

            # colorbox listen on all click events
            # and reload every time there is a click
            # stopPropagation when popin container is reach
            $popinContainer.on 'click', (evt)->
                evt.stopPropagation()
                return

            $popinContainer.on 'click', '.popin-close', (evt)->
                evt.preventDefault()
                $.colorbox.close()
                return

        popinContainer

    # http://fancyapps.com/colorbox/#docs
    colorbox = (selector, options)->
        $(selector[0]).colorbox _.extend
            href        : -> ensurePopin()
            open        : true
            inline      : true
            reposition  : true
            scrolling   : true
            # transition  : 'none'
            maxWidth    : 800
            maxHeight   : 600
            width       : '100%'
            height      : '100%'
        , options
        return

    # url, type, config index
    cache = routing: {}

    _getConfig = (type, name)->
        configs = application.get('engines')[type]

        if typeof name isnt 'undefined'
            config = application.get('enginesByName')[type][name]
            if not config
                errback(new Error "No such router engine '#{name}' for type '#{type}'")
                return
            _i = config.index

        [configs, _i]

    tryConfig = (url, config, next)->
        engine = config.router
        pathEngine = config.path

        try
            urlParams = engine.getParams url
        catch err
            next err
            return

        path = pathEngine.getFilePath urlParams

        require [path], (exported)->
            next null, exported, urlParams, path, config
            return
        , next

        return

    tryController = ({router, location, name}, options, callback, errback)->
        url = location.pathname
        queryParams = QueryString.parse location.search

        [configs, index] = _getConfig 'controller', name
        if typeof index isnt 'undefined'
            _i = index
            _len = index + 1
        else
            _i = 0
            _len = configs.length

        iterate = (err, exported, urlParams, path, config)->
            # if err and err.code isnt 'NO_MATCH'
            #     errback err
            #     return

            if exported
                if options.try is true
                    controller = exported
                else
                    title = config.title.getUrl urlParams if config.title
                    controller = new exported
                        title: title
                        params: _.extend {}, urlParams, queryParams
                        queryParams: queryParams
                        urlParams: urlParams
                        request: url
                        router: router # can be used to change for redirection from inside controller
                        engine: configs[_i - 1].router

                    if not (method = controller.getMethod urlParams) or typeof controller[method] isnt 'function'
                        controller = null

                if controller
                    callback controller, {name: config.name, type: config.type, query: queryParams, url: urlParams}
                    return

            if _i is _len
                errback err
                return

            tryConfig url, configs[_i++], iterate

            return

        iterate()

        return

    tryView = ({application, location, name}, options, callback, errback)->
        url = location.pathname

        [configs, index] = _getConfig 'view', name
        if typeof index isnt 'undefined'
            _i = index
            _len = index + 1
        else
            _i = 0
            _len = configs.length

        iterate = (err, exported, urlParams, path, config)->
            # if err and err.code isnt 'NO_MATCH'
            #     errback err
            #     return

            if exported
                title = config.title.getUrl urlParams if config.title
                view = new exported {title: title}
                callback view, {name: config.name, type: config.type, url: urlParams}
                return

            if _i is _len
                errback err
                return

            tryConfig url, configs[_i++], iterate

            return

        iterate()

        return

    tryTemplate = ({application, location, name}, options, callback, errback)->
        url = location.pathname

        [configs, index] = _getConfig 'template', name
        if typeof index isnt 'undefined'
            _i = index
            _len = index + 1
        else
            _i = 0
            _len = configs.length

        iterate = (err, exported, urlParams, path, config)->
            # if err and err.code isnt 'NO_MATCH'
            #     errback err
            #     return

            if not err and 'undefined' isnt typeof exported
                title = config.title.getUrl urlParams if config.title
                callback {data: exported, title: title}, {name: config.name, type: config.type, url: urlParams}
                return

            if _i is _len
                errback err
                return

            tryConfig url, configs[_i++], iterate

            return

        iterate()

        return

    tries =
        controller: tryController
        view: tryView
        template: tryTemplate

    setRoutingCache = (pathname, type, name)->
        cache.routing[pathname] = [type, name]
        return

    findRouter = ({router, location}, options, next)->
        types = ['controller', 'view', 'template']
        _len = types.length

        if cache.routing.hasOwnProperty location.pathname
            [type, name] = cache.routing[location.pathname]
            _i = types.indexOf type
        else
            _i = 0

        iterate = (err)->
            # if err and err.code isnt 'NO_MATCH'
            #     next err
            #     return

            if _i is _len
                if not err
                    err = new Error 'No matching routes where found'
                    err.code = 'NO_MATCH'
                next err
                return

            type = types[_i++]

            tries[type] {router, location, name}, options, (rendable, result)->
                setRoutingCache location.pathname, result.type, result.name
                if _.isObject rendable
                    rendable.popin = options.container is 'popin'
                next null, rendable, result
                return
            , iterate

            return

        iterate()

        return

    class StandardRouter extends Backbone.Router
        notifyError: notifyError
        routes: '*url': 'dispatch'
        findRouter: findRouter
        setRoutingCache: setRoutingCache

        constructor: ->
            super
            @_history = new StackArray()
            @_events = []
            @_current = null
            hooks = @hooks = {}
            context = application.get 'baseUrl'
            application.eachEngine 'template', (engine)->
                {type, name} = engine
                hooks[type] or (hooks[type] = {})
                if not hooks[type][name]
                    hooks[type][name] = []
                    if context and context.length > 0
                        hook = (html, type, name, params, query)->
                            html = html.replace /\b(href|src|data-main)="(?!mailto:|https?\:\/\/|[\/#!])([^"]+)/g, "$1=\"#{context}$2"
                        hooks[type][name][0] = hook
                return

        _extractParameters: (route, fragment) ->
            # return fragment as is
            # parsing is done in dispatch
            [fragment or null]

        getPrevUrl: ->
            @_history.get -1

        addHistory: (url)->
            @_history.push url
            return @

        back: ->
            url = @_history.get -2
            @navigate url,
                trigger: true
                replace: false
            return

        navigate: (fragment, options = {}, evt)->
            if _.isObject evt
                target = $ evt.target

                if target[0].nodeName isnt 'A'
                    # faster way to do a target.closest('a')
                    target = target[0]
                    while target and target.nodeName isnt 'A'
                        target = target.parentNode
                    target = $ target

                if target.hasClass 'popin'
                    target = target[0]
                    attributes = target.attributes
                    popts = {}
                    for attr in attributes
                        {name, value} = attr
                        if 'data-' is name.substring 0, 5
                            popts[name.substring(5)] = value

                    options = _.extend
                        container: 'popin'
                        popts: popts
                    , options
                    if not application.get 'hasPushState'
                        fragment = fragment.substring 1
                    @dispatch fragment, options
                    return @

            location = application.getLocation fragment
            if location.pathname.charAt(0) in ['/', '#']
                location.pathname = location.pathname.substring(1)

            if options.force
                Backbone.history.fragment = null
                options.trigger = true
            else if @_location and location.pathname is @_location.pathname and location.search is @_location.search
                location = application.getLocation fragment
                application.setLocationHash location.hash
                return @

            options.location = location
            super

        dispatch: (url, options)->

            if url is null
                clientDefaultRouteEngine = application.get 'clientDefaultRouteEngine'
                @navigate clientDefaultRouteEngine.getDefaultUrl()
                return

            if typeof options is 'string'
                url += '?' + options
                options = {}
            else if not _.isPlainObject options
                options = {}

            location = options.location or application.getLocation url
            url = location.pathname + location.search

            prevUrl = @getPrevUrl()

            if not application.get('hasPushState') and document.getElementById url
                # Scroll into view has alreaby been done
                url = prevUrl + '!' + url
                @navigate url, {trigger: false, replace: true}
                return

            if options.hasOwnProperty 'container'
                container = options.container
                if container is 'popin'
                    isPopin = true
                    container = $ ensurePopin()
                else
                    @notifyError i18n.t 'error.container'
                    return

            mainContainer = getMainContainer()
            if not container or container is mainContainer
                container = mainContainer
                @addHistory url

            self = router = @

            application.trigger 'loading', {container, isPopin, url, options}
            findRouter {router, location}, options, (err, rendable, result)->
                if err
                    if err.code is 'NO_MATCH' and isPopin
                        # let the server handle

                        root = ClientUtil.getLocationRoot()
                        if url.charAt(0) is '/'
                            url = root + url
                        else if url.charAt(0) is '#'
                            url = root + '/' + url.substring 1
                        else
                            url = root + '/' + url

                        colorbox container,
                            iframe: true
                            href: url

                        application.trigger 'loaded', url, options, {container, isPopin}
                        return

                    # User notification
                    text = 'Error while retriving params for "' + url + '" \n'
                    console.warn text, err.stack
                    self.notifyError err.message, err, container

                    self.navigate prevUrl, {trigger: false, replace: true} if prevUrl
                    return

                self.run rendable, result, {location, container, mainContainer, isPopin}, options

                return

            return

        run: (rendable, result, {location, container, mainContainer, isPopin}, options)->
            {type, name, url, query} = result

            if type is 'controller'
                isRendable = true
                rendable.set('container', container)
            else if type is 'view'
                isRendable = true

            if mainContainer is container
                isMainContainer = true
                if @_current isnt null
                    @_current.destroy()
                    @_current = null

                @_url = {type, name, url, query}

                {pathname, search, hash} = location
                @_location = {pathname, search, hash}

                @_current = rendable if isRendable

            # link may change the language
            application.setLanguage()

            _onBeforeRender = (rendable)->
                onBeforeRender rendable, container
                return

            _onRender = (rendable)->
                if isMainContainer
                    container.closest(':scrollable(vertical)').scrollTop 0
                    application.trigger 'navigate', result

                images = container.find('img')
                if images.length is 0
                    application.setLocationHash()
                else
                    waiting = images.length
                    images.each (index, element)->
                        loaded = false
                        complete = (evt)->
                            if not loaded && --waiting is 0
                                loaded = true
                                application.setLocationHash()
                            return

                        if this.complete
                            complete()
                        else
                            $(this)
                                .one('load', complete)
                                .one('error', complete)

                        return

                onRender rendable, container
                application.trigger 'loaded', {container, type, name, url, query}

                return

            if isPopin
                if isRendable
                    options.popts.onCleanup = ->
                        rendable.destroy()
                        return

                colorbox container, options.popts

                if isRendable
                    rendable.once 'render', ->
                        ($.colorbox.element()).colorbox options.popts
                        return
            else if isRendable
                rendable.once 'before:render', _onBeforeRender
                rendable.once 'render', _onRender

            if 'controller' is type
                rendable.run()
            else if 'view' is type
                container.empty().append rendable.el
                rendable.render()
            else
                _onBeforeRender rendable
                template = rendable.data

                if 'string' is typeof template
                    html = template
                else if 'function' is typeof template
                    html = template()

                for hook in @hooks[type][name]
                    if 'function' is typeof hook
                        html = hook.call @, html, type, name, url, query
                container.empty().append html

                _onRender rendable

            return

        # {type, name, url, query}
        getParameters: -> @_url

        getParams: -> @_url.url if @_url

        getQueryParams: -> @_url.query if @_url

        getLanguage: -> @_url.url.language if @_url