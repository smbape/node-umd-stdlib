deps = [
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    'umd-stdlib/views/GenericView'
    'umd-stdlib/core/GenericUtil'
]

factory = (require, Backbone, GenericView, GenericUtil)->
    class GenericCollectionView extends GenericView

        constructor: (options = {})->
            @_viewAttributes = new Backbone.Model options.attributes

            super

            if  not (@model instanceof Backbone.Collection)
                throw new Error 'model must be given and be an instanceof Backbone.Collection'

            if 'function' is typeof options.itemTemplate
                @itemTemplate = options.itemTemplate

            if 'undefined' isnt typeof options.container
                @container = options.container

            @setComparator options.comparator

        setAttribute: ->
            switch arguments.length
                when 1
                    @_viewAttributes.set arguments[0]
                when 2
                    @_viewAttributes.set arguments[0], arguments[1]
                else
                    @_viewAttributes.set arguments[0], arguments[1], arguments[2]
        getAttribute: (attr)->
            @_viewAttributes.get attr

        initEvents: ->
            @model.on 'add', @onAdd, @
            @model.on 'remove', @onRemove, @
            @model.on 'reset', @onReset, @
            @model.on 'change', @onChange, @
            @model.on 'switch', @render, @
            @_viewAttributes.on 'change', @onChange, @
            return

        destroyEvents: ->
            @model.off 'add', @onAdd, @
            @model.off 'remove', @onRemove, @
            @model.off 'reset', @onReset, @
            @model.off 'change', @onChange, @
            @model.off 'switch', @render, @
            @_viewAttributes.off 'change', @onChange, @
            return

        initUI: ->
            @.$el.on 'click', '[data-set]', @updateViewAttributes
            return
        destroyUI: ->
            @.$el.off 'click', '[data-set]', @updateViewAttributes
            return
        updateViewAttributes: (evt)=>
            target = $ evt.currentTarget

            evt.preventDefault()
            evt.stopPropagation()
            evt.stopImmediatePropagation()

            value = target.attr('data-value')
            if value
                try
                    value = JSON.parse value
            else
                value = target.val()
            attr = target.attr 'data-set'
            @_viewAttributes.set attr, value
            return

        destroy: ->
            @destroyEvents()
            super
            return

        getContainer: ->
            if @container
                return @$el.find @container
            return @$el

        getModelXhtml: (model)->
            template = @itemTemplate
            if 'function' isnt typeof template
                return ''

            context =
                model: model.toJSON()
                view: @_viewAttributes.toJSON()

            collection = model.collection
            if collection
                if 'function' is typeof collection.toJSONAttribute
                    context.collection = collection.toJSONAttribute()
                else
                    context.collection = _.clone collection.attributes

            template context

        setComparator: (comparator)->
            @destroyEvents()

            if 'function' is typeof comparator
                @_model = @model if not @_model
                @model = @_model.getSubSet comparator: comparator
                res = true
            else if comparator is null and @_model
                @model = @_model
                delete @_model
                res = true
            else
                res = false

            @initEvents()

            res

        sort: (comparator, reverse)->
            if 'string' is typeof comparator
                comparator = GenericUtil.comparators.PropertyComarator comparator

            if arguments.length is 1 and 'boolean' is typeof comparator
                reverse = true
                comparator = @model.comparator

            if reverse
                comparator = GenericUtil.comparators.reverse comparator

            @setComparator(comparator) and @render()

        onRender: ->
            xhtml = ''
            if typeof @template is 'function'
                data = {}

                # Collection model attributes
                if 'function' is typeof @model.toJSONAttribute
                    data.model = @model.toJSONAttribute()
                else
                    data.model = _.clone @model.attributes

                data.view = @_viewAttributes.toJSON()

                xhtml = @template data

            @.$el.empty().html xhtml

            models = @model.models

            # Append current elements
            # String contanation is faster with array
            # TODO : Add reference
            xhtml = []
            for model in models
                xhtml[xhtml.length] = @getModelXhtml model
            container = @getContainer()
            container.empty().html xhtml.join('')

            return @

        onAdd: (model)->
            index = @model.indexOf model
            container = @getContainer()
            xhtml = @getModelXhtml model
            element = $ xhtml
            container.insertAt element, index
            return element

        onRemove: (model, collection, options)->
            index = options.index
            container = @getContainer()
            children = container.children()
            element = children.eq index
            element.destroy()
            return

        onReset: (model)->
            container = @getContainer()
            container.empty()
            @trigger 'reset'
            return

        onChange: (model)->
            if model is @model
                @render()
            else if model is @_viewAttributes
                if model.changed.sort
                    comparator = model.changed.sort.attribute
                    reverse = model.changed.sort.value is 'desc'
                    @sort comparator, reverse
                else
                    @render()
            else
                index = @model.indexOf model
                container = @getContainer()
                xhtml = @getModelXhtml model
                children = container.children()
                element = children.eq index
                element.replaceWith xhtml
                element.destroy()

            @trigger 'change'
            return
