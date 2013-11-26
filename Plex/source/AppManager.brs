Function AppManager()
    if m.AppManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' The unlocked state of the app, one of: PlexPass, Purchased, Trial, or Limited
        obj.IsPlexPass = false
        obj.IsPurchased = false
        obj.IsAvailableForPurchase = false
        obj.IsInTrialWindow = true
        obj.ResetState = managerResetState
        obj.ResetState()

        ' Track anything that needs to be initialized before the app can start
        ' and an initial screen can be shown. These need to be important,
        ' generally related to whether the app is unlocked or not.
        obj.Initializers = CreateObject("roAssociativeArray")
        obj.AddInitializer = managerAddInitializer
        obj.ClearInitializer = managerClearInitializer
        obj.IsInitialized = managerIsInitialized

        ' Media playback is allowed if the app is unlocked or still in a trial
        ' period. So, basically, if it's not Limited.
        obj.IsPlaybackAllowed = managerIsPlaybackAllowed

        ' Channel store
        obj.FetchProducts = managerFetchProducts
        obj.HandleChannelStoreEvent = managerHandleChannelStoreEvent

        ' Singleton
        m.AppManager = obj

        obj.FetchProducts()
    end if

    return m.AppManager
End Function

Sub managerAddInitializer(name)
    m.Initializers[name] = true
End Sub

Sub managerClearInitializer(name)
    if m.Initializers.Delete(name) AND m.IsInitialized() then
        GetViewController().OnInitialized()
    end if
End Sub

Function managerIsInitialized() As Boolean
    m.Initializers.Reset()
    return m.Initializers.IsEmpty()
End Function

Function managerIsPlaybackAllowed() As Boolean
    return m.State <> "Limited"
End Function

Sub managerResetState()
    if m.IsPlexPass then
        m.State = "PlexPass"
    else if m.IsPurchased then
        m.State = "Purchased"
    else if m.IsInTrialWindow then
        m.State = "Trial"
    else
        m.State = "Limited"
    end if

    Debug("App state is now: " + m.State)
End Sub

Sub managerFetchProducts()
    m.AddInitializer("channelstore")

    ' The docs suggest we can make two requests at the same time by using the
    ' source identity, but it doesn't actually work. So we'd need to get the
    ' catalog and the purchases serially. Fortunately, the docs also fail to
    ' mention that the catalog returns the purchased date. So we can just fetch
    ' the catalog and get all the info we need.

    store = CreateObject("roChannelStore")
    store.SetMessagePort(GetViewController().GlobalMessagePort)
    store.GetCatalog()
    m.PendingStore = store
End Sub

Sub managerHandleChannelStoreEvent(msg)
    m.ClearInitializer("channelstore")
    if msg.isRequestSucceeded() then
        for each product in msg.GetResponse()
            'if product.code = "PROD1" then ' Sample product when sideloaded
            if product.code = "plexunlock" then
                m.IsAvailableForPurchase = true
                if product.purchaseDate <> invalid then
                    date = CreateObject("roDateTime")
                    date.FromISO8601String(product.purchaseDate)
                    if date.AsSeconds() > 0 then
                        m.IsPurchased = true
                    end if
                end if
            end if
        next
        Debug("IAP is available: " + tostr(m.IsAvailableForPurchase))
        Debug("IAP is purchased: " + tostr(m.IsPurchased))
        m.ResetState()
    end if

    m.PendingStore = invalid
End Sub
