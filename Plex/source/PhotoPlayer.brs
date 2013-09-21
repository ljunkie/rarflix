'*
'* A simple wrapper around a slideshow. Single items and lists are both supported.
'*

Function createPhotoPlayerScreen(context, contextIndex, viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)
    RegWrite("slideshow_overlay_force", "0", "preferences")

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
        AddAccountHeaders(screen, obj.Item.server.AccessToken)
        screen.SetContentList(context)
        screen.SetNext(contextIndex, true)
    else
        obj.Item = context
        AddAccountHeaders(screen, obj.Item.server.AccessToken)
        screen.AddContent(context)
        screen.SetNext(0, true)
    end if

    obj.HandleMessage = photoPlayerHandleMessage

    obj.playbackTimer = createTimer()

    return obj
End Function

Function photoPlayerHandleMessage(msg) As Boolean
    ' We don't actually need to do much of anything, the slideshow pretty much
    ' runs itself.

    handled = false

    if type(msg) = "roSlideShowEvent" then
        handled = true

        if msg.isScreenClosed() then
            ' Send an analytics event
            RegWrite("slideshow_overlay_force", "0", "preferences")
            amountPlayed = m.playbackTimer.GetElapsedSeconds()
            Debug("Sending analytics event, appear to have watched slideshow for " + tostr(amountPlayed) + " seconds")
            m.ViewController.Analytics.TrackEvent("Playback", firstOf(m.Item.ContentType, "photo"), m.Item.mediaContainerIdentifier, amountPlayed)

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
        else if msg.isRemoteKeyPressed() then
            if msg.GetIndex() = 3 then
                ol = RegRead("slideshow_overlay_force", "preferences","0")
                time = invalid            
                if ol = "0" then
                    time = 2500 ' force show overlay
                    if RegRead("slideshow_overlay", "preferences", "2500").toInt() > 0 then time = 0 'prefs to show, force NO show
                    RegWrite("slideshow_overlay_force", "1", "preferences")
                else
                    ' print "Making overlay invisible ( or set back to the perferred settings )"
                    RegWrite("slideshow_overlay_force", "0", "preferences")
                    time = RegRead("slideshow_overlay", "preferences", "2500").toInt()
               end if

               if time <> invalid then
                   if time = 0 then
                       ' print "Forcing NO overlay"
                       m.screen.SetTextOverlayHoldTime(0)
                       m.screen.SetTextOverlayIsVisible(true) 'yea, gotta set it true to set it false?
                       m.screen.SetTextOverlayIsVisible(false)
                   else 
                      ' print "Forcing Overlay"
                       m.screen.SetTextOverlayHoldTime(0)
                       m.screen.SetTextOverlayIsVisible(true)
                       print "sleeping to show overlay"
                       sleep(time) ' sleeping to show overlay, otherwise we just get a blip (even with m.screen.SetTextOverlayHoldTime(1000)
                       m.screen.SetTextOverlayIsVisible(false)
                       m.screen.SetTextOverlayHoldTime(time)
                   end if
                end if
            end if
        end if
    end if

    return handled
End Function
