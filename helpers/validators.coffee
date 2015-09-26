deps = [{node: 'lodash', common: '!_', amd: 'lodash'}]
factory = (require, _)->

    required: 
        required: true
        msg: 'required'
    either: (list)->
        return if not _.isArray list
        {
            fn: (value, attr, computed) ->
                invalid = true
                for attr in list
                    if 'string' is typeof computed[attr] and computed[attr].length > 0
                        invalid = false
                        break
                if invalid
                    error: 'either'
                    options: list: list.join ', '
        }
    maxLength: (maxLength)->
        {
            fn: (value, attr, computed) ->
                if typeof value is 'string' and value.length > maxLength
                    error: 'maxLength'
                    options:
                        maxLength: maxLength
                        given: value.length
        }
    minLength: (minLength)->
        {
            fn: (value, attr, computed) ->
                if typeof value is 'string' and value.length < minLength
                    error: 'minLength'
                    options:
                        minLength: minLength
                        given: value.length
        }
    length: (length)->
        {
            fn: (value, attr, computed) ->
                if typeof value isnt 'string' or value.length isnt length
                    error: 'length'
                    options:
                        length: length
                        given: value.length
        }
    password:
        fn: (value, attr, computed) ->
            errorList = []
            if typeof value is 'string' and value.length < 6
                errorList.push
                    error: 'minLength'
                    options:
                        minLength: 6
                        given: value.length

            if typeof value is 'string' and value.length > 255
                errorList.push
                    error: 'maxLength'
                    options:
                        maxLength: 6
                        given: value.length

            errorsArray = [
                'digit'
                'lowercase'
                'uppercase'
                'special'
            ]

            re = /([\da-zA-Z]|[^\t\r\n\w])/g
            while (match = re.exec(value))
                errorsArray.splice(errorsArray.indexOf('digit'), 1) if ~errorsArray.indexOf('digit') and /\d/.test match[0]
                errorsArray.splice(errorsArray.indexOf('lowercase'), 1) if ~errorsArray.indexOf('lowercase') and /[a-z]/.test match[0]
                errorsArray.splice(errorsArray.indexOf('uppercase'), 1) if ~errorsArray.indexOf('uppercase') and /[A-Z]/.test match[0]
                errorsArray.splice(errorsArray.indexOf('special'), 1) if ~errorsArray.indexOf('special') and /[^\t\r\n\w]/.test match[0]
                if errorsArray.length is 0
                    break

            errorList = errorList.concat errorsArray
            errorList if errorList.length > 0