factory = (require)->
    'en-GB': translation:
        label: 'English'
        error:
            required: 'Field is required'
            required_value: 'Field [__value__] is required'
            maxLength: 'Number of characters must not exceed __maxLength__. Given __given__'
            minLength: 'Number of characters must be greater than __minLength__. Given __given__'
            length: 'Number of characters must be __length__. Given: __given__'
            either: 'One of [__list__] is required'
            digit: 'Missing a digit character'
            lowercase: 'Missing a lowercase character'
            uppercase: 'Missing an uppercase character'
            special: 'Missing a special character'
            email: '__attr__ is not a valid email'
        welcome: 'Welcome'
        default: home: index: title: 'Home'
        brand: 'Brand'
        'change-language': 'Change language'
        form:
            create: 'Create'
            edit: 'Edit'
            cancel: 'Cancel'
            save: 'Save'
            delete: 'Delete'
        login: 'Sign in'
        logout: 'Sign out'
    'fr-FR': translation:
        label: 'Français'
        error:
            authenticate: 'Invalid authentication credentials'
            restrict: 'Restricted session'
            required: 'Le champ est requis'
            required_value: 'Le champ [__value__] est requis'
            maxLength: 'Le nombre de charactères ne peut dépasser __maxLength__. Actuel: __given__'
            minLength: 'Le nombre de charactères doit être supérieur à __minLength__. Actuel: __given__'
            length: 'Le nombre de charactères doit être __length__. Actuel: __given__'
            either: "L'un des champs [__list__] est requis"
            digit: 'Un chiffre est requis'
            lowercase: 'Une minuscule est requise'
            uppercase: 'Une majuscule est requise'
            special: 'Un caractère spécial est requis'
            email: "__attr__ n'est pas une adresse email valide"
        welcome: 'Bienvenue'
        default: home: index: title: 'Accueil'
        brand: 'Marque'
        'change-language': 'Changer la langue'
        form:
            create: 'Créer'
            edit: 'Modifier'
            cancel: 'Annuler'
            save: 'Enregistrer'
            delete: 'Supprimer'
        login: 'Se connecter'
        logout: 'Se déconnecter'