deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    'umd-stdlib/core/ClientUtil'
    'umd-stdlib/views/GenericView'
    'umd-stdlib/core/i18next'
    'umd-stdlib/core/QueryString'
    'umd-stdlib/core/Backbone.stickit.custom'
]

factory = (require, _, ClientUtil, GenericView, i18n, QueryString)->
    class GenericFormView extends GenericView
        validate: true
        bind: 'validated:invalid'
        tagName: 'form'
        className: 'generic-form form-horizontal'
        events: submit: 'saveModel'
        constructor: (options = {})->
            @saveModel = options.saveModel if typeof options.saveModel is 'function'
            if options.form
                @form = options.form
                @attributes = @form.getAttributes()
            if typeof options.valid is 'function'
                @valid = options.valid
            if typeof options.invalid is 'function'
                @invalid = options.invalid
            if options.hasOwnProperty 'bind'
                @bind = options.bind
            super
            return

        initialize: ->
            super
            return if not @model
            @model.on 'save:success', @onSuccess, @
            @model.on 'save:error', @onErrors, @
            if @bind is true
                @enableBinding()
            else if 'string' is typeof @bind
                bindEvt = @bind
                @model.on bindEvt, @enableBinding, @

            @once 'destroy', =>
                @unstickit()
                @model.off 'save:success', @onSuccess, @
                @model.off 'save:error', @onErrors, @
                @model.off bindEvt, @enableBinding, @ if bindEvt
                return

            return

        enableBinding: ->
            if not @hasBinging
                @hasBinging = true
                @stickit()
            return

        valid: (view, attr, selector = 'name') ->
            $el = view.$ "[#{selector}=#{attr}]"
            return false if $el.length is 0
            $el.closest('.form-group').removeClass 'has-error'
            $el.parent().removeClass 'has-error'
            popover = $el.data 'bs.popover'
            popover.hide() if popover
            $el.removeAttr 'rel'
            return true

        invalid: (view, attr, error, selector = 'name') ->
            $el = view.$ "[#{selector}=#{attr}]"
            return false if $el.length is 0
            $el.closest('.form-group').addClass 'has-error'
            $el.parent().addClass 'has-error'
            msg = ClientUtil.translateError error
            $el.attr
                'rel': 'popover'
                'data-content': msg
            if $el.is ':focus'
                popover = $el.data 'bs.popover'
                if popover
                    # popover.hide()
                    popover.show()
                $el.trigger 'focus'

            return true

        save: (options)->
            return unless @validModel()
            success = options.success
            error = options.error
            complete = options.complete
            @.$('input, button').prop 'disabled', true
            @model.save null, _.extend {}, options,
                success: (model, response, options) =>
                    @.$('input, button').prop 'disabled', false
                    if response.error
                        error.call @, model, response.error, options if (error)
                        @model.trigger 'save:error', model, response, options
                    else
                        success.call @, model, response, options if (success)
                        @model.trigger 'save:success', model, response, options
                    return
                error: (model, response, options)=>
                    @.$('input, button').prop 'disabled', false
                    error.call @, model, response, options if (error)
                    @model.trigger 'save:error', model, response, options
            return

        saveModel: (evt)->
            evt.preventDefault()
            @save()
            return

        validModel: ->
            # https://github.com/thedersen/backbone.validation#isvalid
            data = @.$el.serializeObject()
            @model.set data
            @model.isValid true

        onRender: ->
            if @form
                values = @model.toJSON()
                for name, value of values
                    if typeof value isnt 'undefined' and value isnt null and element = @form.getElement name
                        element.setValue value
                xhtml = @form.getInnerHTML()
            else
                xhtml = @template @model and @model.toJSON()
            @.$el.html xhtml

            @unstickit()
            if @hasBinging
                @stickit()

            return true

        onSuccess:(response) ->
            if _.isPlainObject(response) and _.isPlainObject(response.data) and typeof response.data.message is 'string'
                $().toastmessage 'showToast',
                    text     : i18n.t response.data.message
                    position : 'top-right'
                    type     : 'success'

        onErrors: (error)->
            $el = @.$ '.elements'
            $msg = @.$ '.messages.help-block'

            if $msg.length is 0
                $().toastmessage 'showToast',
                    text     : text
                    position : 'top-right'
                    type     : 'error'
                    sticky   : true
                return

            $msg.removeClass 'hidden'

            text = ClientUtil.translateError error, true
            $msg.html text

            $().toastmessage 'showToast',
                text     : text
                position : 'top-right'
                type     : 'error'