deps = [
    {common: '!async', amd: 'async'}
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {common: '!jQuery', amd: 'jquery'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    'umd-stdlib/core/ClientUtil'
    'umd-stdlib/core/RouterEngine'
    'umd-stdlib/core/i18next'
    'umd-stdlib/core/resources'
    'umd-stdlib/core/QueryString'
    'umd-stdlib/core/patch'
    'umd-stdlib/core/modernizr.custom'
]

factory = (require, async, _, $, Backbone, ClientUtil, RouterEngine, i18n, resources, QueryString)->

    _flip = (obj)->
        res = {}
        for key, value of obj
            res[value] = key
        res

    initConfig = (application, config)->
        # https://www.flag-sprites.com/
        defaultConfig =
            'title': 'Buma'
            'languages':
                'fr': 'fr-FR'
                'en': 'en-GB'
            'flags':
                'en-GB': 'gb'
                'fr-FR': 'fr'
            'engines':
                'controller':
                    'default':
                        'router':
                            'route': '{resource:(app|web)}/{language}/{module}/{controller}/{action}/*'
                            'defaults':
                                'resource': 'app'
                                'language': 'en'
                                'module': 'default'
                                'controller': 'home'
                                'action': 'index'
                            'title': 'route': '{module}.{controller}.{action}.title'
                        'path':
                            'route': '{module}/controllers/{controller}'
                            'suffix': 'Controller'
                            'camel': true
                        'title': 'route': '{module}.{controller}.{action}.title'
                'view':
                    'default':
                        'router':
                            'route': '{resource:(app|web)}/{language}/{module}/{controller}/{action}'
                            'defaults':
                                'resource': 'app'
                                'language': 'en'
                                'module': 'default'
                                'controller': 'home'
                                'action': 'index'
                        'path':
                            'route': '{module}/views/{controller}/{action}'
                            'suffix': 'View'
                            'camel': true
                        'title': 'route': '{module}.{controller}.{action}.title'
                'template':
                    'default':
                        'router':
                            'route': '{resource:(app|web)}/{language}/{module}/{controller}/{action}'
                            'defaults':
                                'resource': 'app'
                                'language': 'en'
                                'module': 'default'
                                'controller': 'home'
                                'action': 'index'
                        'path': 'route': '{module}/views/{controller}/templates/{action}'
                        'title': 'route': '{module}.{controller}.{action}.title'
                    'i18n':
                        'router':
                            'route': '{resource:(app|web)}/{language}/{module}/{controller}/{action}'
                            'defaults':
                                'resource': 'app'
                                'language': 'en'
                                'module': 'default'
                                'controller': 'home'
                                'action': 'index'
                        'path': 'route': '{module}/views/{controller}/templates/{action}.{language}'
                        'title': 'route': '{module}.{controller}.{action}.title'
            'path':
                'model':
                    'route': '{module}/models/{model}'
                    'suffix': 'Model'
                    'camel': true
                'view':
                    'route': '{module}/views/{view}'
                    'suffix': 'View'
                    'camel': true
                'template': 'route': '{module}/views/templates/{template}'

        config = _.extend defaultConfig, config
        config.locales = _flip config.languages

        if appConfig.resource
            for prop in ['controller', 'view', 'template']
                if config.engines.hasOwnProperty prop
                    for name of config.engines[prop]
                        tmp = config.engines[prop][name]
                        tmp.router.defaults.resource = appConfig.resource

        application.set 'title', config.title
        application.set 'config', config
        application.set 'baseUrl', appConfig.baseUrl
        Object.freeze? config

        testNode = document.createElement 'input'
        isInputSupported = 'oninput' of testNode and ((not document.hasOwnProperty 'documentMode') or document.documentMode > 9)
        testNode = null
        if isInputSupported
            textchange = 'input'
        else
            textchange = 'textchange'

        application.set 'textchange', textchange

        lng = (navigator.browserLanguage or navigator.language).slice 0, 2
        lng = config.languages.hasOwnProperty(lng) and lng

        allConfigEngines = {controller: [], view: [], template: []}
        application.set 'engines', allConfigEngines
        allConfigEnginesByName = {controller: {}, view: {}, template: {}}
        application.set 'enginesByName', allConfigEnginesByName

        for type in ['controller', 'view', 'template']
            engines = config.engines[type]
            for name of engines
                if lng
                    # set language according to browser language
                    engines[name].router.defaults.language = lng

                configEngine =
                    name: name
                    type: type

                for key of engines[name]
                    configEngine[key] = new RouterEngine engines[name][key]

                if name is 'default'
                    allConfigEngines[type].unshift configEngine
                else
                    allConfigEngines[type].push configEngine

                allConfigEnginesByName[type][name] = configEngine

            for engine, index in allConfigEngines[type]
                engine.index = index

        application.set 'clientDefaultRouteEngine', allConfigEngines.controller[0].router
        application.set 'clientModelEngine', new RouterEngine(config.path.model)
        application.set 'clientViewEngine', new RouterEngine(config.path.view)
        application.set 'clientTemplateEngine', new RouterEngine(config.path.template)

        return

    initInternationalize = (application, params)->
        # Initiate the translation
        i18n.init resStore: resources
        application.set 'languages', application.get('config').languages

        language = params.language
        locale = application.getLocale language
        
        i18n.setLng locale
        application.set locale: locale, language: language

        application.on 'change:language', _setLanguage, application
        application.on 'change:locale', _setLocale, application

        # Add choice handler
        ###
        (function(application) {
            'use strict';

            var resources = {
                'en-GB': {
                    translation: {
                        'girls-and-boys': {
                            choice: {
                                0: '$t(girls, {"choice": __girls__}) and no boys',
                                1: '$t(girls, {"choice": __girls__}) and a boy',
                                2: '$t(girls, {"choice": __girls__}) and __choice__ boys'
                            }
                        },
                        girls: {
                            choice: {
                                0: 'No girls',
                                1: '__choice__ girl',
                                2: '__choice__ girls',
                                6: 'More than 5 girls'
                            }
                        }
                    }
                }
            };

            application.addResources(resources);

            console.log(i18n.t('girls-and-boys', {choice: 2, girls: 3})); // -> 3 girls and 2 boys
            console.log(i18n.t('girls-and-boys', {choice: 7, girls: 0})); // -> No girls and 7 boys
            console.log(i18n.t('girls-and-boys', {choice: 0, girls: 0})); // -> No girls and no boys
            console.log(i18n.t('girls-and-boys', {choice: 0, girls: 1})); // -> 1 girl and no boys
            console.log(i18n.t('girls-and-boys', {choice: 1, girls: 0})); // -> No girls and a boy
            console.log(i18n.t('girls-and-boys', {choice: 2, girls: 7})); // -> More than 5 girls and 2 boys

        }(require('application')));
        ###
        i18n.options.objectTreeKeyHandler = (key, value, lng, ns, options)->
            if not options.hasOwnProperty('choice') or 'number' isnt typeof options.choice or not value.hasOwnProperty('choice') or 'object' isnt typeof value.choice
                return "key '#{ns}:#{key} (#{lng})' returned an object instead of string."

            keys = Object.keys value.choice
            choice = keys[0]
            value = options.choice
            for num in keys
                if value >= num
                    choice = num

            i18n.t "#{key}.choice.#{choice}", options

        return

    startClient = ->
        if ClientUtil.isLocationFile()
            location = ClientUtil.getHashLocation()

            # Push state is not allowed for files
            hasPushState = false

            _startClient.call @, location, hasPushState
        else
            # First try to find a matching route in hash
            usedHash = true
            location = ClientUtil.getHashLocation()

            # Push state will be allowed if browser has push state feature
            hasPushState = Modernizr.history

            if location.pathname is ''
                usedHash = false
                location = ClientUtil.getPathLocation()

            if location.pathname is ''
                _startClient.call @, location, hasPushState
                return

            @router.findRouter {location}, {try: true}, (err, rendable, result)=>
                if err
                    if usedHash
                        # try in pathname
                        location = ClientUtil.getPathLocation()
                        @router.findRouter {location}, {try: true}, (err, rendable, result)=>
                            if result
                                {type, name, url: params, query} = result
                                engine = @get('enginesByName')[type][name].router

                            _startClient.call @, location, hasPushState, params, engine
                            return
                    else
                        _startClient.call @, location, hasPushState
                else
                    {type, name, url: params, query} = result
                    _startClient.call @, location, hasPushState, params, @get('enginesByName')[type][name].router
                return

        return

    _startClient = (location, hasPushState, params, engine)->
        @hasPushState = hasPushState

        url = location.pathname
        queryString = location.search
        anchor = location.hash
        baseUrl = @get 'baseUrl'

        if hasPushState
            engineHasBaseUrl = true
            @eachEngine (engine)-> engine.router.setBaseUrl baseUrl
            if anchor and anchor.charAt(0) is '!'
                anchor = '#' + anchor.substring 1
        else
            @eachEngine (engine)-> engine.router.setBaseUrl '#'
            if anchor and anchor.charAt(0) is '#'
                anchor = '!' + anchor.substring 1

        if not engine
            # no route matches, use default route
            engine = @get 'clientDefaultRouteEngine'

            url = RouterEngine::removeLeadTrail url
            if engineHasBaseUrl
                params = engine.getParams url
            else
                baseUrl = RouterEngine::removeLeadTrail baseUrl
                params = engine.getParams url.substring baseUrl.length

        if appConfig.resource
            params.resource = appConfig.resource

        # get href with correct resource
        url = engine.getUrl params

        currUrl = url + queryString + anchor
        if not hasPushState
            window.location.href = currUrl
        else if url.charAt(0) isnt '/'
            url = '/' + url

        @eachEngine (engine)-> engine.router.defaults.language = params.language

        initInternationalize @, params

        self = @
        self.beforeHistory params, ->
            startHistory self, currUrl, url
            return

        return

    startHistory = (application, currUrl, url)->
        hasPushState = application.hasPushState

        # Start history navigtion
        Backbone.history.start pushState: hasPushState, silent: true

        # TODO : document why I am doing this. BAD I forgot
        currUrl = RouterEngine::removeLeadTrail currUrl
        if window.location.pathname is '/'
            oldUrl = RouterEngine::removeLeadTrail window.location.search + window.location.hash
        else
            oldUrl = RouterEngine::removeLeadTrail window.location.pathname + window.location.search + window.location.hash

        # TODO : document why I am doing this. BAD I forgot
        # Load url doesn't change the route but triggers it no matter what
        # and url in dispatch is the given url
        # exemple: http://smbape.com/#web/en/default/index/index?param=value!log_2
        #   loadUrl: dispatch(url, options) => http://smbape.com/#web/en/default/index/index?param=value!log_2
        #   navigate: dispatch(url, options) => http://smbape.com/#web/en/default/index/index?param=value
        if currUrl isnt oldUrl 
            if hasPushState
                application.router.navigate currUrl,
                    trigger: false
                    replace: true
            else
                resource = if appConfig.resource then '?resource=' + appConfig.resource else ''
                window.location.href = application.get('baseUrl') + resource + '#' + currUrl
        Backbone.history.loadUrl currUrl

        $document = $(document)

        # on IE < 9 which is not defined on click event, only on mouseup and mousedown
        if document.documentMode < 9
            which = 0
            $document.on 'mouseup mousedown', (evt)->
                which = evt.which

        $document.on 'click', 'a[href]', (evt) ->

            # Allow prevent propagation
            return if evt.isDefaultPrevented()

            if not (document.documentMode < 9)
                which = evt.which

            # Only trigger router on left click with no fancy stuff
            # allowing open in new tab|window shortcut
            return if which isnt 1 or evt.altKey or evt.ctrlKey or evt.shiftKey

            # Only cares about non anchor click
            href = this.getAttribute 'href'
            _char = href.charAt(0)

            if _char is '!'
                evt.preventDefault()
                application.setLocationHash href
                return

            if _char is '#'
                if application.hasPushState
                    evt.preventDefault()
                    application.setLocationHash href
                    return

                hash = href.substring 1
                if document.getElementById(hash) or $("[name=#{hash.replace(/([\\\/])/g, '\\$1')}]")[0]
                    evt.preventDefault()
                    application.setLocationHash href
                    return

            # Get the absolute root.
            root = ClientUtil.getLocationRoot()

            # Our Router only cares about relative path
            return if this.href.slice(0, root.length) isnt root
            href = href.slice(root.length) if href.slice(0, root.length) is root

            # Stop the default event to ensure the link will not cause a page refresh.
            evt.preventDefault()

            # Avoid trigger router for irrelevant click
            if href is '#' or href is ''
                return

            # `Backbone.history.navigate` is sufficient for all Routers and will
            # trigger the correct events. The Router's internal `navigate` method
            # calls this anyways.    The fragment is sliced from the root.
            application.router.navigate href,
                trigger: true
                replace: false
            , evt

            return

        application.trigger 'ready'
        return

    _setLanguage = (application, language, options)->
        application.setLocale application.getLocale(language), options

    _setLocale = (application, locale, options)->
        return if i18n.lng() is locale

        language = application.get('config').locales[locale]

        i18n.setLng locale

        application.eachEngine (engine)-> engine.router.defaults.language = language

        {type, name, url: params, query} = application.router.getParameters()

        params.language = language

        engine = application.get('enginesByName')[type][name].router

        location = application.getLocation()

        url = engine.getUrl(params) + location.search + location.hash

        Backbone.history.navigate url, trigger: true, replace: false

        return

    class StandardApplication extends Backbone.Model
        constructor: (config)->
            super {}, {}, config

        initialize: (attributes, options, config)->
            @tasks = []
            initConfig @, config

            @once 'start', startClient, @

            @addInitializer (options)->
                # IE special task
                return if typeof document.documentMode is 'undefined'

                if document.documentMode < 9
                    depsLoader.loadScript @get('baseUrl') + 'vendor/html5shiv.js'
                    depsLoader.loadScript @get('baseUrl') + 'vendor/respond.sm.js'

                if document.documentMode < 8
                    # IE < 8 fetch from cache
                    $.ajaxSetup cache: false

                # Add IE-MODE-xx to body. For css
                if typeof document.body.className is 'string' and document.body.className.length > 0
                    document.body.className += ' '
                document.body.className += 'IE-MODE-' + document.documentMode
                return

            @addInitializer (options)->
                # Allow to call Backbone validation on model.
                _.extend Backbone.Model.prototype, Backbone.Validation.mixin

                # Since we are automatically updating the model, we want the model
                # to also hold invalid values, otherwise, we might be validating
                # something else than the user has entered in the form.
                # See: http://thedersen.com/projects/backbone-validation/#configuration/force-update
                Backbone.Validation.configure forceUpdate: true

                _.extend Backbone.Validation.callbacks,
                    valid: ClientUtil.valid
                    invalid: ClientUtil.invalid

                return

            @addInitializer @initLayout
            @addInitializer @initRouter
            @addInitializer @initHelpers
            return

        beforeHistory: (queryParams, next)->
            next()
            return

        addInitializer: (fn)->
            if 'function' is typeof fn
                if fn.length > 2
                    throw new Error 'Initializer function must be a function waiting for 2 arguments a most'

                @tasks.push fn
            return

        start: (options)->
            async.eachSeries @tasks, (fn, next)=>
                if fn.length is 2
                    fn.call @, options, next
                else
                    fn.call @, options
                    next()
                return
            , =>
                @trigger 'start'
                return
            @

        initLayout: (options, next)->
            self = @
            require ['umd-stdlib/core/common', 'custom/app-layout'], (com, template)->
                self.layout = new com.gen.views.LayoutView
                    template: template
                    el: '#container'

                    regions:
                        header: '#header'
                        menu: '#menu'
                        content: '#content'
                        footer: '#footer'
                self.layout.render()
                next()
                return
            return

        initRouter: (options, next)->
            self = @
            require ['umd-stdlib/core/StandardRouter'], (Router)->
                self.router = new Router()
                next()
                return
            return

        initHelpers: (options, next)->
            require ['umd-stdlib/helpers/view_helper'], ->
                next()
                return
            return

        eachEngine: (type, callback)->
            engines = @get 'engines'

            if 'function' is typeof type
                callback = type
                type = null

            if type
                for engine in engines[type]
                    callback engine
                return

            for type in ['controller', 'view', 'template']
                for engine in engines[type]
                    callback engine
            return

        addResources: (resources)->
            if _.isPlainObject resources
                for lng of resources
                    if _.isPlainObject resources[lng]
                        for nsp of resources[lng]
                            i18n.addResourceBundle lng, nsp, resources[lng][nsp], true
            return

        setLanguage: (language, options)->
            if typeof language isnt 'string' or language.length is 0
                language = @getLanguage()
            _setLanguage @, language, options

        setLocale: (locale, options)->
            return false if typeof locale isnt 'string'
            language = @get('config').locales[locale]
            @set 'language', language, _.extend {silent: true}, options
            @set 'locale', locale
            return true

        getCurrentParams: -> @router.getParams()

        getLanguage: -> @getCurrentParams().language

        getLocale: (language)->
            language = @getLanguage() if typeof language isnt 'string'
            @get('languages')[language]

        getLanguages: -> _.keys @get 'languages'

        getUrl: (type, name, urlParams, queryParams)->
            engines = @get('enginesByName')
            if engines.hasOwnProperty type
                engines = engines[type]
                if engines.hasOwnProperty name
                    engine = engines[name].router
                    engine.getUrl urlParams, query: queryParams

        getLocation: (url)->
            if @hasPushState
                ClientUtil.getPathLocation url
            else
                ClientUtil.getHashLocation url

        getQueryString: ->
            if @hasPushState
                search = window.location.search
            else
                search = ''
                splitQueryReg = /^#[^?]*(\?[^?]+)$/
                split = splitQueryReg.exec window.location.hash
                if Array.isArray split
                    search = split[1]
            search

        setLocationHash: (hash)->
            hash or (hash = @getLocation().hash)
            return false if not hash
            if hash.charAt(0) in ['#', '!']
                hash = hash.substring 1
            return false if hash.length is 0

            if @hasPushState
                if window.location.hash is '#' + hash
                    element = document.getElementById(hash) or $("[name=#{hash.replace(/([\\\/])/g, '\\$1')}]")[0]
                    element.scrollIntoView() if element
                else
                    window.location.hash = '#' + hash
            else
                location = ClientUtil.getHashLocation()
                location.hash = '!' + hash
                window.location.hash = '#' + location.pathname + location.search + location.hash
                element = document.getElementById(hash) or $("[name=#{hash}]")[0]
                element.scrollIntoView() if element

            return true

        getQueryParams: ->
            search = @getQueryString()
            QueryString.parse search
