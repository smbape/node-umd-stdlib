deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
]

factory = (require, _, Backbone)->

    class GenericView extends Backbone.View
        validate: false
        constructor: (options)->
            @id = @id or _.uniqueId 'view_'
            super
        initialize: (options)->
            super

            if _.isPlainObject options
                if options.hasOwnProperty 'validate'
                    @validate = !!options.validate
                
                if options.hasOwnProperty 'title'
                    @title = options.title

                if options.controller
                    @controller = options.controller

                for opt in ['template', 'initUI', 'destroyUI', 'onRender']
                    if 'function' is typeof options[opt]
                        @[opt] = options[opt]

            return
        initUI: ->
        destroyUI: ->
        onRender: ->
            xhtml = ''
            if typeof @template is 'function'
                if @model instanceof Backbone.Model
                    data = @model.toJSON()
                else if @model instanceof Backbone.Collection and 'function' is typeof @model.toJSONAttribute
                    data = @model.toJSONAttribute()
                xhtml = @template data

            @.$el.empty().html xhtml
            return @
        render: (options = {})->
            @trigger 'before:render', @
            @enableValidation()
            if typeof @onRender isnt 'function'
                @trigger 'render', @
            else
                @destroyUI()
                if @onRender(options) isnt false
                    @initUI()
                    @trigger 'render', @
            return @
        close: ->
            @trigger 'before:close'
            if typeof @.$el isnt 'undefined'
                @destroyUI()
                @.$el.remove()
            @disableValidation()
            @trigger 'close'
            return
        destroy: ->
            @trigger 'destroy', @
            @close()
            if typeof @.$el isnt 'undefined'
                @.$el.destroy()
                @.$el = null
            @el = null 

            for own prop of @
                @[prop] = null

            return
        enableValidation: ->
            if @validate and typeof @model isnt 'undefined'
                Backbone.Validation.bind @
            return @
        disableValidation: ->
            if (typeof @model isnt 'undefined') and @model.associatedViews instanceof Array
                Backbone.Validation.unbind @
            return @
