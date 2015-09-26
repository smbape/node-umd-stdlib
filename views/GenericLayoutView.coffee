deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    'umd-stdlib/views/GenericView'
]

factory = (require, _, GenericView)->
    class GenericLayoutView extends GenericView
        constructor: (options)->
            super
            @children = []
            @once 'destroy', =>
                for child in @children
                    child.view.destroy()
                return

            @_regions = {}
            if _.isPlainObject(options) and _.isPlainObject(options.regions)
                @setRegions options.regions
            else
                @setRegions @regions
            @regions = {}

        append: (view, options)->
            if 'string' is typeof options
                options = selector: options
            else if _.isPlainObject
                options = _.pick options, ['selector', 'required']
                if _.isEmpty options
                    return @
            else
                return @

            options.view = view
            @children.push options
            return @
        setRegions: (regions)->
            return @ if not _.isPlainObject regions
            for name, selector of regions
                @_regions[name] = selector if 'string' is typeof selector
            return @
        unsetRegions: ->
            for name of @regions
                delete @regions[name]
            return @
        initRegions: ->
            if @.$el
                @unsetRegions()
                for name, selector of @_regions
                    region = @.$el.find selector
                    if region.length is 1
                        @regions[name] or (@regions[name] = {})
                        @regions[name].$el = region
                        @regions[name].el = region[0]
            return
        onRender: (options)->
            # fn.empty and fn.html clear every present in the element
            # to avoid destroying events listended on childs,
            # remove them before clearing dom
            for child in @children
                el = child.view.el
                el.parentNode.removeChild el if el.parentNode

            super

            @initRegions()

            for child in @children
                # append child if not already append
                if child.view.$el.closest('#' + @id).length is 0
                    if typeof child.selector is 'string' and child.selector.length > 0
                        parent = @.$el.find(child.selector)[0]
                    else
                        parent = undefined
                    if typeof parent is 'undefined'
                        if child.required
                            continue
                        @el.appendChild child.view.el
                    else
                        parent.appendChild child.view.el

                child.view.render options

            return @
