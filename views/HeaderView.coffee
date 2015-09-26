deps = [
    'umd-stdlib/core/common'
    'umd-stdlib/core/ClientUtil'
    'umd-stdlib/core/i18next'
    './templates/header'
]

factory = (require, com, ClientUtil, i18n, template)->
    Backbone = com.Backbone
    application = com.application
    clientDefaultRouteEngine = application.get 'clientDefaultRouteEngine'
    easingDuration = 250

    class HeaderView extends com.gen.views.View
        tagName: 'nav'
        className: 'navbar navbar-default'
        attributes: role: 'navigation'
        template: template
        events:
            'click .chg-lng': (evt)->
                evt.preventDefault()
                language = $(evt.currentTarget).attr 'language'
                application.setLanguage language
                return

            'click .toggle-menu': (evt)->
                $('#menu').toggle 'blind', {}, easingDuration
                return

        initialize: ->
            super

            @model = new Backbone.Model 'id': @id

            languages = application.get 'languages'
            lngs = {}
            @model.set 'languages', lngs
            flags = application.get('config').flags

            for language, locale of languages
                lngs[locale] =
                    label: i18n.t 'label', lng: locale, defaultValue: locale
                    language: language
                    flag: flags[locale]

            # Everytime language changes, update display
            self = @
            application.on 'change:locale', (application, locale, options)->
                self.render()
                return

            application.on 'render', ->
                if $(window).width() < 768
                    $('#menu').hide 'blind', {}, easingDuration
                return

            return

        onRender: ->
            @model.set 'homepage', clientDefaultRouteEngine.getUrl()
            prevLanguage = @model.get 'language'
            delete prevLanguage.disabled if prevLanguage
            language = @model.get('languages')[application.get('locale')]
            language.disabled = true
            @model.set 'language', language
            super
