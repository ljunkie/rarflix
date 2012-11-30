'*
'* A simple wrapper around a slideshow. Single items and lists are both supported.
'*

Function createPhotoPlayerScreen(context, contextIndex, viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roSlideShow")
    screen.SetMessagePort(obj.Port)

    screen.SetUnderscan(2.5)
    screen.SetMaxUpscale(8.0)
    screen.SetDisplayMode("photo-fit")
    screen.SetPeriod(RegRead("slideshow_period", "preferences", "6").toInt())
    screen.SetTextOverlayHoldTime(RegRead("slideshow_overlay", "preferences", "2500").toInt())

    ' Standard screen properties
    obj.Screen = screen
    if type(context) = "roArray" then
        obj.Item = context[contextIndex]
        if obj.Item.server.AccessToken <> invalid then
            screen.AddHeader("X-Plex-Token", obj.Item.server.AccessToken)
        end if
        screen.SetContentList(context)
        screen.SetNext(contextIndex, true)
    else
        obj.Item = context
        if obj.Item.server.AccessToken <> invalid then
            screen.AddHeader("X-Plex-Token", obj.Item.server.AccessToken)
        end if
        screen.AddContent(context)
        screen.SetNext(0, true)
    end if

    obj.HandleMessage = photoPlayerHandleMessage

    return obj
End Function

Function photoPlayerHandleMessage(msg) As Boolean
    ' We don't actually need to do much of anything, the slideshow pretty much
    ' runs itself.

    handled = false

    if type(msg) = "roSlideShowEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isPlaybackPosition() then
            'm.CurIndex = msg.GetIndex()
        else if msg.isRequestFailed() then
            Debug("preload failed: " + tostr(msg.GetIndex()))
        else if msg.isRequestInterrupted() then
            Debug("preload interrupted: " + tostr(msg.GetIndex()))
        else if msg.isPaused() then
            Debug("paused")
        else if msg.isResumed() then
            Debug("resumed")
        end if
    end if

    return handled
End Function
