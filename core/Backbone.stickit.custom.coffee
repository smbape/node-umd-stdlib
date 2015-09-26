deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
]

factory = (require, _, Backbone)->

    testNode = document.createElement 'input'
    isInputSupported = 'oninput' of testNode and (('documentMode' not of document) or document.documentMode > 9)
    testNode = null
    if isInputSupported
        textchange = 'input'
    else
        textchange = 'textchange'

    # Stickit Namespace
    # --------------------------
    Stickit = {}
    Stickit._handlers = []
    Stickit.addHandler = (handlers) ->

        # Fill-in default values.
        handlers = _.map _.flatten([handlers]), (handler)->
            _.defaults {}, handler,
                updateModel: true
                updateView: true
                updateMethod: 'text'

        @_handlers = @_handlers.concat handlers
        return


    # Backbone.View Mixins
    # --------------------
    Stickit.ViewMixin =

        # Unbind the model and event bindings from `this._modelBindings` and
        # `this.$el`. If the optional `model` parameter is defined, then only
        # delete bindings for the given `model` and its corresponding view events.
        unstickit: (model, bindingSelector) ->
            # Collection of model event bindings.
            #   [{model,event,fn,config}, ...]
            @_modelBindings or (@_modelBindings = [])

            # Collection of view event args
            @_viewBindings or (@_viewBindings = [])

            # Support passing a bindings hash in place of bindingSelector.
            if _.isObject bindingSelector
                for own selector of bindingSelector
                    @unstickit model, selector
                return

            models = []
            destroyFns = []

            return if @_modelBindings.length is 0 and @_viewBindings.length is 0

            for i in [(@_modelBindings.length - 1)..0] by -1
                binding = @_modelBindings[i]
                continue if model and binding.model isnt model
                continue if bindingSelector and binding.config.selector isnt bindingSelector

                destroyFns.unshift binding.config._destroy
                binding.model.off binding.event, binding.fn
                models.unshift binding.model
                @_modelBindings.splice i, 1

            for i in [(@_viewBindings.length - 1)..0] by -1
                binding = @_viewBindings[i]
                continue if model and model isnt binding.model
                continue if bindingSelector and bindingSelector isnt binding.selector
                detachViewEvent binding
                @_viewBindings.splice i, 1

            # Trigger an event for each model that was unbound.
            _.invoke _.uniq(models), 'trigger', 'stickit:unstuck', @cid

            # Call `_destroy` on a unique list of the binding callbacks.
            _.each _.uniq(destroyFns), (fn)->
                fn.call this
                return
            , this

            @$el.off '.stickit' + ((if model then '.' + model.cid else '')), bindingSelector
            return

        # Initilize Stickit bindings for the view. Subsequent binding additions
        # can either call `stickit` with the new bindings, or add them directly
        # with `addBinding`. Both arguments to `stickit` are optional.
        stickit: (optionalModel, optionalBindingsConfig) ->
            model = optionalModel or @model
            bindings = optionalBindingsConfig or _.result(this, 'bindings') or {}

            # Add bindings in bulk using `addBinding`.
            @addBinding model, bindings

            # Wrap `view.remove` to unbind stickit model and dom events.
            unless @remove.stickitWrapped
                remove = @remove
                @remove = ->
                    ret = this
                    @unstickit()
                    ret = remove.apply(this, arguments)    if remove
                    ret
                @remove.stickitWrapped = true
            @


        # Add a single Stickit binding or a hash of bindings to the model. If
        # `optionalModel` is ommitted, will default to the view's `model` property.
        addBinding: (optionalModel, selector, binding) ->
            model = optionalModel or @model
            namespace = '.stickit.' + model.cid
            binding = binding or {}

            # Support jQuery-style {key: val} event maps.
            if _.isObject(selector)
                _.each selector, (val, key) ->
                    @addBinding model, key, val
                    return
                , @
                return

            # Special case the ':el' selector to use the view's this.$el.
            $el = if selector is ':el' then @$el else @$ selector

            # Clear any previous matching bindings.
            @unstickit model, selector

            # Fail fast if the selector didn't match an element.
            return unless $el.length

            # Allow shorthand setting of model attributes - `'selector':'observe'`.
            binding = observe: binding if _.isString binding

            # Handle case where `observe` is in the form of a function.
            binding.observe = binding.observe.call(this) if _.isFunction binding.observe

            # Find all matching Stickit handlers that could apply to this element
            # and store in a config object.
            config = getConfiguration $el, binding

            # The attribute we're observing in our config.
            modelAttr = config.observe

            # Store needed properties for later.
            config.selector = selector
            config.view = this

            # Create the model set options with a unique `bindId` so that we
            # can avoid double-binding in the `change:attribute` event handler.
            bindId = config.bindId = _.uniqueId()

            # Add a reference to the view for handlers of stickitChange events
            options = _.extend
                stickitChange: config
            , config.setOptions

            # Add a `_destroy` callback to the configuration, in case `destroy`
            # is a named function and we need a unique function when unsticking.
            config._destroy = ->
                applyViewFn.call this, config.destroy, $el, model, config
                return

            initializeAttributes $el, config, model, modelAttr
            initializeVisible $el, config, model, modelAttr
            initializeClasses $el, config, model, modelAttr
            if modelAttr

                # Setup one-way (input element -> model) bindings.
                _.each config.events, (type) ->
                    eventName = type + namespace
                    listener = (event) ->
                        val = applyViewFn.call(this, config.getVal, $el, event, config, slice.call(arguments, 1))

                        # Don't update the model if false is returned from the `updateModel` configuration.
                        currentVal = evaluateBoolean config.updateModel, val, event, config
                        setAttr model, modelAttr, val, options, config if currentVal
                        return

                    attachViewEvent.call @, model, eventName, selector, listener
                    return
                , this

                # Setup a `change:modelAttr` observer to keep the view element in sync.
                # `modelAttr` may be an array of attributes or a single string value.
                _.each _.flatten([modelAttr]), (attr) ->
                    observeModelEvent model, 'change:' + attr, config, (m, val, options)->
                        changeId = options and options.stickitChange and options.stickitChange.bindId
                        if changeId isnt bindId
                            currentVal = getAttr(model, modelAttr, config)
                            updateViewBindEl $el, config, currentVal, model
                        return

                    return

                currentVal = getAttr(model, modelAttr, config)
                updateViewBindEl $el, config, currentVal, model, true

            # After each binding is setup, call the `initialize` callback.
            applyViewFn.call this, config.initialize, $el, model, config
            return

    _.extend Backbone.View::, Stickit.ViewMixin

    # Helpers
    # -------
    slice = [].slice

    # Evaluates the given `path` (in object/dot-notation) relative to the given
    # `obj`. If the path is null/undefined, then the given `obj` is returned.
    evaluatePath = (obj, path) ->
        parts = (path or '').split '.'
        result = _.reduce(parts, (memo, i) ->
            memo[i]
        , obj)
        if not result? then obj else result


    # If the given `fn` is a string, then view[fn] is called, otherwise it is
    # a function that should be executed.
    applyViewFn = (fn) ->
        fn = if _.isString(fn) then evaluatePath(this, fn) else fn
        fn.apply this, slice.call(arguments, 1) if fn


    # Given a function, string (view function reference), or a boolean
    # value, returns the truthy result. Any other types evaluate as false.
    # The first argument must be `reference` and the last must be `config`, but
    # middle arguments can be variadic.
    evaluateBoolean = (reference, val, config) ->
        if _.isBoolean(reference)
            return reference
        else if _.isFunction(reference) or _.isString(reference)
            view = _.last(arguments).view
            return applyViewFn.apply(view, arguments)
        false


    # Setup a model event binding with the given function, and track the event
    # in the view's _modelBindings.
    observeModelEvent = (model, event, config, fn) ->
        view = config.view
        model.on event, fn, view
        view._modelBindings or (view._modelBindings = [])
        view._modelBindings.push
            model: model
            event: event
            fn: fn
            config: config

        return

    attachViewEvent = (model, event, selector, method)->
        # create a reference to method => reference on $el
        # proxy = _.bind method, @
        proxy = $.proxy method, @
        if selector is ':el'
            args = [event, proxy]
        else
            args = [event, selector, proxy]

        @$el.on.apply @$el, args
        @_viewBindings or (@_viewBindings = [])
        @_viewBindings.push
            model: model
            view: @
            selector: selector
            method: method
            args: args
        return

    detachViewEvent = (binding)->
        binding.view.$el.off.apply binding.view.$el, binding.args
        for prop of binding
            delete binding[prop]
        return


    # Prepares the given `val`ue and sets it into the `model`.
    setAttr = (model, attr, val, options, config) ->
        value = {}
        view = config.view
        val = applyViewFn.call(view, config.onSet, val, config)    if config.onSet
        if config.set
            applyViewFn.call view, config.set, attr, val, options, config
        else
            value[attr] = val

            # If `observe` is defined as an array and `onSet` returned
            # an array, then map attributes to their values.
            if _.isArray(attr) and _.isArray val
                value = _.reduce(attr, (memo, attribute, index) ->
                    memo[attribute] = (if _.has(val, index) then val[index] else null)
                    memo
                , {})
            model.set value, options
        return


    # Returns the given `attr`'s value from the `model`, escaping and
    # formatting if necessary. If `attr` is an array, then an array of
    # respective values will be returned.
    getAttr = (model, attr, config) ->
        view = config.view
        retrieveVal = (field) ->
            model[(if config.escape then 'escape' else 'get')] field

        sanitizeVal = (val) ->
             if not val? then '' else val

        val = (if _.isArray(attr) then _.map(attr, retrieveVal) else retrieveVal(attr))
        val = applyViewFn.call(view, config.onGet, val, config)    if config.onGet
        (if _.isArray(val) then _.map(val, sanitizeVal) else sanitizeVal(val))


    # Find handlers in `Backbone.Stickit._handlers` with selectors that match
    # `$el` and generate a configuration by mixing them in the order that they
    # were found with the given `binding`.
    getConfiguration = Stickit.getConfiguration = ($el, binding) ->
        handlers = [
            updateModel: false
            updateMethod: 'text'
            update: ($el, val, m, opts) ->
                $el[opts.updateMethod] val    if $el[opts.updateMethod]
                return

            getVal: ($el, e, opts) ->
                $el[opts.updateMethod]()
        ]
        handlers = handlers.concat _.filter Stickit._handlers, (handler) ->
            $el.is handler.selector
        handlers.push binding
        config = _.extend.apply _, handlers

        # `updateView` is defaulted to false for configutrations with
        # `visible`; otherwise, `updateView` is defaulted to true.
        config.updateView = not config.visible    unless _.has(config, 'updateView')
        config


    # Setup the attributes configuration - a list that maps an attribute or
    # property `name`, to an `observe`d model attribute, using an optional
    # `onGet` formatter.
    #
    #     attributes: [{
    #       name: 'attributeOrPropertyName',
    #       observe: 'modelAttrName'
    #       onGet: function(modelAttrVal, modelAttrName) { ... }
    #     }, ...]
    #
    initializeAttributes = ($el, config, model, modelAttr) ->
        props = [
            'autofocus'
            'autoplay'
            'async'
            'checked'
            'controls'
            'defer'
            'disabled'
            'hidden'
            'indeterminate'
            'loop'
            'multiple'
            'open'
            'readonly'
            'required'
            'scoped'
            'selected'
        ]
        view = config.view
        _.each config.attributes or [], (attrConfig) ->
            attrConfig = _.clone attrConfig
            attrConfig.view = view
            lastClass = ""
            observed = attrConfig.observe or  attrConfig.observe = modelAttr
            updateAttr = ->
                updateType = (if _.contains(props, attrConfig.name) then "prop" else "attr")
                val = getAttr model, observed, attrConfig

                # If it is a class then we need to remove the last value and add the new.
                if attrConfig.name is 'class'
                    $el.removeClass(lastClass).addClass val
                    lastClass = val
                else
                    $el[updateType] attrConfig.name, val
                return


            _.each _.flatten([observed]), (attr) ->
                observeModelEvent model, 'change:' + attr, config, updateAttr
                return


            # Initialize the matched element's state.
            updateAttr()
            return

        return

    initializeClasses = ($el, config, model, modelAttr) ->
        _.each config.classes or [], (classConfig, name) ->
            classConfig = observe: classConfig    if _.isString(classConfig)
            classConfig.view = config.view
            observed = classConfig.observe
            updateClass = ->
                val = getAttr(model, observed, classConfig)
                $el.toggleClass name, !!val
                return

            _.each _.flatten([observed]), (attr) ->
                observeModelEvent model, "change:" + attr, config, updateClass
                return

            updateClass()
            return

        return


    # If `visible` is configured, then the view element will be shown/hidden
    # based on the truthiness of the modelattr's value or the result of the
    # given callback. If a `visibleFn` is also supplied, then that callback
    # will be executed to manually handle showing/hiding the view element.
    #
    #     observe: 'isRight',
    #     visible: true, // or function(val, options) {}
    #     visibleFn: function($el, isVisible, options) {} // optional handler
    #
    initializeVisible = ($el, config, model, modelAttr) ->
        return    unless config.visible?
        view = config.view
        visibleCb = ->
            visible = config.visible
            visibleFn = config.visibleFn
            val = getAttr model, modelAttr, config
            isVisible = !!val

            # If `visible` is a function then it should return a boolean result to show/hide.
            isVisible = !!applyViewFn.call(view, visible, val, config) if _.isFunction(visible) or _.isString visible

            # Either use the custom `visibleFn`, if provided, or execute the standard show/hide.
            if visibleFn
                applyViewFn.call view, visibleFn, $el, isVisible, config
            else
                $el.toggle isVisible
            return

        _.each _.flatten([modelAttr]), (attr) ->
            observeModelEvent model, 'change:' + attr, config, visibleCb
            return

        visibleCb()
        return


    # Update the value of `$el` using the given configuration and trigger the
    # `afterUpdate` callback. This action may be blocked by `config.updateView`.
    #
    #     update: function($el, val, model, options) {},  // handler for updating
    #     updateView: true, // defaults to true
    #     afterUpdate: function($el, val, options) {} // optional callback
    #
    updateViewBindEl = ($el, config, val, model, isInitializing) ->
        view = config.view
        return unless evaluateBoolean config.updateView, val, config
        applyViewFn.call view, config.update, $el, val, model, config
        applyViewFn.call view, config.afterUpdate, $el, val, config unless isInitializing
        return


    # Default Handlers
    # ----------------
    Stickit.addHandler [
        {
            selector: '[contenteditable]'
            updateMethod: 'html'
            events: [
                'input'
                'change'
            ]
        }
        {
            selector: 'input'
            events: [
                textchange
            ]
            update: ($el, val) ->
                $el.val val
                return

            getVal: ($el) ->
                $el.val()
        }
        {
            selector: 'textarea'
            events: [
                'propertychange'
                'input'
                'change'
            ]
            update: ($el, val) ->
                $el.val val
                return

            getVal: ($el) ->
                $el.val()
        }
        {
            selector: 'input[type="radio"]'
            events: ['change']
            update: ($el, val) ->
                $el.filter('[value="' + val + '"]').prop 'checked', true
                return

            getVal: ($el) ->
                $el.filter(':checked').val()
        }
        {
            selector: "input[type=\"checkbox\"]"
            events: ['change']
            update: ($el, val, model, options) ->
                if $el.length > 1

                    # There are multiple checkboxes so we need to go through them and check
                    # any that have value attributes that match what's in the array of `val`s.
                    val or val = []
                    $el.each (i, el) ->
                        checkbox = Backbone.$ el
                        checked = _.contains val, checkbox.val()
                        checkbox.prop 'checked', checked
                        return

                else
                    checked = (if _.isBoolean(val) then val else val is $el.val())
                    $el.prop 'checked', checked
                return

            getVal: ($el) ->
                if $el.length > 1
                    val = _.reduce($el, (memo, el) ->
                        checkbox = Backbone.$ el
                        memo.push checkbox.val() if checkbox.prop 'checked'
                        memo
                    , [])
                else
                    val = $el.prop 'checked'

                    # If the checkbox has a value attribute defined, then
                    # use that value. Most browsers use 'on' as a default.
                    boxval = $el.val()
                    val = (if val then $el.val() else null) if boxval isnt 'on' and boxval?
                val
        }
        {
            selector: 'select'
            events: ['change']
            update: ($el, val, model, options) ->
                selectConfig = options.selectOptions
                list = selectConfig and selectConfig.collection or `undefined`
                isMultiple = $el.prop 'multiple'

                # If there are no `selectOptions` then we assume that the `<select>`
                # is pre-rendered and that we need to generate the collection.
                unless selectConfig
                    selectConfig = {}
                    getList = ($el) ->

                        # Retrieve the text and value of the option, preferring "stickit-bind-val"
                        # data attribute over value property.
                        $el.map((index, option) ->
                            dataVal = Backbone.$(option).data('stickit-bind-val')
                            value: (if dataVal isnt `undefined` then dataVal else option.value)
                            label: option.text
                        ).get()

                    if $el.find('optgroup').length
                        list = opt_labels: []

                        # Search for options without optgroup
                        if $el.find('> option').length
                            list.opt_labels.push `undefined`
                            _.each $el.find('> option'), (el)->
                                list[`undefined`] = getList(Backbone.$(el))
                                return

                        _.each $el.find('optgroup'), (el)->
                            label = Backbone.$(el).attr 'label'
                            list.opt_labels.push label
                            list[label] = getList(Backbone.$(el).find('option'))
                            return

                    else
                        list = getList($el.find('option'))

                # Fill in default label and path values.
                selectConfig.valuePath = selectConfig.valuePath or 'value'
                selectConfig.labelPath = selectConfig.labelPath or 'label'
                selectConfig.disabledPath = selectConfig.disabledPath or 'disabled'
                addSelectOptions = (optList, $el, fieldVal) ->
                    _.each optList, (obj) ->
                        option = Backbone.$ '<option/>'
                        optionVal = obj
                        fillOption = (text, val, disabled) ->
                            option.text text
                            optionVal = val

                            # Save the option value as data so that we can reference it later.
                            option.data 'stickit-bind-val', optionVal
                            option.val optionVal if not _.isArray(optionVal) and not _.isObject optionVal
                            option.prop 'disabled', 'disabled' if disabled is true
                            return

                        if obj is '__default__'
                            text = fieldVal.label
                            val = fieldVal.value
                            disabled = fieldVal.disabled
                        else
                            text = evaluatePath(obj, selectConfig.labelPath)
                            val = evaluatePath(obj, selectConfig.valuePath)
                            disabled = evaluatePath(obj, selectConfig.disabledPath)
                        fillOption text, val, disabled

                        # Determine if this option is selected.
                        isSelected = ->
                            if not isMultiple and optionVal? and fieldVal? and optionVal is fieldVal
                                return true
                            else return true if _.isObject(fieldVal) and _.isEqual(optionVal, fieldVal)
                            false

                        if isSelected()
                            option.prop 'selected', true
                        else if isMultiple and _.isArray fieldVal
                            _.each fieldVal, (val) ->
                                val = evaluatePath(val, selectConfig.valuePath) if _.isObject val
                                option.prop 'selected', true if val is optionVal or (_.isObject(val) and _.isEqual(optionVal, val))
                                return

                        $el.append option
                        return

                    return

                $el.find('*').remove()

                # The `list` configuration is a function that returns the options list or a string
                # which represents the path to the list relative to `window` or the view/`this`.
                if _.isString(list)
                    context = window
                    context = this if list.indexOf('this.') is 0
                    list = list.replace(/^[a-z]*\.(.+)$/, '$1')
                    optList = evaluatePath context, list
                else if _.isFunction list
                    optList = applyViewFn.call(this, list, $el, options)
                else
                    optList = list

                # Support Backbone.Collection and deserialize.
                if optList instanceof Backbone.Collection
                    collection = optList
                    refreshSelectOptions = ->
                        currentVal = getAttr(model, options.observe, options)
                        applyViewFn.call this, options.update, $el, currentVal, model, options
                        return


                    # We need to call this function after unstickit and after an update so we don't end up
                    # with multiple listeners doing the same thing
                    removeCollectionListeners = ->
                        collection.off "add remove reset sort", refreshSelectOptions
                        return

                    removeAllListeners = ->
                        removeCollectionListeners()
                        collection.off "stickit:selectRefresh"
                        model.off "stickit:selectRefresh"
                        return


                    # Remove previously set event listeners by triggering a custom event
                    collection.trigger "stickit:selectRefresh"
                    collection.once "stickit:selectRefresh", removeCollectionListeners, this

                    # Listen to the collection and trigger an update of the select options
                    collection.on "add remove reset sort", refreshSelectOptions, this

                    # Remove the previous model event listener
                    model.trigger "stickit:selectRefresh"
                    model.once "stickit:selectRefresh", ->
                        model.off "stickit:unstuck", removeAllListeners
                        return


                    # Remove collection event listeners once this binding is unstuck
                    model.once "stickit:unstuck", removeAllListeners, this
                    optList = optList.toJSON()
                if selectConfig.defaultOption
                    option = (if _.isFunction(selectConfig.defaultOption) then selectConfig.defaultOption.call(this, $el, options) else selectConfig.defaultOption)
                    addSelectOptions ["__default__"], $el, option
                if _.isArray(optList)
                    addSelectOptions optList, $el, val
                else if optList.opt_labels

                    # To define a select with optgroups, format selectOptions.collection as an object
                    # with an 'opt_labels' property, as in the following:
                    #
                    #     {
                    #       'opt_labels': ['Looney Tunes', 'Three Stooges'],
                    #       'Looney Tunes': [{id: 1, name: 'Bugs Bunny'}, {id: 2, name: 'Donald Duck'}],
                    #       'Three Stooges': [{id: 3, name : 'moe'}, {id: 4, name : 'larry'}, {id: 5, name : 'curly'}]
                    #     }
                    #
                    _.each optList.opt_labels, (label) ->
                        $group = Backbone.$('<optgroup/>').attr 'label', label
                        addSelectOptions optList[label], $group, val
                        $el.append $group
                        return


                # With no 'opt_labels' parameter, the object is assumed to be a simple value-label map.
                # Pass a selectOptions.comparator to override the default order of alphabetical by label.
                else
                    opts = []
                    for i of optList
                        opt = {}
                        opt[selectConfig.valuePath] = i
                        opt[selectConfig.labelPath] = optList[i]
                        opts.push opt
                    opts = _.sortBy(opts, selectConfig.comparator or selectConfig.labelPath)
                    addSelectOptions opts, $el, val
                return

            getVal: ($el) ->
                selected = $el.find('option:selected')
                if $el.prop('multiple')
                    _.map selected, (el) ->
                        Backbone.$(el).data 'stickit-bind-val'

                else
                    selected.data 'stickit-bind-val'
        }
    ]

    # Export onto Backbone object
    Backbone.Stickit = Stickit
    Backbone.Stickit
