deps = [
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
]
factory = (require, Backbone)->

    getOnMethod = (method)->
        'on' + method.charAt(0).toUpperCase() + method.slice 1

    delegateMethods = ['change']

    proxyMethod = (self, method)->
        self[method] = ->
            @model[method].apply @model, arguments
        return

    class GenericSwitchModel extends Backbone.Model

        getModel: ->
            @model

        switch: (model)->
            if model and not (model instanceof Backbone.Model)
                return

            if model is @model
                return

            prev = @model
            @removeModel()
            @model = model
            if not model
                @trigger 'change'
                @trigger 'switch', model, prev
                return
            @attributes = model.attributes

            for method of model
                if 'function' is typeof model[method] and method isnt 'model' and not GenericSwitchModel::[method]
                    proxyMethod @, method

            for evt in delegateMethods
                method = getOnMethod evt
                model.on evt, @[method], @

            @trigger 'change'
            @trigger 'switch', model, prev
            return

        removeModel: ->
            if @model
                for evt in delegateMethods
                    method = getOnMethod evt
                    @model.off evt, @[method], @

                @attributes = {}
                @model = null

            return

        # toJSON: ->
        #     if @model
        #         @model.toJSON()
        #     else
        #         super

    (->
        for method in Backbone.Model::
            ((method)->
                # Method cannot be called on this class
                GenericSwitchModel::[method] = ->
                    throw new Error "Method '#{method}' cannot be called on GenericSwitchModel"
                return
            ) method

        for evt in delegateMethods
            ((evt)->
                method = getOnMethod evt
                GenericSwitchModel::[method] = ->
                    args = [evt].concat Array::slice.call arguments
                    @trigger.apply @, args
                    return
                return
            ) evt

        return
    )()

    GenericSwitchModel