deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    'umd-stdlib/core/GenericUtil'
    'umd-stdlib/controllers/GenericController'
]
factory = (require, _, GenericUtil, GenericController)->

    return class GenericClientController extends GenericController
        redirect: (url, options)->
            if 'boolean' is typeof options
                options = reset: options, trigger: true, replace: false
            else if null is options or 'object' isnt typeof options
                options = trigger: true, replace: false
            url = @getUrl(url, options) if _.isObject url
            @get('router').navigate url, options
            return

        # @private
        getMethod: (params)->
            GenericUtil.StringUtil.toCamelDash(params.action.toLowerCase()) + 'Action'

        destroy: ->
            if _.isObject(@view) and 'function' is typeof @view.destroy
                @view.destroy()
            super

        renderView: (content)->
            container = @get 'container'

            if typeof content isnt 'undefined'
                if _.isObject content
                    view = _.pick content, ['title']
                    options = content.options or {}
                    content = content.data
                else
                    view = {data: content, title: @get('title')}
                    options = {}
                options.onBeforeRender container if 'function' is typeof options.onBeforeRender
                @emit 'before:render', view
                container.empty().html content
                options.onRender container if 'function' is typeof options.onRender
                @emit 'render', view
                return @

            container.empty().append @view.el
            @view.once 'before:render', =>
                @emit 'before:render', @view
            @view.once 'render', =>
                @emit 'render', @view

            @view.render()
            return @
        render: (content)->
            if typeof content isnt 'undefined' or typeof @view isnt 'undefined'
                return @renderView content
            throw new Error 'Generic Render Exception: '
