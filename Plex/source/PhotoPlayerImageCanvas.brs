' Current TASK: 
'
' TODO: 
' * change dialogs to image canvas overlay
' * possible to show music info in overlay -- or another overlay?
'

' DONE: needs more work
' * prevent screenSaver ( kinda done in a hacky way -- sending the InstandReplay key )

' DONE:
' * Photo Display mode -- seems like it's cropping 
'    X -- cropping fixed 
'    X -- cached images 
'    X -- purge cache when needed ( to much or close the screen )
'    X -- center the image ( since we no longer "stretch/crop" )
'    X -- timer to hide overlay
'    X -- keeps state when EU toggles overlay with remove (up/down) 
'    X -- verify remote control works ( fun stuff )
'    X -- reload slideshow ( after completion )
'    X -- verify shuffle works


Function createICphotoPlayerScreen(context, contextIndex, viewController, shuffled=false, slideShow=true)
    Debug("creating ImageCanvas Photo Player at index" + tostr(contextIndex))
    Debug("    Shuffled: " + tostr(Shuffled))
    Debug("   SlideShow: " + tostr(slideShow))

    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    di=createobject("rodeviceinfo")
    if mid(di.getversion(),3,1).toint() > 3 then 
        obj.isLegacy = false
    else
        obj.isLegacy = true
    end if

    obj.OnTimerExpired = ICphotoPlayerOnTimerExpired
    obj.OnUrlEvent = photoSlideShowOnUrlEvent
    obj.nonIdle = ICnonIdle

    ' ljunkie - we need to iterate through the items and remove directories -- they don't play nice
    ' note: if we remove directories ( itms ) the contextIndex will be wrong - so fix it!
    cleanContext = ICphotoPlayerCleanContext(context,contextIndex)
    context = cleanContext.context
    contextIndex = cleanContext.contextIndex
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
    obj.IsPaused = NOT(slideshow)
    obj.ForceResume = false
    obj.OverlayOn = false

    obj.LocalFiles = []
    obj.LocalFileSize = 0

    obj.playbackTimer = createTimer()
    obj.idleTimer = createTimer()

    AudioPlayer().focusedbutton = 0
    obj.HandleMessage = ICphotoPlayerHandleMessage

    NowPlayingManager().SetControllable("photo", "skipPrevious", obj.Context.Count() > 1)
    NowPlayingManager().SetControllable("photo", "skipNext", obj.Context.Count() > 1)

    screen = createobject("roimagecanvas")

    ' percent of understan (2.5 with the slideShow -- but 5% seems right for this)
    obj.UnderScan = RegRead("slideshow_underscan", "preferences", "5").toInt() 
    obj.canvasrect = screen.GetCanvasRect()

    screen.SetRequireAllImagesToDraw(false)

    obj.theme = getImageCanvasTheme()
    screen.SetLayer(0, obj.theme["background"])
    screen.SetMessagePort(obj.Port)
    obj.Screen = screen

    obj.overlayEnabled = (RegRead("slideshow_overlay", "preferences", "2500").toInt() <> 0)

    obj.Activate = ICphotoPlayerActivate

    obj.StopKeepState = ICphotoStopKeepState

    obj.Pause = ICphotoPlayerPause
    obj.Resume = ICphotoPlayerResume
    obj.Next = ICphotoPlayerNext
    obj.Prev = ICphotoPlayerPrev
    obj.Stop = ICphotoPlayerStop
    obj.OverlayToggle = ICphotoPlayerOverlayToggle

    obj.reloadSlideContext = ICreloadSlideContext
    obj.ShowSlideImage = ICshowSlideImage
    obj.getSlideImage = ICgetSlideImage
    obj.purgeSlideImages = ICPurgeLocalFiles
    obj.setImageFailureInfo = ICsetImageFailureInfo
    obj.showContextMenu = photoShowContextMenu
    obj.setImageFailureInfo()

    obj.SetShuffle = ICphotoPlayerSetShuffle
    obj.IsShuffled = shuffled
    if shuffled then
        NowPlayingManager().timelines["photo"].attrs["shuffle"] = "1"
    else
        NowPlayingManager().timelines["photo"].attrs["shuffle"] = "0"
    end if

    ' slideshow timer
    if obj.Timer = invalid then
        time = RegRead("slideshow_period", "preferences", "6").toInt()
        obj.Timer = createTimer()
        obj.Timer.Name = "slideshow"
        obj.Timer.SetDuration(time*1000, true)
        obj.Timer.Active = false
        GetViewController().AddTimer(obj.Timer, obj)
    end if

    ' overlay timer ( used if if disabled -- one can toggle the overlay )
    if obj.TimerOverlay = invalid then
        time = RegRead("slideshow_overlay", "preferences", "2500").toInt()
        if time = 0 then time = 2500
        obj.TimerOverlay = createTimer()
        obj.TimerOverlay.Name = "overlay"
        obj.TimerOverlay.SetDuration(time, true)
        obj.TimerOverlay.Active = false
        GetViewController().AddTimer(obj.TimerOverlay, obj)
    end if

    return obj

End Function

Function photoContextMenuHandleButton(command, data) As Boolean
    handled = false
    obj = m.ParentScreen

    if command = "shufflePhoto" then
        m.parentScreen.SetShuffle(1)
    else if command = "UnshufflePhoto" then
        m.parentScreen.SetShuffle(0)
    end if

    ' For now, close the dialog after any button press instead of trying to
    ' refresh the buttons based on the new state.
    return true
end function


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
            ' 7: InstatReplay:: 

            if msg.GetIndex() = 0 then 
                ' back: close
                m.Stop()
            else if msg.GetIndex() = 2 then
                ' down/up : toggle overlay
                ' - if someone manually toggles the overlay -- remember state for this slideshow (overlayEnabled) 
                ' - Legacy devices require the up button to exit the screen (no back button)
                ' UPDATE: some people use old remotes.. no back button, so we will have to close on up
                m.Stop()
            else if msg.GetIndex() = 3 then 
                m.overlayEnabled = not(m.OverlayOn)
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
                di=createobject("rodeviceinfo")
                if NOT m.isLegacy then 
                    ' OK: pause or start (photo only)
                    if m.IsPaused then 
                        m.resume()
                    else 
                        m.pause()
                    end if
                 else 
                    ' pretend this is the info key for legacy devices (they don't have an * key)
                    ' show context menu
                    m.forceResume = NOT(m.isPaused)
                    m.Pause()
                    m.ShowContextMenu()
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
                m.forceResume = NOT(m.isPaused)
                m.Pause()
                m.ShowContextMenu()
            else if msg.GetIndex() = 8 then 
               ' rwd: previous track if audio is playing
               if AudioPlayer().IsPlaying then AudioPlayer().Prev()
            else if msg.GetIndex() = 9 then 
               ' fwd: next track if audio is playing
               if AudioPlayer().IsPlaying then AudioPlayer().Next()
            else if msg.GetIndex() = 120 then 
               return handled
               ' keyboard press(x): used to keep the slideshow from being idle ( screensaver hack )
            else 
                Debug("button pressed (not handled) code:" + tostr(msg.GetIndex()))
            end if

            m.nonIdle(true) ' reset the idle Time -- no need to send key

        end if
    end if

    return handled
End Function

sub ICphotoPlayerOverlayToggle(option=invalid,headerText=invalid,overlayText=invalid)
        if tostr(option) <> "forceShow" and NOT m.overlayEnabled and overlayText = invalid and headerText = invalid then 
            'print "overlay not enabled -- hiding it"
            m.screen.clearlayer(2)
            m.OverlayOn = false
            m.TimerOverlay.Active = false
            return
        end if

        if option <> invalid 
            if tostr(option) = "hide" then 
                m.OverlayOn = true
            else 
                m.OverlayOn = false
            end if
        else
            m.OverlayOn = (m.OverlayOn = true)
        end if

        if m.OverlayOn then 
            'print "---------- remove overlay"
            m.screen.clearlayer(2)
            m.OverlayOn = false
            m.TimerOverlay.Active = false
        else 
            'print "---------- show overlay"
            item = m.context[m.curindex]

            overlayPaddingTop = 15 ' works for both SD/HD
            if GetGlobal("IsHD") = true then
                overlayY = int(m.canvasrect.h*.85)
                overlayPaddingLR = 250
                failureHeight = int(m.canvasrect.h*.10)
            else 
                overlayY = int(m.canvasrect.h*.80)
                overlayPaddingLR = 150
                failureHeight = int(m.canvasrect.h*.15)
            end if

            overlayTopRight = tostr(m.curindex+1) + " of " + tostr(m.PhotoCount)
            overlayTopLeft = item.TextOverlayUL
            overlayCenter = item.title
            overlayErrorBG = "#70FF0000"
            overlayErrorText = "#FFFFFFFF"
            overlayBG = "#90000000"
            overlayText = "#FFCCCCCC"

            display = [ 
                { color: overlayBG, TargetRect:{x:0,y:overlayY,w:m.canvasrect.w,h:0} },
                {Text: overlayTopLeft, TextAttrs:{Color:overlayText, Font:"Small", HAlign:"Left", VAlign:"Top",  Direction:"LeftToRight"}, TargetRect:{x:overlayPaddingLR,y:overlayY+overlayPaddingTop,w:m.canvasrect.w,h:0} }, 
                {Text: overlayTopRight, TextAttrs:{Color:overlayText, Font:"Small", HAlign:"Right", VAlign:"Top",  Direction:"LeftToRight"}, TargetRect:{x:int(overlayPaddingLR*-1),y:overlayY+overlayPaddingTop,w:m.canvasrect.w,h:0} }, 
                {Text: overlayCenter, TextAttrs:{Color:overlayText, Font:"Small", HAlign:"HCenter", VAlign:"VCenter",  Direction:"LeftToRight"}, TargetRect:{x:0,y:overlayY,w:m.canvasrect.w,h:0} }]
            
            ' if Paused or HeaderText sent, include it in the bottom overlay Top Middle
            if (m.IsPaused = true and m.isSlideShow) or headerText <> invalid then 
                if headerText <> invalid then 
                    overlayHeader = tostr(headerText)
                else 
                    overlayHeader = "Paused"
                end if
                display.Push( {Text: overlayHeader, TextAttrs:{Color:overlayText, Font:"Small", HAlign:"HCenter", VAlign:"Top",  Direction:"LeftToRight"}, TargetRect:{x:0,y:overlayY+overlayPaddingTop,w:m.canvasrect.w,h:0} } )
            end if

            ' show a red overlay on the top with the last failure and count 
            if m.ImageFailure = true and m.ImageFailureReason <> invalid and m.isSlideShow then 
                ' show the EU failure info -- will help support issues if slideShows are not working as expected
                failCountText = tostr(m.ImageFailureCount)
                if m.ImageFailureCount = 1 then 
                    failCountText = failCountText + " failure"
                else 
                    failCountText = failCountText + " failures"
                end if
                overlayFail = failCountText + " : " + tostr(m.ImageFailureReason)
                display.Push({ color: OverlayErrorBG, TargetRect:{x:0,y:0,w:m.canvasrect.w,h:failureHeight}})
                display.Push({Text: overlayFail, TextAttrs:{Color:overlayErrorText, Font:"Small", HAlign:"HCenter", VAlign:"VCenter",  Direction:"LeftToRight"}, TargetRect:{x:0,y:overlayPaddingTop,w:m.canvasrect.w,h:failureHeight} })
            end if

            ' show the overlay
            m.screen.setlayer(2,display)
            m.OverlayOn = true

            ' activate and mark the slideshow & overlay timers
            m.Timer.Mark()
            m.TimerOverlay.Active = true
            m.TimerOverlay.Mark()
        end if

end sub

sub ICphotoPlayerOnTimerExpired(timer)

    if timer.Name = "slideshow" then
        if m.PhotoCount > 1 then 
            m.Next()
        end if
    end if

    if timer.Name = "overlay" then
        m.OverlayToggle("hide")
    end if

End Sub

sub ICshowSlideImage()
    if m.ImageFailure = true then m.setImageFailureInfo() ' reset any failures
    m.item = m.context[m.CurIndex]
    y = int((m.canvasrect.h-m.CurFile.metadata.height)/2)
    x = int((m.canvasrect.w-m.CurFile.metadata.width)/2)
    display=[{url:m.CurFile.localFilePath, targetrect:{x:x,y:y,w:m.CurFile.metadata.width,h:m.CurFile.metadata.height}}]
    m.screen.AllowUpdates(false)
    m.screen.Clear()

    m.screen.SetLayer(0, m.theme["background"])
    m.screen.setlayer(1,display)

    NowPlayingManager().location = "fullScreenPhoto"
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)

    ' to toggle or not to toggle..
    if m.FirstSlide = invalid then 
        m.FirstSlide = true
    else 
        m.FirstSlide = false
    end if

    if NOT m.overlayEnabled then 
        m.OverlayToggle("hide")
    else if m.isSlideShow or NOT m.FirstSlide then
        m.OverlayToggle("show")
    end if

    m.screen.show()
    m.screen.AllowUpdates(true)
    m.nextindex = m.curindex+1
    m.Timer.Mark()
    GetViewController().ResetIdleTimer() ' lockscreen
    m.nonIdle() ' inhibit screensaver
end sub

sub ICnonIdle(reset=false)
   ' we don't know what the user has set the screen saver idle time too
   ' we do know 5 minutes is the lowest setting, so set this number lower
   ' than 300 ( perferably no higher than 240 to be safe )
    maxIdle = 240
    if reset then 
        Debug("idle time reset (forced)")
        m.idleTimer.mark()
    else if m.idleTimer.GetElapsedSeconds() > maxIdle then 
        Debug("idle time reset (popped)")
        m.idleTimer.mark()
        SendRemoteKey("Lit_x") ' sending keyboard command (x) -- stop idle
    end if
    Debug("IDLE TIME " + tostr(m.idleTimer.GetElapsedSeconds()))
end sub

sub ICphotoPlayerNext()
    if m.PhotoCount = 1 then return 
    'print "-- next"
    if m.nextindex <> invalid then 
        i = m.nextindex
    else 
        i = m.curindex
    end if

    ' we are at the end -- reset index and reload context ( if enabled in prefs )
    if i > m.context.count()-1 then 
        i=0:m.reloadSlideContext()
    end if

    m.curindex = i

    m.GetSlideImage()

end sub

sub ICphotoPlayerPrev()
    if m.PhotoCount = 1 then return 
    'print "-- Previous"
    i=m.curindex-1
    if i < 0 then i = m.context.count()-1
    m.curindex=i

    m.GetSlideImage()
end sub

sub ICphotoPlayerPause()
    if m.PhotoCount = 1 then return 
    m.IsPaused = true
    m.Timer.Active = false
    m.OverlayToggle("show","Paused")
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "paused", 0)
end sub

sub ICphotoPlayerResume()
    if m.PhotoCount = 1 then return 
    m.IsPaused = false
    m.isSlideShow = true ' EU can start a slideshow from a single show ( if PhotoCount > 1 )
    m.Timer.Active = true
    m.OverlayToggle("show","Resumed")
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)
end sub

sub ICphotoPlayerStop()
    m.Screen.Close()
end sub

Sub ICphotoPlayerSetShuffle(shuffleVal)
    if m.PhotoCount = 1 then return 
    newVal = (shuffleVal = 1)
    if newVal = m.IsShuffled then return

    m.IsShuffled = newVal
    if m.IsShuffled then
        Debug("shuffle context")
        m.CurIndex = ShuffleArray(m.Context, m.CurIndex)
        NowPlayingManager().timelines["photo"].attrs["shuffle"] = "1"
    else
        Debug("Un-shuffle context")
        m.CurIndex = UnshuffleArray(m.Context, m.CurIndex)
        NowPlayingManager().timelines["photo"].attrs["shuffle"] = "0"
    end if

    ' next photo = currentIndex+1, unless this is a start or end of the slideshow
    if m.NextIndex <> invalid and m.CurIndex < m.PhotoCount - 1 then
        m.NextIndex = m.CurIndex + 1
    else
        m.NextIndex = 0 ' End or Start of slideShow
    end if

    NowPlayingManager().timelines["photo"].attrs["shuffle"] = tostr(shuffleVal)
End Sub

function ICgetSlideImage()
    item = m.context[m.curindex]

    if item.url = invalid then  
        container = createPlexContainerForUrl(item.server, invalid, item.key)
        if container <> invalid then 
            item = container.getmetadata()[0]
            if item <> invalid then 
                ' anything we need to set before we reset the item
                ' * OrigIndex might exist if shuffled
                if m.context[m.curindex].OrigIndex <> invalid then item.OrigIndex = m.context[m.curindex].OrigIndex
                m.context[m.curindex] = item
            end if
        end if
    end if

    ' location/name of the cached file ( to read or to save )
    localFilePath = "tmp:/" + item.ratingKey + "_" + item.title + ".jpg"

    Debug("-- cached files: " + tostr(m.LocalFiles.count()))
    Debug("   bytes: " + tostr(m.LocalFileSize))
    Debug("      MB: " + tostr(int(m.LocalFileSize/1048576)))

    ' Purge the local cache if we have more than X images or 10MB used on disk 
    if m.LocalFiles.count() > 500 or (m.LocalFileSize/1048576) > 10 then m.purgeSlideImages()

    ' return the cached image ( if we have one )
    if m.LocalFiles.count() > 0 then 
        for each local in m.LocalFiles 
            if local.localFilePath = localFilePath then 
                Debug("using cached file: " + tostr(localFilePath))
                m.CurFile = local ' set it and return
                m.ShowSlideImage()
                return true
                'return true ' do not wait for urlEvent -- it's cached!
            end if 
        end for
    end if

    ' cache the image on disk
    request = CreateObject("roUrlTransfer")
    request.EnableEncodings(true)
    request.SetUrl(item.url)
    context = CreateObject("roAssociativeArray")
    context.requestType = "slideshow"
    context.localFilePath = localFilePath
    Debug("Get Slide Show Image" + item.url + " save to " + localFilePath)
    GetViewController().StartRequest(request, m, context, invalid, localFilePath)
    return false ' false means we wait for response
end function

sub ICPurgeLocalFiles() 
    ' cleanup our mess -- purge any files we have created during the slideshow
    if m.LocalFiles.count() > 0 then 
        Debug("Purging Local Cache -- Total Files:" + tostr(m.LocalFiles.count()))
        for each local in m.LocalFiles 
            Debug("    delete cached file: " + tostr(local.localFilePath))
            deletefile(local.localFilePath)
        end for
        m.LocalFiles = []   ' container now empty
        m.LocalFileSize = 0 ' total size used now 0
        Debug("    Done. Total Files left:" + tostr(m.LocalFiles.count()))
    else 
        Debug("Purge files called -- no files to purge")
    end if
    Debug("Running Garbage Collector")
    RunGarbageCollector()
end sub

sub ICphotoPlayerActivate(priorScreen) 
    ' pretty basic for now -- we will resume the slide show if paused and forcResume is set
    '  note: forceResume is set if slideshow was playing while EU hits the * button ( when we come back, we need/should to resume )
    m.nonIdle(true)
    if m.isPaused and m.ForceResume then 
        m.Resume():m.ForceResume = false
        if AudioPlayer().forceResume = true then 
            ' either starts at the resumeOffset or beginning of track
            AudioPlayer().Play():AudioPlayer().forceResume = false
        end if
    end if
end sub

Function PhotoPlayer()
    ' If the active screen is a slideshow, return it. Otherwise, invalid.
    screen = GetViewController().screens.Peek()
    if type(screen.Screen) = "roSlideShow" then ' to deprecate roSlideShow!
        return screen
    else if type(screen.screen) = "roImageCanvas" and tostr(screen.imagecanvasname) = "slideshow" then
        return screen
    else
        return invalid
    end if
End Function

function ICphotoPlayerCleanContext(context,contextIndex)
    ' should attache this function to the 
    cleaned = {}
    cleaned.context = context
    cleaned.contextIndex = contextIndex
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
                    cleaned.contextIndex = index
                    exit for
                end if
            end for
        end if
        cleaned.context = newcontext
    end if

    return cleaned

end function

Sub photoSlideShowOnUrlEvent(msg, requestContext)

 if msg.GetResponseCode() = 200 then 
        headers = msg.GetResponseHeaders()
        obj = CreateObject("roAssociativeArray")

        obj.localFilePath = requestContext.localFilePath

        ' get image metadata (width/height)
        ImageMeta = CreateObject("roImageMetadata")
        ImageMeta.SetUrl(obj.localFilePath)
        obj.metadata = ImageMeta.GetMetadata()

        ' verify we have a valid image -- show over and return if invalid
        if obj.metadata.width = 0 or obj.metadata.height = 0 then 
            Debug("Failed to write image -- consider purging local cache (maybe full?)")
            m.setImageFailureInfo("failed to save image")
            ' show the failure on the 1st and every 5th try ( mainly we want to show this on the 1st try if it's the initial start )
            showFailureInfo = m.ImageFailureCount/5
            if int(showFailureInfo) = showFailureInfo or m.ImageFailureCount = 1 then m.OverlayToggle("forceShow")
            m.purgeSlideImages() ' cleanup the local cached images
            return
        end if

        ' get size of image from headers -- fall back to reading from tmp
        numBytes = 0
        if headers["Content-Length"] <> invalid then
            numBytes = headers["Content-Length"].toInt()
            Debug("Header Response - bytes:" + tostr(numbytes))
        else 
            ba=CreateObject("roByteArray")
            ba.ReadFile(obj.localFilePath)
            numBytes = ba.Count()
            Debug("Fall back to reading localfile for size - bytes" + tostr(numbytes))
        end if

        m.LocalFileSize = int(m.LocalFileSize+numBytes) ' we will fall back to image count if we fail to get bytes for cleanup

        ' verify the height = canvas height ( scale to resize ) -- works for HD/SD
        if obj.metadata.height < m.canvasrect.h then 
            mp = m.canvasrect.h/obj.metadata.height
            obj.metadata.width = int(mp*obj.metadata.width)
            obj.metadata.height = m.canvasrect.h
        end if

        ' after height scale - veriy the width is < canvas width
        if obj.metadata.width > m.canvasrect.w then 
            mp = m.canvasrect.w/obj.metadata.width
            obj.metadata.height = int(mp*obj.metadata.height)
            obj.metadata.width = m.canvasrect.w
        end if

        ' set UnderScan -- TODO(ljunkie) verify this is right fow other TV's
        obj.metadata.height = int(obj.metadata.height*((100-m.UnderScan)/100))
        obj.metadata.width = int(obj.metadata.width*((100-m.UnderScan)/100))

        ' container to know what file(s) we have created to purge later
        m.LocalFiles.Push(obj)

        ' current image to display
        m.CurFile = obj

        m.ShowSlideImage()
    else 
        ' urlEventFailure - nothing to see here
        failureReason = msg.GetFailureReason()
        url = tostr(requestContext.Request.GetUrl())
        Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + url + " - " + tostr(failureReason))
        m.setImageFailureInfo(failureReason)
    end if

End Sub

' overlay info -- so EU can know what's happening if the slideShow isn't working
sub ICsetImageFailureInfo(failureReason=invalid)
    if failureReason <> invalid then 
        m.ImageFailure = true
        m.ImageFailureReason = failureReason
        m.ImageFailureCount = int(m.ImageFailureCount+1)
        Debug("    fail Count: " + tostr(m.ImageFailureCount))
        ' only show the failure on every 5th try ( it's ok if it fails once in a while without someone noticing )
        showFailureInfo = m.ImageFailureCount/5
        if int(showFailureInfo) = showFailureInfo then m.OverlayToggle("show")
    else 
        ' reset any image failures
        m.ImageFailure = false
        m.ImageFailureReason = invalid
        m.ImageFailureCount = 0
    end if
end sub

' this can be called independently while passing the object 
sub photoShowContextMenu(obj = invalid,force_show = false, forceExif = false)
    if obj <> invalid then
        Debug("context menu using passed object")
    else if type(m.context) = "roArray" and m.CurIndex <> invalid then 
        obj = m.context[m.CurIndex]
    end if

    if obj = invalid then return

    ' this also works for the existing Photo Player
    player = AudioPlayer()

    ' show audio dialog if item is directory and audio is playing/paused
    if tostr(obj.nodename) = "Directory" then
        if player.IsPlaying or player.IsPaused or player.ContextScreenID <> invalid then player.ShowContextMenu()
        return
    end if
   
    ' do not display if audio is playing - sorry, audio dialog overrides this, maybe work more logic in later
    ' I.E. show button for this dialog from audioplayer dialog
    if NOT force_show and player.IsPlaying or player.IsPaused or player.ContextScreenID <> invalid then 
        player.ShowContextMenu()
        return
    end if

    getExifData(obj,false,true)

    ' TODO(ljunkie) it's ugly! -- convert this to an image canvas 
    if obj.MediaInfo <> invalid then 
        dialog = createBaseDialog()
        dialog.Title = "Image: " + obj.title
        dialog.text = ""
        ' NOTHING lines up in a dialog.. lovely        
        if obj.mediainfo.make <> invalid then dialog.text = dialog.text                  + "    camera: " + tostr(obj.mediainfo.make) + chr(10)
        if obj.mediainfo.model <> invalid then dialog.text = dialog.text                 + "      model: " + tostr(obj.mediainfo.model) + chr(10)
        if obj.mediainfo.lens <> invalid then dialog.text = dialog.text                  + "          lens: " + tostr(obj.mediainfo.lens) + chr(10)
        if obj.mediainfo.aperture <> invalid then dialog.text = dialog.text              + "  aperture: " + tostr(obj.mediainfo.aperture) + chr(10)
        if obj.mediainfo.exposure <> invalid then dialog.text = dialog.text              + " exposure: " + tostr(obj.mediainfo.exposure) + chr(10)
        if obj.mediainfo.iso <> invalid then dialog.text = dialog.text                   + "             iso: " + tostr(obj.mediainfo.iso) + chr(10)
        if obj.mediainfo.width <> invalid and obj.mediainfo.height <> invalid then dialog.text = dialog.text + "           size: " + tostr(obj.mediainfo.width) + " x " + tostr(obj.mediainfo.height) + chr(10)
        if obj.mediainfo.aspectratio <> invalid then dialog.text = dialog.text           + "      aspect: " + tostr(obj.mediainfo.aspectratio) + chr(10)
        if obj.mediainfo.container <> invalid then dialog.text = dialog.text             + "          type: " + tostr(obj.mediainfo.container) + chr(10)
        if obj.mediainfo.originallyAvailableAt <> invalid then dialog.text = dialog.text + "          date: "  + tostr(obj.mediainfo.originallyAvailableAt) + chr(10)
        
        
        if GetViewController().IsSlideShowPlaying() then
            if m.isShuffled then 
                dialog.SetButton("UnshufflePhoto", "Unshuffle Photos")
            else 
                dialog.SetButton("shufflePhoto", "Shuffle Photos")
            end if
        end if

        dialog.SetButton("close", "Close")
        dialog.HandleButton = photoContextMenuHandleButton
        dialog.EnableOverlay = true
        dialog.ParentScreen = m
        dialog.Show()
    end if

End sub

sub ICreloadSlideContext()
    if RegRead("slideshow_reload", "preferences", "disabled") <> "disabled" then 

        expireSec = 300 ' only reload every 5 minutes max ( stops delay from clicking back/forth between last and 1st image )
        if m.lastreload <> invalid and getEpoch()-m.lastReload < expireSec then 
            Debug("Skipping Reload " + tostr(getEpoch()-m.lastReload) + " seconds < expire seconds " + tostr(expireSec))
            return
        end if

        Debug("slideshow completing loop, checking for new content")
        m.lastReload = getEpoch()
        if m.item <> invalid and m.item.server <> invalid and (m.item.sourceurl <> invalid or m.sourceReloadURL <> invalid) then 
            obj = {}:dummyItem = {}
            dummyItem.server = m.item.server
            ' we really should only be reloading from the sourceReloadURL ( m.item.sourcurl is now most likely the specific item.. no good )
            ' TODO(ljunkie) we could also speed this up by creating a container with headers to return 0 items, just size and verify 
            dummyItem.sourceUrl = firstof(m.sourceReloadURL,m.item.sourceurl)
            if dummyItem.sourceUrl = invalid then Debug("no valid url to reload"):return
            PhotoMetadataLazy(obj, dummyItem, true)

            ' set to true to test the reload function 
            ' otherwise it will only reset context if newCount <> curCount
            forceReloadTest = false 

            newCount = obj.context.count():curCount = m.context.count()
            Debug("Cur Items: " + tostr(curCount)):Debug("New Items: " + tostr(newCount))
            ' we might want to return if newCount = 1 --- if someone sets the sourceReloadURL incorrectly, we might use a direct item hit (wrong)
            if forceReloadTest or (newCount > 0 and newCount <> curCount) then 
                cleanContext = ICphotoPlayerCleanContext(obj.context,0)
                cleanCount = cleanContext.context.count()
                Debug("New (cleaned) Items: " + tostr(cleanCount)) 
                if forceReloadTest or (cleanCount > 0 and cleanCount <> curCount) then 
                    m.context = cleanContext.context
                    m.PhotoCount = cleanCount
                    Debug("reloading slideshow with new context " + tostr(m.PhotoCount) + " items")
                    if m.isShuffled then 
                        Debug("slideshow was shuffled - we need to reshuffle due to new context")
                        ShuffleArray(m.Context, m.CurIndex)
                        Debug("shuffle done")
                    end if
                    Debug("Running Garbage Collector")
                    RunGarbageCollector()
                    return
                end if
            end if
        end if

        Debug("did not reload slideshow content (no new items)")
    end if

end sub

sub ICphotoStopKeepState()
    PhotoPlayer().purgeSlideImages() ' cleanup the local cached images
    m.IsPaused = true
    m.Timer.Active = false
    m.OverlayToggle("show","Paused")
    NowPlayingManager().location = "navigation"
    NowPlayingManager().UpdatePlaybackState("photo", invalid, "stopped", 0)
end sub

' we need a quicker, more memory effecient way to load images. We don't need all the metadata as we do normally
' by default (quick) we will only set the library key and some other necessities 
' NOTE: quick=false sould really not be used.. defeats the purpose -- but nice for testing
sub GetPhotoContextFromFullGrid(obj,curindex = invalid, lazy=true) 
    Debug("----- get Photo Context from Full Grid")
    Debug("----- lazy Mode: " + tostr(lazy) )
    if NOT fromFullGrid() then Debug("NOT from a full grid.. nothing to see here"):return

    ' full context already loaded -- but we still might need to reset the CurIndex
    if obj.FullContext = true then 
       Debug("All context is already loaded! total: " + tostr(obj.context.count()))
       ' if we are still in the full grid, we will have to caculate the index again ( rows are only 5 items -- curIndex is always 0-5 )
       if obj.isFullGrid = true then obj.CurIndex = getFullGridCurIndex(obj,CurIndex,1)
       return
    end if

    if obj.metadata.sourceurl = invalid then return
    if curindex = invalid then curindex = obj.curindex

    ' strip any limits imposed by the full grid - we need it all ( not start or container size)
    r  = CreateObject("roRegex", "[?&]X-Plex-Container-Start=\d+\&X-Plex-Container-Size\=.*", "")
    sourceUrl = obj.metadata.sourceurl
    if r.IsMatch(sourceUrl) then  
        Debug("--------------------------- OLD " + tostr(sourceUrl))
        sourceUrl = r.replace(sourceUrl,"")
        Debug("--------------------------- NEW " + tostr(sourceUrl))
    end if

    ' no quickly load the required metadata (lazy)
    dummyItem = {}
    dummyItem.server = obj.metadata.server
    dummyItem.sourceUrl = sourceUrl
    PhotoMetadataLazy(obj, dummyItem, lazy)
end sub

sub PhotoMetadataLazy(obj, dummyItem, lazy = true)
    ' sourceUrl can be a fullUrl or key
    container = createPlexContainerForUrl(dummyItem.server, invalid, dummyItem.sourceUrl)
    obj.sourceReloadURL = container.sourceurl ' lazy loading .. we need this for later to reload the slideshow

    if isnonemptystr(container.xml@header) AND isnonemptystr(container.xml@message) then
        ShowErrorDialog("Sorry! We were unable to load your photos.","Warning"):return
    end if
    
    ' parse the xml into objects
    nodes = container.xml.GetChildElements()
    for each n in nodes
        nodeType = firstOf(n.GetName(), n@type, container.ViewGroup) ' n.GetName() should never fail

        if nodeType = "Photo" then
            ' only load the required data -- keep the memory footprint small
            if lazy then 
                metadata = {}
                metadata.server = dummyItem.server
                metadata.key = n@key
                metadata.nodename = "Photo"
                metadata.ContentType = "photo"
                metadata.Type = "photo"
            else 
                metadata = newPhotoMetadata(container, n)
            end if
        else if nodeType = "Directory"
            ' ljunkie -- slideShow doesn't work with directories, but other screens do
            ' for now we will just create the metadata the normal way. If someone has
            ' thousands of directories too, we might have memory issues and have to 
            ' re-work this like we do above for photos
            metadata = newDirectoryMetadata(container, n)
        end if

        ' CUSTOM thumbs? -- not for photos
        ' PosterIndicators(metadata) -- nah, watched status not implemented for photos and probably never should be shown if it is

        ' only push valid metadata - we only expect Photo and Directories
        if metadata <> invalid and metadata.key <> invalid then container.metadata.Push(metadata)
        metadata = invalid
    next

    obj.context = container.metadata
    obj.CurIndex = getFullGridCurIndex(obj,dummyItem.CurIndex,1) ' when we load the full context, we need to fix the curindex
    obj.FullContext = true

    ' cleanup
    nodes = invalid
    metadata = invalid 
    container = invalid
    RunGarbageCollector()
end sub
