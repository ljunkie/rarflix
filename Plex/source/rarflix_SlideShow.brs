' Current TASK: 
'
' TODO:
' * verify shuffle works

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


Function createICphotoPlayerScreen(context, contextIndex, viewController, shuffled=false, slideShow=true)
    Debug("creating ImageCanvas Photo Player at index" + tostr(contextIndex))
    Debug("    Shuffled: " + tostr(Shuffled))
    Debug("   SlideShow: " + tostr(slideShow))

    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.OnTimerExpired = ICphotoPlayerOnTimerExpired
    obj.OnUrlEvent = photoSlideShowOnUrlEvent

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

    obj.LocalFiles = []
    obj.LocalFileSize = 0

    obj.playbackTimer = createTimer()
    AudioPlayer().focusedbutton = 0
    obj.HandleMessage = ICphotoPlayerHandleMessage

    NowPlayingManager().SetControllable("photo", "skipPrevious", obj.Context.Count() > 1)
    NowPlayingManager().SetControllable("photo", "skipNext", obj.Context.Count() > 1)

    screen = createobject("roimagecanvas")

    obj.UnderScan = 5 ' percent of understan (2.5 with the slideShow -- but 5% seems right for this)
    obj.canvasrect = screen.GetCanvasRect()

    screen.SetRequireAllImagesToDraw(true)

    theme = getImageCanvasTheme()
    screen.SetLayer(0, theme["background"])
    screen.SetMessagePort(obj.Port)
    obj.Screen = screen

    obj.overlayEnabled = (RegRead("slideshow_overlay", "preferences", "2500").toInt() <> 0)

    obj.Activate = ICphotoPlayerActivate

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

    obj.IsShuffled = shuffled
    obj.SetShuffle = ICphotoPlayerSetShuffle
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
            else if msg.GetIndex() = 2 or msg.GetIndex() = 3 then 
                ' down/up : toggle overlay
                ' - if someone manually toggles the overlay -- remember state for this slideshow (overlayEnabled) 
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
                m.forceResume = NOT(m.isPaused)
                m.Pause()
                m.ShowContextMenu()
            else if msg.GetIndex() = 8 then 
               ' rwd: previous track if audio is playing
               if AudioPlayer().IsPlaying then AudioPlayer().Prev()
            else if msg.GetIndex() = 9 then 
               ' fwd: next track if audio is playing
               if AudioPlayer().IsPlaying then AudioPlayer().Next()
            else if msg.GetIndex() = 7 then 
               ' InstantReplay: use to keep the slideshow from being idle ( screensaver hack )
            else 
                Debug("button pressed (not handled)" + tostr(msg.GetIndex()))
            end if

        end if
    end if

    return handled
End Function

sub ICphotoPlayerOverlayToggle(option=invalid,headerText=invalid,overlayText=invalid)
        if tostr(option) <> "forceShow" and NOT m.overlayEnabled and overlayText = invalid and headerText = invalid then 
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
            y = int(m.canvasrect.h*.80)

            'TODO: work on the fonts
            if overlayText = invalid then 
                overlayText = item.title + "             " + item.textoverlayul + "              " + tostr(m.curindex+1) + " of " + tostr(m.PhotoCount)
            end if

            if headerText <> invalid then 
                overlayText = tostr(headerText) + chr(10)+chr(10) + overlayText
                y = int(m.canvasrect.h*.75)
            else if m.IsPaused = true and m.isSlideShow then 
                ' prepend Paused to the overlay ( if this is a playing SlideShow and not just a single view )
                overlayText = "Paused" + chr(10)+chr(10) + overlayText
                y = int(m.canvasrect.h*.75)
            else if m.ImageFailure = true and m.ImageFailureReason <> invalid and m.isSlideShow then 
                ' show the EU failure info -- will help support issues if slideShows are not working as expected
                failCountText = tostr(m.ImageFailureCount)
                if m.ImageFailureCount = 1 then 
                    failCountText = failCountText + " failure"
                else 
                    failCountText = failCountText + " failures"
                end if
                overlayText = failCountText + " : " + tostr(m.ImageFailureReason) + chr(10)+chr(10) + overlayText
                y = int(m.canvasrect.h*.75)
            end if

            display=[
                { color: "#A0000000", TargetRect:{x:0,y:y,w:m.canvasrect.w,h:0} }
                {
                    Text: overlayText
                    TextAttrs:{Color:"#FFCCCCCC", Font:"Medium",
                    HAlign:"HCenter", VAlign:"VCenter",
                    Direction:"LeftToRight"}
                    TargetRect:{x:0,y:y,w:m.canvasrect.w,h:0}
                }
            ]
            m.screen.setlayer(2,display)
            m.OverlayOn = true

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
    m.screen.setlayer(1,display)

    NowPlayingManager().location = "fullScreenPhoto"
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)

    if NOT m.overlayEnabled then 
        m.OverlayToggle("hide")
    else 
        m.OverlayToggle("show")
    end if

    m.nextindex = m.curindex+1
    m.Timer.Mark()
    GetViewController().ResetIdleTimer()
    SendRemoteKey("InstantReplay") ' need to find a better fix to prevent the screenSaver
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

    if m.CurIndex < m.PhotoCount - 1 then
        m.NextIndex = m.CurIndex + 1
    else
        m.NextIndex = 0
    end if

    NowPlayingManager().timelines["photo"].attrs["shuffle"] = tostr(shuffleVal)
End Sub

function ICgetSlideImage()
    item = m.context[m.curindex]
 
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
end sub

sub ICphotoPlayerActivate(priorScreen) 
    ' pretty basic for now -- we will resume the slide show if paused and forcResume is set
    '  note: forceResume is set if slideshow was playing while EU hits the * button ( when we come back, we need/should to resume )
    if m.isPaused and m.ForceResume then m.Resume()
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
Sub photoShowContextMenu(obj = invalid,force_show = false)
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

    container = createPlexContainerForUrl(obj.server, obj.server.serverUrl, obj.key)
    if container <> invalid then
        container.getmetadata()
        ' only create dialog if metadata is available
        if type(container.metadata) = "roArray" and type(container.metadata[0].media) = "roArray" then 
            obj.MediaInfo = container.metadata[0].media[0]
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
    end if

End Sub

sub ICreloadSlideContext()
    expireSec = 300 ' only reload every 5 minutes
    if RegRead("slideshow_reload", "preferences", "disabled") <> "disabled" then 
        if m.lastreload <> invalid and getEpoch()-m.lastReload < expireSec then 
            Debug("---- Skipping Reload " + tostr(getEpoch()-m.lastReload) + " seconds < expire seconds " + tostr(expireSec))
        else 
            Debug("---- trying to Reload SlideShow context")
            m.lastReload = getEpoch()
            if m.item <> invalid and m.item.server <> invalid and m.item.sourceurl <> invalid then 
                obj = createPlexContainerForUrl(m.item.server, "", m.item.sourceurl) ' sourceurl for key arg -- will use the unadulterated url
                newCount = obj.count():curCount = m.context.count()
                Debug("    Cur Items: " + tostr(curCount)):Debug("    New Items: " + tostr(newCount))
                if newCount > 0 and newCount <> curCount then 
                    cleanContext = ICphotoPlayerCleanContext(obj.getmetadata(),0)
                    cleanCount = cleanContext.context.count()
                    Debug("    New (cleaned) Items: " + tostr(cleanCount))
                    if cleanCount > 0 and cleanCount <> curCount then 
                        m.context = cleanContext.context
                        m.PhotoCount = cleanCount
                        Debug("---- reloading slideshow with new context " + tostr(m.PhotoCount) + " items")
                    else 
                       Debug("---- slideshow content reload (no new items)")                            
                    end if
                else 
                    Debug("---- slideshow content reload (no new items)")
                end if
            end if
        end if
    end if
end sub
