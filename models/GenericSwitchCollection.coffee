deps = [
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
]
factory = (require, Backbone)->

    getOnMethod = (method)->
        'on' + method.charAt(0).toUpperCase() + method.slice 1

    delegateEvents = ['add', 'remove', 'reset', 'change']

    proxyMethod = (self, method)->
        self[method] = ->
            @collection[method].apply @collection, arguments
        return

    class GenericSwitchCollection extends Backbone.Collection

        getCollection: ->
            @collection

        switch: (collection)->
            if collection and not (collection instanceof Backbone.Collection)
                return

            if collection is @collection
                return

            prev = @collection
            @removeCollection()
            @collection = collection
            if not collection
                @trigger 'switch', collection, prev
                return

            for method of collection
                if 'function' is typeof collection[method] and method isnt 'collection' and not GenericSwitchCollection::[method]
                    proxyMethod @, method

            for evt in delegateEvents
                method = getOnMethod evt
                collection.on evt, @[method], @

            @models = @collection.models

            for model in @models
                @trigger 'add', model

            @trigger 'switch', collection, prev
            return

        removeCollection: ->
            if @collection
                for evt in delegateEvents
                    method = getOnMethod evt
                    @collection.off evt, @[method], @

                for method of @collection
                    if 'function' is typeof @collection[method] and method isnt 'collection' and not GenericSwitchCollection::[method]
                        delete @[method]

                @collection = null
                @models = []

            return

    (->
        # for method in Backbone.Collection::
        #     ((method)->
        #         # Method cannot be called on this class
        #         GenericSwitchCollection::[method] = ->
        #             throw new Error "Method '#{method}' cannot be called on GenericSwitchCollection"
        #         return
        #     ) method

        for evt in delegateEvents
            ((evt)->
                method = getOnMethod evt
                GenericSwitchCollection::[method] = ->
                    args = [evt].concat Array::slice.call arguments
                    @trigger.apply @, args
                    return
                return
            ) evt

        return
    )()

    GenericSwitchCollection