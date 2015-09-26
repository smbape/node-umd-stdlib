deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    'umd-stdlib/core/GenericUtil'
]

factory = (require, _, Backbone, GenericUtil)->

    _lookup = (attr, model)->
        attr = attr.split '.'
        value = model
        for prop in attr
            if value instanceof Backbone.Model
                value = value.get prop
            else if _.isObject value
                value = value[prop]
            else
                value = undefined
                break
        value

    class GenericCollection extends Backbone.Collection
        constructor: (models, options = {})->
            super

            @_modelAttributes = new Backbone.Model options.attributes

            self = @

            @_modelAttributes.on 'change', (model, options)->
                for attr of model.changed
                    self.trigger 'change:' + attr, self, model.attributes[attr], options
                self.trigger 'change', self, options
                return

            if 'function' is typeof options.selector
                @selector = options.selector

            @_options = _.extend {strict: true}, options

            @_keymap = {}
            @_keys = {}

            indexes = options.indexes or @indexes
            if _.isObject indexes
                for name, attrs of indexes
                    @addIndex name, attrs

            if @_options.strict
                @on 'change', (model, options)->
                    if model isnt @
                        # maintain filter
                        if @selector and not @selector model
                            @remove model
                            return

                        # maintain order
                        if @comparator
                            at = GenericUtil.comparators.binaryIndex model, @models, @comparator
                            index = @indexOf model
                            if at isnt index
                                @remove model
                                @add model
                    return

        unsetAttribute: (name)->
            @_modelAttributes.unset name
            @
        getAttribute: (name)->
            @_modelAttributes.get name
        setAttribute: (name, value)->
            switch arguments.length
                when 0
                    @_modelAttributes.set.call @_modelAttributes
                when 1
                    @_modelAttributes.set.call @_modelAttributes, arguments[0]
                else
                    @_modelAttributes.set.call @_modelAttributes, arguments[0], arguments[1]

            @
        toJSONAttribute: ->
            @_modelAttributes.toJSON()

        addIndex: (name, attrs)->
            if 'string' is typeof attrs
                attrs = [attrs]

            if Array.isArray attrs
                @_keymap[name] = _.clone attrs
                @_keys[name] = {}
                for model in @models
                    @_indexModel model, name

                return true

            return false

        get: (obj)->
            @byIndex obj

        byIndex: (model, indexName)->
            if null is model or 'object' isnt typeof model
                return GenericCollection.__super__.get.call @, model

            if model instanceof Backbone.Model
                found = GenericCollection.__super__.get.call @, model
                return found if found
                model = model.toJSON()

            id = model[@model::idAttribute]
            found = GenericCollection.__super__.get.call @, id
            return found if found

            if not indexName
                for indexName of @_keymap
                    found = @byIndex model, indexName
                    break if found
                return found

            return if not @_keymap.hasOwnProperty indexName

            ref = @_keymap[indexName]
            key = @_keys[indexName]
            for attr, index in ref
                value = _lookup attr, model
                key = key[value]
                if 'undefined' is typeof key
                    break

            key

        _addReference: (model, options)->
            super
            @_indexModel model
            return

        _indexModel: (model, name)->
            if model instanceof Backbone.Model
                if not name
                    for name of @_keymap
                        @_indexModel model, name
                    return

                attrs = @_keymap[name]
                chain = []
                for attr in attrs
                    value = _lookup attr, model
                    if 'undefined' is typeof value
                        return
                    chain.push value

                key = @_keys[name]

                for value, index in chain
                    if index is chain.length - 1
                        break
                    if key.hasOwnProperty value
                        key = key[value]
                    else
                        key = key[value] = {}

                key[value] = model

            return

        _removeReference: (model, options)->
            super
            @_removeIndex model
            return

        _removeIndex: (model, name)->
            if model instanceof Backbone.Model
                if not name
                    for name of @_keymap
                        @_removeIndex model, name
                    return

                # @_keys[name][prop1][prop2] = model
                attrs = @_keymap[name]
                chain = []
                for attr in attrs
                    # value = model.get attr
                    value = _lookup attr, model
                    if 'undefined' is typeof value
                        return
                    chain.push value

                key = @_keys[name]

                for value, index in chain
                    if not key or index is chain.length - 1
                        break
                    key = key[value]

                delete key[value] if key

            return

        _getClone: (model)->
            _model = @get model
            if _model
                _model = new _model.constructor _model.attributes
                if model instanceof Backbone.Model
                    _model.set model.attributes
                else
                    _model.set model
            _model

        add: (models, options = {})->
            if options.merge
                if Array.isArray models
                    for model, index in models
                        _model = @_getClone model
                        models[index] = _model if _model
                else
                    _model = @_getClone models
                    models = _model if _model

            # maintain filter
            if @selector
                models = _.filter models, @selector

            super models, options

        getSubSet: (options)->
            options = _.extend {}, @_options, options
            subSet = new @constructor @models, options

            subSet.parent = @

            @on 'change', (model, options)->
                if model is subSet.parent
                    attributes = model.changed
                    subSet.set attributes, options
                return

            @on 'add', (model)->
                subSet.add model
                return

            @on 'remove', (model)->
                subSet.remove model
                return

            @on 'reset', (models, options)->
                subSet.reset models, _.extend {proxy: true}, options
                return

            reset = subSet.reset
            subSet.reset = (models, options = {})->
                if options.proxy
                    reset.apply @, arguments
                return

            subSet
