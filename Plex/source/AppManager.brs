Function AppManager()
    if m.AppManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' The unlocked state of the app, one of: PlexPass, Purchased, Trial, or Limited
        obj.IsPlexPass = false
        obj.IsPurchased = false
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

        ' Singleton
        m.AppManager = obj
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
