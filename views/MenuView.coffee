deps = [
    'umd-stdlib/core/common'
    'umd-stdlib/core/ClientUtil'
    './templates/menu-item'
]

factory = (require, com, ClientUtil, menuItemTemplate)->
    _ = com._
    application = com.application

    easingDuration = 250

    _urlDistance = (fromConfig, toConfig, config)->
        # url: urlParams
        # query: queryParams

        fromParams = _.pick fromConfig.url, (value)-> !!value
        toParams = _.pick toConfig.url, (value)-> !!value

        # mandatory params are required
        variables = config.router.getVariables()
        for prop in variables
            if fromParams[prop] isnt toParams[prop]
                return 0
            delete fromParams[prop]
            delete toParams[prop]

        # query params are required
        fromQuery = _.pick fromConfig.query, (value)-> !!value
        toQuery = _.pick toConfig.query, (value)-> !!value
        total = _.keys(fromQuery).length + _.keys(toQuery).length
        diffSearch = 0
        for prop of toQuery
            if fromQuery[prop] is toQuery[prop]
                delete fromQuery[prop]
            else
                return 0
        diffSearch += _.keys(fromQuery).length
        diffSearch = diffSearch / total if total isnt 0

        missingParams = 0
        total = _.keys(fromParams).length + _.keys(toParams).length
        for prop of fromParams
            if fromParams[prop] is toParams[prop]
                delete toParams[prop]
            else
                missingParams++
        missingParams += _.keys(toParams).length
        missingParams = missingParams / total if missingParams isnt 0

        1 - missingParams * 0.1 - diffSearch * 0.05

    class MenuView extends com.gen.views.View
        tagName: 'ul'
        className: 'menu menu-children nav nav-pills nav-stacked'
        events:
            'activate li.menu-item': (evt)->
                if evt.target is evt.currentTarget
                    $(evt.currentTarget).addClass 'active'
                else
                    $(evt.currentTarget).addClass 'opened'
                return
            'de-activate li.menu-item': (evt)->
                if evt.target is evt.currentTarget
                    $(evt.currentTarget).removeClass 'active'
                else
                    $(evt.currentTarget).removeClass 'opened'
                return
            'click .open-children': (evt)->
                evt.preventDefault()
                evt.stopImmediatePropagation()
                evt.stopPropagation()
                target = $(evt.currentTarget).closest('.menu-item')
                target.find('> .menu-children').show 'blind', {
                    complete: ->
                        target.addClass 'opened'
                        $(':focus').blur()
                        return
                }, easingDuration
                return
            'click .close-children': (evt)->
                evt.preventDefault()
                evt.stopImmediatePropagation()
                evt.stopPropagation()
                target = $(evt.currentTarget).closest('.menu-item')
                target.find('> .menu-children').hide 'blind', {
                    complete: ->
                        target.removeClass 'opened'
                        $(':focus').blur()
                        return
                }, easingDuration
                return

            'click .show-parent': (evt)->
                evt.preventDefault()
                evt.stopImmediatePropagation()
                evt.stopPropagation()

                target = $ evt.currentTarget
                parent = target.closest('.menu-item').parent().closest('.menu-item')

                target.closest('.menu-children').hide()
                toShow = parent.closest('.menu-children').find '> .menu-item'
                toShow.push parent.find('> .menu-header')[0]

                # ui-effect creates a div.wraper which make css to mess during animation
                # quick fix: hide parent, show children animate show parent
                _toShow = parent.closest('.menu-children')
                _toShow.hide()
                toShow.show()
                _toShow.show 'drop', {direction: 'right'}, easingDuration

                return
            'click .show-children': (evt)->
                evt.preventDefault()
                evt.stopImmediatePropagation()
                evt.stopPropagation()

                target = $ evt.currentTarget
                parent = target.closest '.menu-item'
                toHide = [target.closest('.menu-header')[0]]
                parent.parent().children().each (index, el)->
                    if el isnt parent[0]
                        toHide.push el
                    return
                toHide = $ toHide
                toShow = parent.find '> .menu-children'

                toHide.hide()
                toShow.show 'drop', {direction: 'left'}, easingDuration
                return
        constructor: (options = {})->
            super
            @itemTemplate = options.itemTemplate or menuItemTemplate
            @process options.menu
            @bindEvents()

        bindEvents: ->
            application.on 'navigate', @activate, @
            application.on 'change:locale', @onChangeLocale, @

            # Redo menu on resize to avoid unwanted effects of user actions
            # chrome android triggers resize on scroll
            window_width = null
            window_height = null
            render = =>
                width = $(window).width()
                height = $(window).height()
                return if window_width is width and window_height is height
                window_width = width
                window_height = height
                @render()
                return
            $(window).on 'resize', render
            @once 'destroy', ->
                $(window).off 'resize', render
                return

            return

        unbindEvents: ->
            application.off 'navigate', @activate, @
            application.off 'change:locale', @onChangeLocale, @
            return

        destroy: ->
            @unbindEvents()
            super

        onRender: ->
            xhtml = []
            for item in @map.children
                xhtml.push """<li id="#{item.id}" role="presentation" class="menu-item#{if item.children then ' has-children' else ''}">"""
                xhtml.push item.template item
                xhtml.push '</li>'
            @.$el.empty().html xhtml.join ''

            @activate()
            return @

        process: (menu)->
            @map =
                children: []
                urls: {}
                allItems: []

            @_process menu, @map.children
            return

        _process: (menu, parent)->
            for item in menu
                _item = _.pick item, ['href', 'title', 'attributes', 'className']
                _item.template = @itemTemplate
                if _item.attributes and _item.attributes.class
                    if _item.className
                        delete _item.attributes.class
                    else
                        _item.className = _item.attributes.class
                        delete _item.attributes.class
                _item.className or (_item.className = 'menu-header')

                if not _item.href and Array.isArray(item.children) and item.children.length > 0
                    _item.href = item.children[0].href
                    _item.ignore = true

                @_initItem _item

                @map.allItems.push _item
                parent.push _item

                if Array.isArray item.children
                    @_process item.children, _item.children = []

            return

        _initItem: (item)->
            # params and shortUrl are used by activation algorithm
            # the first item with maximum number of matches is the item to activate

            if typeof item.id is 'undefined'
                item.id = _.uniqueId 'menu-item-'

            type = item.href.type
            name = item.href.name
            engine = application.get('enginesByName')[type][name]

            url = engine.router.getUrl item.href.url
            application.router.setRoutingCache url, type, name

            url += '?' + QueryString.stringify(item.href.query) if item.href.query
            item.url = url
            item.params = engine.router.getParams url
            if not item.title and engine.title
                item.title = engine.title.getUrl item.params

            @map.urls[type] or (@map.urls[type] = {})
            @map.urls[type][name] or (@map.urls[type][name] = [])
            @map.urls[type][name].push item

            return

        onChangeLocale: ->
            @map.urls = {}
            for item in @map.allItems
                @_initItem item

            # Show new labels and links
            @render()
            return

        activate: ->
            @$el.find(':focus').blur()

            if @activeItem
                $item = @$el.find '#' + @activeItem.id
                $item.trigger 'de-activate'

            item = @getActiveItem application.router.getParameters()

            if item
                @activeItem = item
                $item = @$el.find '#' + @activeItem.id
                $item.trigger 'activate'

                if $(document).width() < 768
                    @$el.find('.menu-item.opened').find('> .menu-header > .show-children').click()
            else
                @activeItem = null

            return

        getActiveItem: (params)->
            return null if not params
            ret = null

            {type, name, url, query} = params
            config = application.get('enginesByName')[type][name]

            if @map.urls.hasOwnProperty(type) and @map.urls[type].hasOwnProperty(name)
                items = @map.urls[type][name]

                matched = 0
                for item in items
                    continue if item.ignore
                    tmpMatched = _urlDistance params, {url: item.params, query: item.href.query}, config
                    if tmpMatched > matched
                        ret = item
                        matched = tmpMatched
                        break if matched is 1

            return ret
