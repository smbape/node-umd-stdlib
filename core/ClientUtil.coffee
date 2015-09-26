deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    'umd-stdlib/core/GenericUtil'
    'umd-stdlib/core/QueryString'
    'umd-stdlib/core/i18next'
    {node: 'handlebars', common: '!Handlebars', amd: 'handlebars'}
]

factory = (require, _, GenericUtil, QueryString, i18n, Handlebars)->
    # containing various method usable by client
    ClientUtil =
        isCurrentUrl: (url)->
            currentUrl = @getCurrentUrl()
            if _.isPlainObject url
                url = @getUrl url
            if url is currentUrl
                return true
            RouterEngine = require 'umd-stdlib/core/RouterEngine'
            RouterEngine::removeLeadTrail(url) is RouterEngine::removeLeadTrail(currentUrl)

        getUrl: (params)->
            clientDefaultRouteEngine = require('application').get 'clientDefaultRouteEngine'
            if typeof params is 'string'
                return clientDefaultRouteEngine.baseUrl + params
            clientDefaultRouteEngine.getUrl params

        isLocationFile: ->
            # '...index.html#url?query!anchor'
            # ^\w+ : protocol
            # // : //
            # (?:[^:@\/]+(?::[^@\/]+)?@)? : [user[:pass]@]
            # [^@\/]+ : url
            # / : /
            # [^?#!]+\.\w+ : filename.ext
            # 
            fileReg = /^file:\/\/\/\w|\w+:\/\/(?:[^:@\/]+(?::[^@\/]+)?@)?[^@\/]+\/[^?#!]+\.\w+[?#!]?/
            fileReg.test window.location.href
        getHashLocation: (url)->
            url or (url = window.location.hash.slice(1))
            # '#url?query!anchor'
            splitPathReg = /^([^?!]*)(\?[^!]*)?(\!.*)?$/
            return {pathname: '', search: '', hash: ''} if not (split = splitPathReg.exec url)

            pathname: split[1] or ''
            search: split[2] or ''
            hash: split[3] or ''
        getPathLocation:  (url)->
            if url
                splitPathReg = /^([^?#]*)(\?[^#]*)?(\#.*)?$/
                return {pathname: '', search: '', hash: ''} if not (split = splitPathReg.exec url)
                pathname: split[1] or ''
                search: split[2] or ''
                hash: split[3] or ''
            else
                pathname: window.location.pathname
                search: window.location.search
                hash: window.location.hash
        getLocation: (url)->
            if require('application').get 'hasPushState'
                @getPathLocation url
            else
                @getHashLocation url
        getLocationRoot: ->
            location.protocol + '//' + location.host
        getQueryString: ->
            if require('application').get 'hasPushState'
                search = window.location.search
            else
                search = ''
                splitQueryReg = /^#[^?]*(\?[^?]+)$/
                split = splitQueryReg.exec window.location.hash
                if Array.isArray split
                    search = split[1]
            search
        setLocationHash: (hash)->
            hash or (hash = @getLocation().hash)
            return false if not hash
            if hash.charAt(0) in ['#', '!']
                hash = hash.substring 1
            return false if hash.length is 0

            if require('application').get 'hasPushState'
                if window.location.hash is '#' + hash
                    element = document.getElementById(hash) or $("[name=#{hash.replace(/([\\\/])/g, '\\$1')}]")[0]
                    element.scrollIntoView() if element
                else
                    window.location.hash = '#' + hash
            else
                location = @getHashLocation()
                location.hash = '!' + hash
                window.location.hash = '#' + location.pathname + location.search + location.hash
                element = document.getElementById(hash) or $("[name=#{hash}]")[0]
                element.scrollIntoView() if element

            return true

        getQueryParams: ->
            search = @getQueryString()
            QueryString.parse search

        # Return url without query string
        getCurrentUrl: ->
            url = Backbone.history.fragment
            if GenericUtil.notEmptyString url
                loc = @getLocation url
                loc.pathname
            else if loc = @getLocation()
                loc.pathname

        valid: (view)->
            if typeof view.valid is 'function'
                return view.valid.apply view, arguments
            return false
        invalid: (view)->
            if typeof view.invalid is 'function'
                return view.invalid.apply view, arguments
            return false
        resultStr: (str, context)->
            if /\{\{(?:(?!(?:\{\{|\}\})).)+\}\}/.test str
                template = Handlebars.compile str
                str = template context

            str
        translateError: (error)->
            if typeof error is 'string'
                str = 'error.' + error
                textError = i18n.t str
                if str is textError
                    textError = error
            else if Array.isArray error
                textError = '<ul>'
                for err in error
                    textError += '<li>' + ClientUtil.translateError(err) + '</li>'
                textError += '</ul>'
            else if _.isPlainObject error

                if error.hasOwnProperty('error')
                    options = error.options
                    error = error.error

                    str = 'error.' + error
                    textError = i18n.t str, options

                    if textError is str
                        textError = i18n.t error, options

            textError

    _.extend ClientUtil, GenericUtil

    return ClientUtil
