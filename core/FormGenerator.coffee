deps = [
    'umd-stdlib/core/common'
    {common: 'umd-stdlib/core/ClientUtil', amd: 'umd-stdlib/core/ClientUtil'}
    'umd-stdlib/core/i18next'
    {amd: 'jquery-ui'}
]

factory = (require, com, ClientUtil, i18n)->
    application = com.application
    _ = com._
    $ = com.$
    Backbone = com.Backbone
    Util = com.gen.Util
    FormView = com.gen.views.FormView

    attributesToHtml = (attributes)->
        attrs = []
        str = []

        for attr, value of attributes
            type = typeof value
            if value is null or value is true
                str[str.length] = ' ' if str.length is 0
                str[str.length] = attr
            else if type is 'string' or type is 'number'
                str[str.length] = ' ' if str isnt ''
                str[str.length] = "#{attr}=\"#{value}\""

        return ' ' + str.join ''

    _cloneProperties = (dst, src, except = ['id', 'attributes', 'decorators', 'elements', 'el', '$el'])->
        return dst if not dst or not src
        Array.isArray(except) or (except = [])
        for own prop of src
            if except.indexOf(prop) is -1
                if 'function' is typeof src[prop]
                    dst[prop] = src[prop]
                else if _.isObject(src[prop]) and 'function' is typeof src[prop].clone
                    dst[prop] = src[prop].clone()
                else
                    dst[prop] = _.clone src[prop]
        dst

    FormHelper =
        Element: class Element
            type: 'element'
            constructor: (name, attributes, options)->
                if arguments.length < 3 and _.isPlainObject name
                    options = attributes
                    attributes = name
                    name = ''

                options = options or {}
                @attributes = {}
                @options = {}

                @setAttribute 'id', _.uniqueId 'Element_'
                @setName name
                @setOptions options
                @setAttributes attributes
                @decorators = self: []
                @addDecorators options.decorators
                @initialize.apply @, arguments
                if typeof options.initialize is 'function'
                    options.initialize.apply @, arguments
            destroy: (options)->
                if 'undefined' is typeof options or options isnt false
                    for own prop of @
                        @[prop] = null
                return
            clone: ->
                clone = new @constructor()
                _cloneProperties clone, @
                _cloneProperties clone.attributes, @attributes
                _cloneProperties clone.decorators, @decorators
                _cloneProperties clone.elements, @elements
                clone
            initialize: ->
            addDecorators: (decorators, options = {})->
                return unless Array.isArray decorators
                for decorator in decorators
                    @addDecorator decorator, options
                return
            addDecorator: (decorator, options = {})->
                if _.isPlainObject decorator
                    fn = decorator.fn
                    target = decorator.target or options.target
                else if typeof decorator is 'function'
                    fn = decorator
                    target = options.target
                return unless typeof fn is 'function'
                target = target or 'self'
                @decorators[target] = @decorators[target] or []
                @decorators[target].push fn
                return
            removeDecorators: (target = 'self')->
                return @ unless Array.isArray @decorators[target]
                arr = @decorators[target]
                arr.splice 0, arr.length
                return @
            removeDecorator: (decorator, target = 'self', limit = 1)->
                arr = @decorators[target]
                return @ unless Array.isArray arr
                return @ if limit is 0 or arr.length is 0
                if limit is 1 and (idx = array.indexOf decorator) isnt -1
                    arr.splice idx, 1
                else
                    for idx in [(arr.length -1)..0] by -1
                        break if limit is 0
                        if arr[idx] is decorator
                            arr.splice idx, 1
                            limit--
                return @
            getName: ->
                return @name
            setName: (@name)->
                return @
            getOption: (attr)->
                return @options[attr]
            getOptions: ->
                return @options
            removeOption: (opt)->
                delete @options[opt]
            setOption: (opt, value)->
                return @ if typeof opt is 'undefined'
                @options[opt] = value
            setOptions: (options = {})->
                for opt, value of options
                    @setOption opt, value
                return @
            removeAttribute: (opt)->
                delete @attributes[opt]
            getAttribute: (attr)->
                return @attributes[attr]
            getAttributes: ->
                return @attributes
            setAttribute: (attr, value)->
                return @ if typeof attr is 'undefined'
                @attributes[attr] = value
                return @
            setAttributes: (attributes = {})->
                for attr, value of attributes
                    @setAttribute attr, value
                return @
            addClass: (name)->
                className = @getAttribute('class')
                if className
                    className = className.split(/\s+/)
                else
                    className = []
                if -1 is className.indexOf(name)
                    className[className.length] = name
                @setAttribute 'class', className.join(' ')
            getValue: ->
                return @attributes.value
            setValue: (value)->
                return @setAttribute 'value', value
            getLabel: ->
                return @options.label or @options.label = ''
            getInfo: ->
                res = _.clone @attributes
                name = @getName()
                if typeof name is 'string' and name.length > 0
                    res.name = name
                    if belongsTo = @getOption 'belongsTo'
                        res.name = "#{belongsTo}[#{res.name}]"
                    if @getOption 'isArray'
                        res.name += '[]'
                if typeof res.disabled isnt 'undefined'
                    res.disabled = !!res.disabled
                res
            getXhtml: ->
                xhtml = @getValue()
                for decorator in @decorators.self
                    xhtml = decorator.call @, xhtml

                return xhtml
            render: ->
                xhtml = @getXhtml()
                for decorator in @decorators.self
                    xhtml = decorator.call @, xhtml
                return xhtml
            getType: ->
                return @type
            getJQueryEl: ->
                return @$el if @$el and @$el.length is 1
                $el = $ '#' + @getAttribute 'id'
                if $el.length is 1
                    @$el = $el
            getContent: ->
                @getValue()

    class FormHelper.TagElement extends FormHelper.Element
        constructor: (name, attributes, options = {})->
            super
            if typeof options.tagName is 'string'
                @tagName = options.tagName
            if typeof options.isParentNode is 'boolean'
                @isParentNode = options.isParentNode
            else
                @isParentNode = true
        getXhtml:->
            attributes = @getInfo()
            xhtml = '<' + @tagName + attributesToHtml(attributes)
            if @isParentNode
                content = @getContent()
                if typeof content is 'undefined'
                    content = ''
                xhtml += '>' + content + '</' + @tagName + '>'
            else
                xhtml += '/>'

            return xhtml

    class FormHelper.TextArea extends FormHelper.TagElement
        tagName: 'textarea'

    class FormHelper.Form extends FormHelper.Element
        type: 'form'
        constructor: (name, attributes, options)->
            super
            @decorators.child = @decorators.child or []
            @elements = {}

        # Add an element
        # 
        # @params type [String] Element type
        # @params name [String] Element form name
        # @option options [Object] Element options
        # @return [Form] this
        addElement: (type, name, attributes, options)->
            if type instanceof FormHelper.Element
                element = type
                name = name or element.getName()
            else if typeof FormHelper[type] isnt 'function' or not FormHelper[type]::hasOwnProperty 'constructor'
                err = new Error "[#{type}] is unknown"
                err.code = 'UNKNOWN_ELEMENT'
                throw err
            else
                element = new FormHelper[type] name, attributes, options

            if @elements.hasOwnProperty name
                err = new Error "An element [#{name}] already exists"
                err.code = 'DUPLICATE_NAME'
                throw err

            @elements[name] = element
            return @
        removeElement: (name)->
            delete @elements[name]
            return @
        getElement: (name)->
            return @elements[name]
        getElements: ->
            return @elements
        getInnerHTML: ->
            xhtml = ''
            for name, element of @elements
                elHtml = element.render()
                for decorator in @decorators.child
                    elHtml = decorator.call element, elHtml
                xhtml += elHtml

            for decorator in @decorators.self
                xhtml = decorator.call @, xhtml
            return xhtml
        getXhtml: ->
            attributes = @getInfo()
            xhtml = '<form' + attributesToHtml(attributes) + '>' + @getInnerHTML() + '</form>'

            return xhtml

    class FormHelper.StaticText extends FormHelper.Element
        type: 'static-text'
        getXhtml: ->
            attributes = @getInfo()
            if typeof attributes.class is 'undefined' or attributes.class is null
                attributes.class = 'form-control-static'
            else
                if typeof attributes.class isnt 'string'
                    attributes.class = attributes.class.toString()
                if attributes.class.length is 0
                    attributes.class = 'form-control-static'
                else
                    attributes.class += ' form-control-static'

            if not (content = @getValue())
                content = ''
            xhtml = '<p' + attributesToHtml(attributes) + '>' + content + '</p>'

            return xhtml

    class FormHelper.Input extends FormHelper.Element
        type: 'input'
        getXhtml: ->
            attributes = @getInfo()

            type = @getType attributes
            delete attributes.type

            xhtml = '<input type="' + type + '"' + attributesToHtml(attributes) + '/>'

            return xhtml
        getType: (attributes)->
            attributes = attributes or @attributes

            # Ensure type is sane
            type = 'text'
            if typeof attributes.type isnt 'undefined'
                attributes.type = attributes.type.toLowerCase()
                type = attributes.type if /^(?:text|password|hidden)$/.test attributes.type
            return type

    class FormHelper.Button extends FormHelper.Element
        type: 'button'
        getXhtml: ->
            attributes = @getInfo()
            if  typeof @options.content isnt 'undefined'
                content = @options.content
            else
                content = ''

            # Ensure type is sane
            type = @type
            if typeof attributes.type isnt 'undefined'
                attributes.type = attributes.type.toLowerCase()
                type = attributes.type if /^(?:submit|reset|button)$/.test attributes.type
                delete attributes.type

            xhtml = '<button type="' + type + '"' + attributesToHtml(attributes) + '>' + content + '</button>'
            return xhtml

    class FormHelper.Checkbox extends FormHelper.Input
        type: 'checkbox'
        getXhtml: ->
            @attributes.type = @type
            super
        getInfo: ->
            info = super
            if typeof info.value is 'boolean'
                info.checked = info.value
                delete info.value
            info.checked = if info.checked then 'checked' else false
            delete info.checked unless info.checked

            return info
        getType: (attributes)->
            attributes = attributes or @attributes

            # Ensure type is sane
            type = 'checkbox'
            if typeof attributes.type isnt 'undefined'
                attributes.type = attributes.type.toLowerCase()
                type = attributes.type if /^(?:checkbox|radio)$/.test attributes.type
            return type

    class FormHelper.Radio extends FormHelper.Checkbox
        type: 'radio'

    class FormHelper.Collection extends FormHelper.Element
        constructor: (name, attributes = {}, options = {})->
            super
            @decorators.items = @decorators.items or []
            @items = []
            @setItems attributes.items
        hasValue: (value)->
            selfValue = @getValue()
            return false if typeof selfValue is 'undefined'
            return value in selfValue if Array.isArray selfValue
            return selfValue.hasOwnProperty(value) if _.isPlainObject selfValue
            return value is selfValue
        setItems: (items)->
            if Array.isArray items
                @items = items
            return @
        getItemType: ->
            @getAttribute('type') or 'checkbox'
        getItems: ->
            @items
        getXhtml: ->
            xhtml = ''
            items = @getItems()
            type = Util.StringUtil.firstUpper @getItemType()
            info = @getInfo()
            for item in items
                if _.isPlainObject item
                    if typeof FormHelper[type] isnt 'function' or not FormHelper[type].prototype.hasOwnProperty 'constructor'
                        className = 'TagElement'
                        options = _.extend {}, item.options, tagName: type
                    else
                        className = type
                        options = item.options
                    item = new FormHelper[className] @name, _.extend({}, item.attributes, disabled: info.disabled), options
                else
                    item.setName @name

                if not (isArray = item.getOption 'isArray')
                    item.setOption 'isArray', true
                if @hasValue item.getValue()
                    item.setAttribute 'checked', true
                else
                    item.setAttribute 'checked', false

                elHtml = item.render()
                if not isArray
                    item.setOption 'isArray', false
                for decorator in @decorators.items
                    elHtml = decorator.call item, elHtml

                xhtml += elHtml
            xhtml

    class FormHelper.Option extends FormHelper.TagElement
        tagName: 'option'
        getContent: ->
            label = @getOption 'label'
            if label then i18n.t label else label

    class FormHelper.Select extends FormHelper.Collection
        getXhtml: ->
            xhtml = ''
            items = @getItems()
            for item, index in items
                if _.isPlainObject item
                    attributes = item.attributes
                    options = item.options
                    item = items[index] = new FormHelper.Option '', attributes, options
                # else if item instanceof FormHelper.Element

                if @hasValue item.getValue()
                    item.setAttribute 'selected', 'selected'
                else
                    item.removeAttribute 'selected'

                elHtml = item.render()

                for decorator in @decorators.items
                    elHtml = decorator.call item, elHtml

                xhtml += elHtml
            info = @getInfo()
            delete info.value
            '<select' + attributesToHtml(info) + '>' + xhtml + '</select>'

    class FormHelper.Text extends FormHelper.Input
        type: 'text'
        getXhtml: ->
            @attributes.type = @type
            super

    class FormHelper.Password extends FormHelper.Input
        type: 'password'
        getXhtml: ->
            @attributes.type = @type
            super

    class FormHelper.Hidden extends FormHelper.Input
        type: 'hidden'
        getXhtml: ->
            @attributes.type = @type
            super

    UIProto = (widget, className)->
        type: className
        initialize: (name, attributes, options = {})->
            @initialOptions = options.initial
            if typeof options.initializeUI is 'function'
                initializeUI = options.initializeUI
                @initializeUI = ->
                    @_initializeUI()
                    initializeUI.call @
            else
                @initializeUI = @_initializeUI
            if typeof options.destroyUI is 'function'
                destroyUI = options.destroyUI
                @destroyUI = ->
                    destroyUI.call @
                    @_destroyUI()
            else
                @destroyUI = @_destroyUI
            return
        setInitialOptions: (options, reset)->
            if reset
                @initialOptions = options
            else
                @initialOptions = @initialOptions or {}
                _.extend @initialOptions, options
            return @
        setUIOption: ->
            $el = @getUI()
            if $el
                $el[widget].apply $el, arguments
            return
        _setDisabled: (bool)->
            info = @getInfo()
            if info.disabled
                @setUIOption 'option', 'disabled', info.disabled
            return
        _initializeUI: ->
            # console.log 'initialOptions', JSON.stringify @initialOptions
            # window._$el = @getUI()
            # _$el.select2(@initialOptions)
            # _$el.select2('destroy')
            if $el = @getUI()
                $el[widget] @initialOptions
                @_setDisabled()
            return
        _destroyUI: ->
            if $el = @getUI()
                $el[widget] 'destroy'
            return
        destroy: (options)->
            @destroyUI()
            FormHelper.Element::destroy.call @, options
            return

        getUI: FormHelper.Element::getJQueryEl
        getInput: FormHelper.Element::getJQueryEl

    createUI = (widget, type = 'Text', className)->
        className = className or Util.StringUtil.firstUpper(widget) + 'UI'
        proto = UIProto widget, className
        FormHelper[className] = class extends FormHelper[type]
        FormHelper[className].UIProto = proto
        for method, fn of proto
            FormHelper[className]::[method] = fn
        FormHelper[className]

    for widget in ['autocomplete', 'datepicker']
        createUI widget

    FormHelper.DatepickerUI::_initializeUI = ->
        lng = application.getLanguage()
        $.datepicker.setDefaults $.datepicker.regional[lng]
        FormHelper.DatepickerUI.UIProto._initializeUI.apply @, arguments

    class FormHelper.DatepickerWithFormatUI extends FormHelper.DatepickerUI
        type: 'DatepickerWithFormatUI'
        constructor: (name, attributes, options = {})->
            super
            @setOption 'belongsTo', name
            @setName 'date'

            items = []
            for lng in application.getLanguages()
                items[items.length] =
                    attributes: value: $.datepicker.regional[lng].dateFormat
                    options: label: $.datepicker.regional[lng].dateFormat
            items[items.length] =
                    attributes: value: 'yy-mm-dd'
                    options: label: 'yy-mm-dd'
            items[items.length] =
                    attributes: value: 'DD, d MM, yy'
                    options: label: 'Full'

            if _.isPlainObject options.select
                sattributes = options.select.attributes
                soptions = options.select.options

            sattributes = _.extend {}, sattributes,
                items: items
                value: $.datepicker.regional[application.getLanguage()].dateFormat

            soptions = _.extend {}, soptions, belongsTo: name

            if typeof sattributes['class'] is 'string' and sattributes['class'].length > 0
                sattributes['class'] += ' form-control'
            else
                sattributes['class'] = 'form-control'

            @select = new FormHelper.Select 'format', sattributes, soptions
            @_changeDateFormat = =>
                @setUIOption 'option', 'dateFormat', @select.getJQueryEl().val()
        _startDecorator: (xhtml)->
            id = @getAttribute 'id'
            label = @getOption 'label'
            if typeof label is 'string'
                label = i18n.t label
            else
                label = ''
            """
            <div class="form-group">
                <label for="#{id}" class="col-sm-4 control-label">#{label}</label>
                <div class="col-md-5 col-sm-4 rel-select">#{xhtml}</div>
            """
        _endDecorator: (xhtml)->
                """
                    <div class="col-md-3 col-sm-4 rel-datepicker">
                        #{xhtml}
                    </div>
                </div>
                """
        getXhtml: ->
            xhtml = super
            value = @getValue()
            if _.isPlainObject value
                @select.setValue value.format
            info = @getInfo()
            @select.setAttribute 'disabled', info.disabled
            @_startDecorator(xhtml) + @_endDecorator(@select.render())
        _initializeUI: ->
            super
            @setUIOption 'option', 'dateFormat', @select.getValue()
            value = @getValue()
            if _.isPlainObject value
                @getInput().val value.date
            $select = @select.getJQueryEl()
            $select.on 'change', @_changeDateFormat
            return
        _destroyUI: ->
            $select = @select.getJQueryEl()
            $select.off 'change', @_changeDateFormat
            super
            return

    createUI 'autocomplete', 'TextArea', 'AutocompleteAreaUI'

    class FormHelper.SliderUI extends FormHelper.Element
        constructor: (name, attributes, options)->
            super
            if _.isPlainObject options.ui
                uiAttributes = options.ui.attributes
                uiOptions = options.ui.options
            @ui = new FormHelper.TagElement _.uniqueId('SliderUI_name_'), {}, _.extend tagName: 'div', uiOptions

            if _.isPlainObject options.input
                inputAttributes = options.input.attributes
                inputOptions = options.input.options
            @input = new FormHelper.Text name, inputAttributes, inputOptions
            info = @getInfo()
            @input.setAttribute 'disabled', info.disabled
            for target in ['input', 'ui']
                @decorators[target] = @decorators[target] or []

            @initialOptions = _.extend 
                slide: (evt, ui)=>
                    @setUIValue ui.value
                    return
            , options.initial
        setUIValue: (value)->
            $input = @getInput().val value

    onlyKeyNumeric = (
        # http://www.cambiaresearch.com/articles/15/javascript-char-codes-key-codes
        allowedKeys = {}
        for key in [8, 9, 13, 27, 46, 110, 190]
            allowedKeys[key] = true

        (evt, keyCode)->
            keyCode = keyCode or if evt.which then evt.which else evt.keyCode
            if (
                # Allow: backspace, tab, enter, escape, delete and . (alphakey + numpad)
                allowedKeys.hasOwnProperty(keyCode) or

                # Allow: Ctrl+A
                (keyCode is 65 and evt.ctrlKey is true) or

                # Allow: home, end, left, right
                (keyCode >= 35 && keyCode <= 39)
            )
                return

            # Numeric key codes are in [48, 57]
            # Numeric numpad codes are in [96, 105]
            # If not number stop the keypress
            if (not evt.shiftKey or (keyCode < 48 or keyCode > 57)) and (keyCode < 96 or keyCode > 105)
                evt.preventDefault()
            return
    )

    if application
        textchange = application.get 'textchange'

    ((proto)->
        for method, fn of proto
            FormHelper.SliderUI::[method] = fn

        FormHelper.SliderUI::_initializeUI = ->
            proto._initializeUI.apply @, arguments
            $ui = @getUI()
            @setUIValue $ui.slider 'value'

            # two binding slider-input
            @onChange =  (evt, keyPressEvent)->
                $this = $(this)
                val = $this.val()
                min = $ui.slider 'option', 'min'
                max = $ui.slider 'option', 'max'
                if val < min
                    keyPressEvent.preventDefault() if keyPressEvent
                    val = min
                    $this.val val
                else if val > max
                    keyPressEvent.preventDefault() if keyPressEvent
                    val = max
                    $this.val val
                $ui.slider 'value', val
                return

            $input = @getInput()
            $input.on textchange, @onChange
            $input.on 'keydown', onlyKeyNumeric

        FormHelper.SliderUI::_destroyUI = ->
            $input = @getInput()
            $input.off textchange, @onChange
            $input.off 'keydown', onlyKeyNumeric
            proto._destroyUI.apply @, arguments
            return

        FormHelper.SliderUI::getXhtml = ->
            xhtml = ''
            for target in ['input', 'ui']
                elHtml = @[target].render()
                for decorator in @decorators[target]
                    elHtml = decorator.call @[target], elHtml
                xhtml += elHtml

            return xhtml

        FormHelper.SliderUI::getUI = ->
            $el = $ '#' + @ui.getAttribute 'id'
            if $el.length is 1
                $el

        FormHelper.SliderUI::getInput = ->
            $el = $ '#' + @input.getAttribute 'id'
            if $el.length is 1
                $el

        FormHelper.SliderUI::setValue = (value)->
            @initialOptions.value = value
            return @

        return
    ) UIProto 'slider', 'SliderUI'

    class FormHelper.SliderRangeUI extends FormHelper.SliderUI
        type: 'SliderRangeUI'
        constructor: (name, attributes, options = {})->
            super
            @initialOptions = _.extend 
                slide: (evt, ui)=>
                    @setUIValue ui.values[0], ui.values[1]
                    return
            , options.initial, range: true

            @decorators.inputMax = []
            if _.isPlainObject options.inputMax
                inputMaxAttributes = options.inputMax.attributes
                inputMaxOptions = options.inputMax.options

            @inputMax = new FormHelper.Text 'max', inputMaxAttributes, inputMaxOptions
            @input.setName 'min'
            @input.setOption 'belongsTo', name
            @inputMax.setOption 'belongsTo', name
            info = @getInfo()
            @inputMax.setAttribute 'disabled', info.disabled
        getInputMax: ->
            $el = $ '#' + @inputMax.getAttribute 'id'
            if $el.length is 1
                $el
        getXhtml: ->
            if not Array.isArray @initialOptions.values
                @initialOptions.values = [@initialOptions.min or 0, @initialOptions.max or 100]

            xhtml = ''
            for target in ['input', 'inputMax', 'ui']
                elHtml = @[target].render()
                for decorator in @decorators[target]
                    elHtml = decorator.call @[target], elHtml

                if target is 'input'
                    elHtml = '<div class="input-slider clearfix">' + elHtml
                else if target is 'inputMax'
                    elHtml += '</div>'
                xhtml += elHtml

            return xhtml
        setValue: (value)->
            if Array.isArray value
                @initialOptions.values = value
            return @
        setUIValue: (min, max)->
            $input = @getInput()
            $inputMax = @getInputMax()
            $input.val min
            $inputMax.val max
            return

    ((proto)->
        FormHelper.SliderRangeUI::_initializeUI = ->
            proto._initializeUI.apply @, arguments
            $ui = @getUI()
            @setUIValue $ui.slider('values', 0), $ui.slider('values', 1)

            $min = @getInput()
            @onMinChange = (evt)->
                $this = $(this)
                min = $this.val()
                max = $ui.slider 'values', 1
                if max < min
                    min = max
                    $this.val max
                $ui.slider 'values', 0, min
            $min.on textchange, @onMinChange
            $min.on 'keydown', onlyKeyNumeric

            $max = @getInputMax()
            @onMaxChange = (evt)->
                $this = $(this)
                min = $ui.slider 'values', 0
                max = $this.val()
                if max < min
                    max = min
                    $this.val min
                $ui.slider 'values', 1, max
            $max.on textchange, @onMaxChange
            $max.on 'keydown', onlyKeyNumeric
            return
        FormHelper.SliderRangeUI::_destroyUI = ->
            $min = @getInput()
            $min.off textchange, @onMinChange
            $min.off 'keydown', onlyKeyNumeric

            $max = @getInputMax()
            $max.off textchange, @onMaxChange
            $max.off 'keydown', onlyKeyNumeric

            proto._destroyUI.apply @, arguments
            return
    ) UIProto 'slider', 'SliderRangeUI'

    viewOnRender = ->
        if @rendered
            # calling render multiple times must destroy previous render
            # otherwise, it will cause a dom leak
            # however, the libray must have a proper destroy function
            for name, element of @elements
                clone = element.clone()
                element.destroy()
                @elements[name] = clone

        FormView::onRender.apply @, arguments

        for name, element of @elements
            element.initializeUI() if 'function' is typeof element.initializeUI

        @rendered = true
        return
    viewDestroy = ->
        @trigger 'destroy', @
        for name, element of @elements
            element.destroy()
        @close()
        if typeof @.$el isnt 'undefined'
            @.$el.destroy()
            @.$el = null
        @el = null
        for own prop of @
            @[prop] = null
        return

    formDecorator = (xhtml)->
        title = @getAttribute('form-title') or ''
        if title isnt ''
            title = i18n.t title

        """
    <fieldset class="center-block">
        <h3 class="text-center">#{title}</h3>
        <div class="elements clearfix">
            #{xhtml}
        </div>
    </fieldset>
        """

    formGroupDecorator = (xhtml)->
        '<div class="form-group">' + xhtml + '</div>'

    explicitLabelDecorator = (xhtml)->
        id = @getAttribute 'id'
        label = @getOption 'label'
        if typeof label is 'string'
            label = i18n.t label
        else
            label = ''
        """<label for="#{id}" class="col-sm-4 control-label">#{label}</label><div class="col-sm-8">#{xhtml}</div>"""

    collectionItemsDecorator =
        target: 'items'
        fn: (xhtml)->
            type = @getType()
            label = @getOption 'label'
            if typeof label is 'string'
                label = i18n.t label
            else
                label = ''
            """
                <label class="#{type}-inline control-label">
                    #{xhtml} #{label}
                </label>
            """

    if typeof document isnt 'undefined'
        $(document.body).popover
            html: true
            placement: 'bottom'
            selector: '[rel=popover]'
            trigger: 'manual focus'

    # Generate a Backbone.Model and a FormView based on added elements
    class FormGenerator extends FormHelper.Form
        formDecorator: formDecorator
        explicitLabelDecorator: explicitLabelDecorator
        formGroupDecorator: formGroupDecorator
        constructor: (name, attributes, options = {})->
            opts = _.clone options
            if not options.hasOwnProperty 'decorators'
                opts.decorators = [formDecorator]
            super name, attributes, opts

        generateView: (options = {}, attributes = {})->
            bindings = {}
            options.decorators = options.decorators or {}
            options.bindings = options.bindings or {}
            form = @.clone()
            for name, element of form.elements
                if options.decorate isnt false and options.decorators[name] isnt false and element.options.decorate isnt false and element.decorators.self.length is 0
                    form.addElementDecorator element
                if options.bind isnt false and element.getOption('bind') isnt false and options.bindings isnt false
                    bindings["[name=" + element.name + "]"] = _.extend
                        observe: element.name
                        setOptions: validate: 'undefined' isnt typeof element.getOption('validation')
                    , options.bindings[name], element.getOption 'bindings'

            view = new FormView _.extend
                form: form
            , options
            view.bindings = bindings
            view.elements = form.elements
            view.onRender = viewOnRender
            view.destroy = viewDestroy
            view

        generateModel: (attributes)->
            model = new Backbone.Model()
            properties =
                validation: {}
                urlRoot: @getAttribute 'action'
            data = {}

            for name, element of @elements
                if typeof element.getValue() isnt 'undefined'
                    model.set element.name, element.getValue()
                if typeof element.getOption('validation') isnt 'undefined'
                    properties.validation[element.name] = element.getOption('validation')

            _.extend model, properties
            model.set attributes
            model

        addElementDecorator: (element)->
            type = element.type
            if /(?:text|password|static-text|(?:^(?:(?!DatepickerWithFormat).)+UI$))/.test type
                if _.isEmpty element.getAttribute('class')
                    element.addClass 'form-control'
                element.addDecorator explicitLabelDecorator
                element.addDecorator formGroupDecorator
            else if element instanceof FormHelper.Collection
                element.addDecorator collectionItemsDecorator
                element.addDecorator explicitLabelDecorator
                element.addDecorator formGroupDecorator
            else if element instanceof FormHelper.Checkbox or element instanceof FormHelper.Radio
                element.addDecorator (xhtml)->
                    """
                <div class="col-sm-offset-4 col-sm-8">
                    <label class="control-label">
                        #{xhtml}
                    </label>
                </div>
                    """
                element.addDecorator formGroupDecorator
            else if element instanceof FormHelper.Button
                element.addDecorator (xhtml)->
                    """<div class="col-sm-offset-4 col-sm-8">#{xhtml}</div>"""
                element.addDecorator formGroupDecorator

    FormGenerator.generateEditForm = (definition, attributes, options)->
        form = new FormGenerator null, attributes, options

        for name, def of definition
            _.isObject(def) or (def = {})
            form.addElement (def.type or 'Text'), name, def.attributes, def.options

        openButtonGroup = (xhtml)->
            """
            <div class="form-group">
                <div class="col-sm-offset-4 col-sm-8">
                    #{xhtml}&nbsp;
            """

        closeButtonGroup = (xhtml)-> xhtml + '</div></div>'

        form.addElement 'Button', 'Cancel',
            class: 'btn btn-default cancel popin-close'
        ,
            content: i18n.t 'form.cancel'
            bind: false
            decorators: [openButtonGroup]

        form.addElement 'Button', 'OK',
            type: 'submit'
            class: 'btn btn-primary'
        ,
            content: '<i class="glyphicon glyphicon-floppy-save"></i> ' + i18n.t 'form.save'
            bind: false
            decorators: [closeButtonGroup]

        form

    FormGenerator.FormHelper = FormHelper
    FormGenerator.createUI = createUI

    return FormGenerator