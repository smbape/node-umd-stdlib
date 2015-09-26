deps = [
    {common: 'application', amd: 'application'}
    {node: 'lodash', common: '!_', amd: 'lodash'}
    {common: '!jQuery', amd: 'jquery'}
    {node: 'backbone', common: '!Backbone', amd: 'backbone'}
    {node: 'events', common: '!EventEmitter', amd: 'eventEmitter'}
    'umd-stdlib/core/GenericUtil'
    'umd-stdlib/controllers/GenericController'
    'umd-stdlib/controllers/GenericClientController'
    'umd-stdlib/controllers/GenericListController'
    'umd-stdlib/models/GenericCollection'
    'umd-stdlib/models/GenericSwitchCollection'
    'umd-stdlib/models/GenericSwitchModel'
    {common: 'umd-stdlib/views/GenericCollectionView', amd: 'umd-stdlib/views/GenericCollectionView'}
    {common: 'umd-stdlib/views/GenericFormView', amd: 'umd-stdlib/views/GenericFormView'}
    {common: 'umd-stdlib/views/GenericLayoutView', amd: 'umd-stdlib/views/GenericLayoutView'}
    {common: 'umd-stdlib/views/GenericView', amd: 'umd-stdlib/views/GenericView'}
]

factory = (
    require
    application
    _
    $
    Backbone
    events
    GenericUtil
    GenericController
    GenericClientController
    GenericListController
    GenericCollection
    GenericSwitchCollection
    GenericSwitchModel
    GenericCollectionView
    GenericFormView
    GenericLayoutView
    GenericView
)->
    application: application
    isClient: !!application
    _: _
    $: $
    Backbone: Backbone
    EventEmitter: events.EventEmitter or events
    gen:
        controllers:
            Controller: GenericController
            ClientController: GenericClientController
            ListController: GenericListController
        models:
            Collection: GenericCollection
            SwitchCollection: GenericSwitchCollection
            SwitchModel: GenericSwitchModel
        views:
            View: GenericView
            CollectionView: GenericCollectionView
            FormView: GenericFormView
            LayoutView: GenericLayoutView
        Util: GenericUtil
