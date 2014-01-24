'
' TODO:
' * timer to hide overlay 
' * reload slideshow ( after completion )
' * verify shuffle works
' * verify remote control works

' TASK:
' * Photo Display mode -- seems like it's cropping 
'    X -- cropping fixed 
'    X -- cached images 
'    X -- purge cache when needed ( to much or close the screen )
'    -- center the image ( since we no longer "stretch/crop" )

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
   
    obj.isSlideShow = slideShow       ' if we came in through the play/slide show vs showing a shingle item
    obj.ImageCanvasName = "slideshow" ' used if we need to know we are in a slideshow screen
    obj.IsPaused = true
    obj.ForceResume = false

    obj.LocalFiles = []
    obj.LocalFileSize = 0

    obj.playbackTimer = createTimer()
    AudioPlayer().focusedbutton = 0
    obj.HandleMessage = ICphotoPlayerHandleMessage

    NowPlayingManager().SetControllable("photo", "skipPrevious", obj.Context.Count() > 1)
    NowPlayingManager().SetControllable("photo", "skipNext", obj.Context.Count() > 1)

    screen = createobject("roimagecanvas")
    screen.SetRequireAllImagesToDraw(true)

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
    obj.OverlayToggle = ICphotoPlayerOverlayToggle
    obj.SetSlideImage = ICslideshowSetSlideImage
    obj.getSlideImage = ICslideshowGetImage
    obj.purgeSlideImages = ICPurgeLocalFiles

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
        handled = true

        if msg.isScreenClosed() then
            m.purgeSlideImages() ' cleanup the local cached images
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
                ' back: close
                m.Stop()
            else if msg.GetIndex() = 2 or msg.GetIndex() = 3 then 
                ' down/up : toggle overlay
                m.OverlayToggle()
            else if msg.GetIndex() = 4 then 
                ' left: previous
                'm.OverlayToggle("show",invalid,"previous")
                m.prev()
            else if msg.GetIndex() = 5 then 
                ' right: next
                'm.OverlayToggle("show",invalid,"next")
                m.next()
            else if msg.GetIndex() = 6 then
                ' OK: pause or start (photo only)
                if m.IsPaused then 
                    m.resume()
                else 
                    m.pause()
                end if
            else if msg.GetIndex() = 13 then
                ' PlayPause: pause or start (photo/music)
                if m.IsPaused then 
                    if audioplayer().IsPaused then Audioplayer().Resume()
                    m.resume()
                else 
                    if AudioPlayer().IsPlaying then AudioPlayer().Pause()
                    m.pause()
                end if
            else if msg.GetIndex() = 10 then
                ' * : dialog -- we should make this an imageCanvas now too ( it's prettier )
                if type(m.context) = "roArray" and m.CurIndex <> invalid then obj = m.context[m.CurIndex]
                m.forceResume = NOT(m.isPaused)
                m.Pause()
                photoPlayerShowContextMenu(obj)
            end if

        end if
    end if

    return handled
End Function

sub ICphotoPlayerOverlayToggle(force=invalid,headerText=invalid,overlayText=invalid)

        if force <> invalid 
            if tostr(force) = "hide" then 
                m.OverlayOn = true
            else if tostr(force) = "show" then 
                m.OverlayOn = false
            end if
        else
            m.OverlayOn = (m.OverlayOn = true)
        end if

        if m.OverlayOn then 
            print "---------- remove overlay"
            m.screen.clearlayer(2)      
            m.OverlayOn = false
        else 
            print "---------- show overlay"
            item = m.context[m.curindex]                
            canvasRect = m.screen.GetCanvasRect()
            y = int(canvasrect.h*.80)

            if overlayText = invalid then 
                overlayText = item.title + "             " + item.textoverlayul + "              " + tostr(m.curindex+1) + " of " + tostr(m.PhotoCount)
            end if

            if headerText <> invalid then 
                overlayText = tostr(headerText) + chr(10)+chr(10) + overlayText
                y = int(canvasrect.h*.75)                    
            else if m.IsPaused = true then 
                overlayText = "Paused" + chr(10)+chr(10) + overlayText
                y = int(canvasrect.h*.75)                    
            end if

            display=[
                { color: "#A0000000", TargetRect:{x:0,y:y,w:canvasrect.w,h:0} }
                {
                    Text: overlayText
                    TextAttrs:{Color:"#FFCCCCCC", Font:"Medium",
                    HAlign:"HCenter", VAlign:"VCenter",
                    Direction:"LeftToRight"}
                    TargetRect:{x:0,y:y,w:canvasrect.w,h:0}
                }
            ]
            m.screen.setlayer(2,display)      
            m.OverlayOn = true
            m.Timer.Mark()
            'sleep(500)
        end if

end sub

sub ICphotoPlayerOnTimerExpired(timer)
    if timer.Name = "slideshow" then
        m.Next()
    end if
End Sub

sub ICslideshowSetSlideImage()
    m.GetSlideImage()
    display=[{url:m.CurFile.localFilePath, targetrect:{x:0,y:0,w:m.CurFile.size.width,h:m.CurFile.size.height}}]
    m.screen.setlayer(1,display)      
end sub

sub ICphotoPlayerNext()
    'print "-- next"
    if m.nextindex <> invalid then 
        i = m.nextindex
    else 
        i = m.curindex
    end if
    if i > m.context.count()-1 then i=0  
    m.curindex = i

    m.SetSlideImage()
    'display=[{url:m.context[i].url, targetrect:{x:0,y:0,w:1280,h:720}}]

    NowPlayingManager().location = "fullScreenPhoto"
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)

    m.OverlayToggle("hide")
    m.nextindex = m.curindex+1
    m.Timer.Mark()
    GetViewController().ResetIdleTimer()
end sub

sub ICphotoPlayerPrev()
    'print "-- Previous"
    i=m.curindex-1
    if i < 0 then i = m.context.count()-1
    m.curindex=i

    m.SetSlideImage()

    NowPlayingManager().location = "fullScreenPhoto"
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)

    m.OverlayToggle("hide")
    m.nextindex = m.curindex+1
    m.Timer.Mark()
    GetViewController().ResetIdleTimer()
end sub

sub ICphotoPlayerPause()
   m.IsPaused = true
   m.Timer.Active = false
   m.OverlayToggle("show")
   NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "paused", 0)
end sub

sub ICphotoPlayerResume()
   m.IsPaused = false
   m.Timer.Active = true
   m.OverlayToggle("show","Resumed")
   NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)
end sub

sub ICphotoPlayerStop()
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

sub ICslideshowGetImage(async=false)
    item = m.context[m.curindex]
 
    ' location/name of the cached file ( to read or to save )
    localFilePath = "tmp:/" + item.ratingKey + "_" + item.title + ".jpg"

    print "-- cached files: " + tostr(m.LocalFiles.count())
    print "   bytes: " + tostr(m.LocalFileSize)
    print "      MB: " + tostr(int(m.LocalFileSize/1048576))

    ' Purge the local cache if we have more than X images or 10MB used on disk 
    if m.LocalFiles.count() > 500 or (m.LocalFileSize/1048576) > 10 then m.purgeSlideImages()

    ' return the cached image ( if we have one )
    if m.LocalFiles.count() > 0 then 
        for each local in m.LocalFiles 
            if local.localFilePath = localFilePath then 
                print "cached file: " + localFilePath + " already cached!"
                m.CurFile = local ' set it and return
                return 
            end if 
        end for
    end if

    ' cache the image on disk
    req = NewHttp(item.url)
    if async then 
        ' not tested or used ( don't really see a point for this yet )
        req.http.AsyncGetToFile(localFilePath)
    else 
        req.http.GetToFile(localFilePath)
        content = {}

        ' get image metadata (width/height)
        meta = CreateObject("roImageMetadata")
        meta.SetUrl(localFilePath)

        ' get/set image size on disk
        ba=CreateObject("roByteArray")
        ba.ReadFile(localFilePath)
        numBytes = ba.Count()
        m.LocalFileSize = int(m.LocalFileSize+numBytes)

        ' set local cache info
        content.size = meta.GetMetadata()

        ' verify the height is 720 ( scale to resize )
        if content.size.height < 720  then 
            mp = 720/content.size.height
            content.size.width = int(mp*content.size.width)
            content.size.height = 720
        end if

        ' after height scale - veriy the width is < 1280 
        if content.size.width > 1280 then 
            mp = 1280/content.size.width
            content.size.height = int(mp*content.size.height)
            content.size.width = 1280
        end if

        content.localFilePath = localFilePath

        ' container to know what files we have created       
        m.LocalFiles.Push(content)

        ' current image to display
        m.CurFile = content
    end if
end sub

sub ICPurgeLocalFiles() 
    ' cleanup our mess -- purge any files we have created during the slideshow
    if m.LocalFiles.count() > 0 then 
        print "Purging Local Cache -- Total Files:" + tostr(m.LocalFiles.count())
        for each local in m.LocalFiles 
            print "    delete cached file: " + local.localFilePath
            deletefile(local.localFilePath)
        end for
        m.LocalFiles = []   ' container now empty
        m.LocalFileSize = 0 ' total size used now 0
        print "    Done. Total Files left:" + tostr(m.LocalFiles.count())
    end if
end sub