deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    'umd-stdlib/core/i18next'
    {node: 'handlebars', common: '!Handlebars', amd: 'handlebars'}
]

factory = (require, _, i18n, Handlebars)->
    # containing various method usable by client
    ClientUtil =
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
        getLocationRoot: ->
            location.protocol + '//' + location.host

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

    return ClientUtil
