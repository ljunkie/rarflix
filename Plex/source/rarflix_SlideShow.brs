Function createICphotoPlayerScreen(context, contextIndex, viewController, shuffled=false, slideShow=true)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.OnTimerExpired = ICphotoPlayerOnTimerExpired

    ' ljunkie - we need to iterate through the items and remove directories -- they don't play nice
    ' note: if we remove directories ( itms ) the contextIndex will be wrong - so fix it!
    if type(context) = "roArray" then
        key = context[contextIndex].key
        newcontext = []
        for each item in context
            if item <> invalid and tostr(item.nodename) = "Photo" then 
                newcontext.Push(item)
            else 
                if item <> invalid then Debug("skipping item: " + tostr(item.nodename) + " " + tostr(item.title))
            end if
        next
        
        ' reset contextIndex (curIndex) if needed -- it may have shifted
        if context.count() <> newcontext.count() then 
            contextIndex = 0 ' reset context to zero, unless we find a match
            for index = 0 to newcontext.count() - 1 
                if key = newcontext[index].key then 
                    contextIndex = index
                    exit for
                end if
            end for
        end if
        context = newcontext
    end if
    ' end cleaning

    if type(context) = "roArray" then
        obj.item = context[contextIndex]
        obj.CurIndex = contextIndex
        obj.PhotoCount = context.count()
        obj.context = context
    else 
        ' this actually shouldn't be possible as we always pass the full context
        obj.context = [context]
        obj.CurIndex = 0
        obj.PhotoCount = 1
    end if
   
    obj.isSlideShow = slideShow ' if we came in through the play/slide show vs showing a shingle item
    obj.ImageCanvasName = "slideshow" 
    obj.IsPaused = true
    obj.ForceResume = false

    obj.playbackTimer = createTimer()

    AudioPlayer().focusedbutton = 0

    obj.HandleMessage = ICphotoPlayerHandleMessage

    NowPlayingManager().SetControllable("photo", "skipPrevious", obj.Context.Count() > 1)
    NowPlayingManager().SetControllable("photo", "skipNext", obj.Context.Count() > 1)

    screen = createobject("roimagecanvas")
    theme = getImageCanvasTheme()
    screen.SetLayer(0, theme["background"])
    screen.SetMessagePort(obj.Port)

    obj.Screen = screen
    obj.doReload = RegRead("slideshow_reload", "preferences", "disabled")

    obj.Pause = ICphotoPlayerPause
    obj.Resume = ICphotoPlayerResume
    obj.Next = ICphotoPlayerNext
    obj.Prev = ICphotoPlayerPrev
    obj.Stop = ICphotoPlayerStop

    obj.IsShuffled = shuffled
    obj.SetShuffle = ICphotoPlayerSetShuffle
    if shuffled then
        NowPlayingManager().timelines["photo"].attrs["shuffle"] = "1"
    else
        NowPlayingManager().timelines["photo"].attrs["shuffle"] = "0"
    end if

    if obj.Timer = invalid then
        time = RegRead("slideshow_period", "preferences", "6").toInt()
        obj.Timer = createTimer()
        obj.Timer.Name = "slideshow"
        obj.Timer.SetDuration(time*1000, true)
        obj.Timer.Active = false
        GetViewController().AddTimer(obj.Timer, obj)
    end if
    return obj

End Function

Function ICphotoPlayerHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roImageCanvasEvent" then
        print "-- ImageCanvasEvent!"
        handled = true

        if msg.isScreenClosed() then
            amountPlayed = m.playbackTimer.GetElapsedSeconds()
            Debug("Sending analytics event, appear to have watched slideshow for " + tostr(amountPlayed) + " seconds")
            AnalyticsTracker().TrackEvent("Playback", firstOf(m.Item.ContentType, "photo"), m.Item.mediaContainerIdentifier, amountPlayed)
            NowPlayingManager().location = "navigation"
            NowPlayingManager().UpdatePlaybackState("photo", invalid, "stopped", 0)

            m.ViewController.PopScreen(m)
        else if msg.isRemoteKeyPressed() then
            print "button pressed" + tostr(msg.GetIndex())
            'assigned
            '  0: KeyBack :: close
            '  4: KeyLeft :: prev
            '  5: KeyRight:: next
            '  6: KeyOk :: play/pause ( but only slideshow )
            ' 13: play/pause :: play/pause ( slideshow and audio )
            
            ' TODO
            ' 10: KeyInfo :: context menu
            '  2: KeyUp :: overlay toggle
            '  3: KeyDown :: overlay toggle
            
            ' unassigned
            ' 8: KeyRev :: 
            ' 9: KeyFwd :: 
            ' 7: replay:: 

            if msg.GetIndex() = 0 then 
                m.Stop()
            else if msg.GetIndex() = 2 then 
                print "up pressed"
            else if msg.GetIndex() = 3 then 
                print "down pressed"
            else if msg.GetIndex() = 4 then 
                print "left pressed"
                m.prev()
            else if msg.GetIndex() = 5 then 
                print "right pressed"
                m.next()
            else if msg.GetIndex() = 6 then
                ' OK button -- pause or start photo only
                if m.IsPaused then 
                    m.resume()
                else 
                    m.pause()
                end if
            else if msg.GetIndex() = 13 then
                ' Play/Pause button -- pause or start photo/music
                if m.IsPaused then 
                    if audioplayer().IsPaused then Audioplayer().Resume()
                    m.resume()
                else 
                    if AudioPlayer().IsPlaying then AudioPlayer().Pause()
                    m.pause()
                end if
            else if msg.GetIndex() = 10 then
                if type(m.context) = "roArray" and m.CurIndex <> invalid then obj = m.context[m.CurIndex]
                m.forceResume = NOT(m.isPaused)
                m.Pause()
                photoPlayerShowContextMenu(obj)
            end if

        end if
    end if

    return handled
End Function

sub ICphotoPlayerOnTimerExpired(timer)

    if timer.Name = "slideshow" then
        m.Next()
    end if

End Sub

sub ICphotoPlayerNext()
    print "-- next"
    if m.nextindex <> invalid then 
        i = m.nextindex
    else 
        i = m.curindex
    end if
    if i > m.context.count()-1 then i=0  
    m.curindex = i

    NowPlayingManager().location = "fullScreenPhoto"
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)

    display=[{url:m.context[i].url, targetrect:{x:0,y:0,w:1280,h:720}}]
    m.screen.setlayer(1,display)      
    m.nextindex = m.curindex+1
    m.Timer.Mark()
    GetViewController().ResetIdleTimer()
end sub

sub ICphotoPlayerPrev()
    print "-- Previous"
    i=m.curindex-1
    if i < 0 then i = m.context.count()-1
    m.curindex=i

    NowPlayingManager().location = "fullScreenPhoto"
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)

    display=[{url:m.context[i].url, targetrect:{x:0,y:0,w:1280,h:720}}]
    m.screen.setlayer(1,display)      
    m.nextindex = m.curindex+1
    m.Timer.Mark()
    GetViewController().ResetIdleTimer()
end sub

sub ICphotoPlayerPause()
   ' DONE
   print "-- Pause"
   m.IsPaused = true
   m.Timer.Active = false
   NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "paused", 0)
end sub

sub ICphotoPlayerResume()
   ' DONE
   print "-- Resume"
   m.IsPaused = false
   m.Timer.Active = true
   NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)
end sub


sub ICphotoPlayerStop()
    print "-- Stop"
    m.Screen.Close()
end sub


Sub ICphotoPlayerSetShuffle(shuffleVal)
    newVal = (shuffleVal = 1)
    if newVal = m.IsShuffled then return

    m.IsShuffled = newVal
    if m.IsShuffled then
        m.CurIndex = ShuffleArray(m.Context, m.CurIndex)
    else
        m.CurIndex = UnshuffleArray(m.Context, m.CurIndex)
    end if

    if m.CurIndex < m.PhotoCount - 1 then
        m.NextIndex = m.CurIndex + 1
    else
        m.NextIndex = 0
    end if

    NowPlayingManager().timelines["photo"].attrs["shuffle"] = tostr(shuffleVal)
End Sub
