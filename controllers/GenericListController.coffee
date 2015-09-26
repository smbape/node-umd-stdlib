deps = [
    {common: 'application', amd: 'application'}
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {common: '!jQuery', amd: 'jquery'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    'umd-stdlib/controllers/GenericClientController'
    'umd-stdlib/views/GenericCollectionView'
]

factory = (require, application, _, $, Backbone, GenericClientController, GenericCollectionView)->

    class GenericListController extends GenericClientController
        listAction: ->
            @listRender()
            return

        editAction: ->
            @editRender()
            return

        getCollection: ->
            throw new Error 'undefined'

        getItemModel: (attributes)->
            throw new Error 'undefined'

        getForm: (attributes, model, params)->
            throw new Error 'undefined'

        listRender: (options)->
            self = @

            collection = self.getCollection()
            ListView = self.getListView collection
            collection.fetch complete: ->
                self.view = new ListView options
                self.render()
                return

            return

        getListView: (collection)->
            self = @

            class ListView extends GenericCollectionView
                title: self.get 'title'
                model: collection
                events:
                    'click .delete': (evt)->
                        evt.preventDefault()
                        id = evt.currentTarget.getAttribute 'data-id'
                        model = self.getItemModel()
                        model.set model.idAttribute, id
                        model.destroy complete: ->
                            collection.fetch()
                            return
                        return
                initialize: ->
                    super
                    @ack = _.uniqueId 'ack'
                    @setAttribute 'ack', @ack
                    return
                initUI: ->
                    super
                    application.on @ack, ->
                        collection.fetch()
                        return
                    return
                destroyUI: ->
                    super
                    application.off @ack
                    return

        editRender: (options)->
            self = @

            render = (attributes, model, params)->
                form = self.getForm attributes, model, params
                form.setAttribute 'action', model.urlRoot

                if params.redirect
                    redirect = ->
                        self.redirect params.redirect
                        return
                else if self.popin
                    redirect = ->
                        $.colorbox.close()
                        if params.ack
                            application.trigger params.ack
                        return
                else
                    redirect = ->

                self.view = form.generateView _.extend
                    events:
                        'click .cancel': redirect
                        'submit': (evt)->
                            evt.preventDefault()
                            @save complete: redirect
                            return
                    model: form.generateModel attributes
                , options

                self.render()
                return

            params = self.get 'params'
            model = self.getItemModel()
            model.set model.idAttribute, params[model.idAttribute]
            model.fetch
                success: (model, attributes, options)->
                    render attributes, model, params
                    return
                error: (model, response)->
                    render null, model, params
                    return
            return
