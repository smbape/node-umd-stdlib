deps = [
    {node: 'jquery', common: '!jQuery', amd: 'jquery'}
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    'umd-stdlib/core/QueryString'
]

factory = (require, $, _, Backbone, QueryString) ->
    'use strict'

    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/Array/isArray#Prothèse_d'émulation_(polyfill)
    unless Array.isArray
        Array.isArray = (arg) ->
            Object::toString.call(arg) is '[object Array]'

    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/Object/keys#Prothèse_d'émulation_(polyfill)
    unless Object.keys
        do ->
            'use strict'
            hasOwnProperty = Object::hasOwnProperty
            hasDontEnumBug = !{ toString: null }.propertyIsEnumerable('toString')
            dontEnums = [
                'toString'
                'toLocaleString'
                'valueOf'
                'hasOwnProperty'
                'isPrototypeOf'
                'propertyIsEnumerable'
                'constructor'
            ]
            dontEnumsLength = dontEnums.length
            Object.keys = (obj) ->
                if typeof obj != 'object' and (typeof obj != 'function' or obj == null)
                    throw new TypeError('Object.keys called on non-object')
                result = []

                for prop of obj
                    if hasOwnProperty.call(obj, prop)
                        result.push prop
                if hasDontEnumBug
                    for i in [0...dontEnumsLength] by 1
                        if hasOwnProperty.call(obj, dontEnums[i])
                            result.push dontEnums[i]
                result
            return

    # https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Objets_globaux/String/trim#Polyfill
    unless String::trim
        do ->
            'use strict'
            rtrim = /^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g
            String::trim = ->
                @replace rtrim, ''
            return

    # for dom leak test
    # to remove in production
    $.expr.cacheLength = 1

    $.fn.serializeObject = ->
        QueryString.parse @serialize()

    discard = (element) ->
        discard element.firstChild while element.firstChild
        if element.nodeType is 1 and not /^(?:IMG|SCRIPT|INPUT)$/.test element.nodeName
            try
                element.innerHTML = ''
        element.parentNode.removeChild element if element.parentNode
        return

    $.fn.destroy = (selector) ->
        ret = @remove()
        i = 0
        while (elem = this[i])?
            # Remove any remaining nodes
            discard elem
            i++
        ret

    $.fn.insertAt = (elements, index) ->
        children = @children()
        if index >= children.size()
            @append elements
            return this
        before = children.eq index

        if before.length > 0
            $(elements).insertBefore before
        else
            @append elements
        this

    do ->
        # http://erraticdev.blogspot.de/2011/02/jquery-scroll-into-view-plugin-with.html

        converter = 
            vertical:
                x: false
                y: true
            horizontal:
                x: true
                y: false
            both:
                x: true
                y: true

        converter.x = converter.horizontal
        converter.y = converter.vertical

        scrollValue = 
            auto: true
            scroll: true
            visible: false
            hidden: false

        rootrx = /^(?:html)$/i;

        $.expr[':'].scrollable = (element, index, meta, stack) ->
            direction = converter[typeof meta[3] is 'string' and meta[3].toLowerCase()] or converter.both
            styles = if document.defaultView and document.defaultView.getComputedStyle then document.defaultView.getComputedStyle(element, null) else element.currentStyle
            overflow = 
                x: scrollValue[styles.overflowX.toLowerCase()] or false
                y: scrollValue[styles.overflowY.toLowerCase()] or false
                isRoot: rootrx.test(element.nodeName)
            
            # check if completely unscrollable (exclude HTML element because it's special)
            if !overflow.x and !overflow.y and !overflow.isRoot
                return false

            size =
                height:
                    scroll: element.scrollHeight
                    client: element.clientHeight
                width:
                    scroll: element.scrollWidth
                    client: element.clientWidth
                scrollableX: ->
                    (overflow.x or overflow.isRoot) and @width.scroll > @width.client
                scrollableY: ->
                    (overflow.y or overflow.isRoot) and @height.scroll > @height.client

            direction.y and size.scrollableY() or direction.x and size.scrollableX()

        return

    return