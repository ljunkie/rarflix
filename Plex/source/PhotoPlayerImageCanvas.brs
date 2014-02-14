'*
'* Alpha Release of a slideshow written in an roImageCanvas
'*

Function createICphotoPlayerScreen(context, contextIndex, viewController, shuffled=false, slideShow=true)
    Debug("creating ImageCanvas Photo Player at index: " + tostr(contextIndex))
    Debug("    Shuffled: " + tostr(Shuffled))
    Debug("   SlideShow: " + tostr(slideShow))

    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)
    obj.HandleMessage = ICphotoPlayerHandleMessage
    obj.Activate = ICphotoPlayerActivate
    obj.OnTimerExpired = ICphotoPlayerOnTimerExpired
    obj.OnUrlEvent = photoSlideShowOnUrlEvent
    obj.nonIdle = ICnonIdle
    obj.Refresh = PhotoPlayerRefresh

    ' we do some thing different if one is using a legacy remote ( no back button or info(*) button )
    if RegRead("legacy_remote", "preferences","0") <> "0" then 
        obj.isLegacyRemote = true
    else 
        obj.isLegacyRemote = false
    end if

    ' ljunkie - we need to iterate through the items and remove directories -- they don't play nice
    ' note: if we remove directories (items) the contextIndex will be wrong - so fix it!
    cleanContext = ICphotoPlayerCleanContext(context,contextIndex)
    context = cleanContext.context
    contextIndex = cleanContext.contextIndex
    ' end cleaning

    if type(context) = "roArray" then
        obj.item = context[contextIndex]
        obj.CurIndex = contextIndex
        obj.context = context
    else 
        ' this actually shouldn't be possible as we always (try) pass the full context
        ' when we "show" a single image, we pass the full context so one can click
        ' fwd/rwd to move forward/back -- "show" button will pass slideShow=false
        obj.context = [context]
        obj.CurIndex = 0
    end if

    NowPlayingManager().SetControllable("photo", "skipPrevious", obj.Context.Count() > 1)
    NowPlayingManager().SetControllable("photo", "skipNext", obj.Context.Count() > 1)
   
    obj.isSlideShow = slideShow       ' if we came in through the play/slideshow vs showing a single item
    obj.ImageCanvasName = "slideshow" ' used if we need to know we are in a slideshow screen
    obj.IsPaused = NOT(slideshow)
    obj.ForceResume = false
    obj.OverlayOn = false

    ' containers used for info about the file/metadata cache
    obj.LocalFiles = []
    obj.LocalFileSize = 0
    obj.CachedMetadata = 0

    obj.playbackTimer = createTimer()
    obj.idleTimer = createTimer()

    AudioPlayer().focusedbutton = 0

    screen = createobject("roimagecanvas")
    screen.SetMessagePort(obj.Port)
    screen.SetRequireAllImagesToDraw(false)
    screen.setLayer(0, {Color:"#000000", CompositionMode:"Source"})

    obj.canvasrect = screen.GetCanvasRect()

    ' TODO(ljunkie) only show this if first image and continuing images fail. 
    ' As of now, it will flash before the first image downloads
    display = {
        Text: "loading image....", 
        TextAttrs: {
            Color:"#A0FFFFFF", 
            Font:"Small", 
            HAlign:"HCenter", 
            VAlign:"VCenter",  
            Direction:"LeftToRight"
        }, 
        TargetRect: { 
            x:0,
            y:0,
            w:int(obj.canvasrect.w),
            h:0
        } 
    }
    screen.SetLayer(1, display)
    obj.Screen = screen

    ' percent of underscan (2.5 with the slideShow -- but 5% seems right for this)
    ' toggle is available for users in slideshow prefs ( TV or Monitor )
    obj.UnderScan = RegRead("slideshow_underscan", "preferences", "5").toInt() 
    obj.overlayEnabled = (RegRead("slideshow_overlay", "preferences", "2500").toInt() <> 0)


    ' standardized actions
    obj.Pause = ICphotoPlayerPause
    obj.Resume = ICphotoPlayerResume
    obj.Next = ICphotoPlayerNext
    obj.Prev = ICphotoPlayerPrev
    obj.Stop = ICphotoPlayerStop

    obj.OverlayToggle = ICphotoPlayerOverlayToggle
    obj.StopKeepState = ICphotoStopKeepState
    obj.reloadSlideContext = ICreloadSlideContext
    obj.ShowSlideImage = ICshowSlideImage
    obj.getSlideImage = ICgetSlideImage
    obj.purgeSlideImages = ICPurgeLocalFiles
    obj.purgeMetadata = ICPurgeMetadata
    obj.setImageFailureInfo = ICsetImageFailureInfo
    obj.showContextMenu = photoShowContextMenu
    obj.setImageFailureInfo()

    ' standard shuffle options
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

    ' overlay timer
    if obj.TimerOverlay = invalid then
        time = RegRead("slideshow_overlay", "preferences", "2500").toInt()
        if time = 0 then time = 2500
        obj.TimerOverlay = createTimer()
        obj.TimerOverlay.Name = "overlay"
        obj.TimerOverlay.SetDuration(time, true)
        obj.TimerOverlay.Active = false
        GetViewController().AddTimer(obj.TimerOverlay, obj)
    end if

    ' We have had some times where the slideshow process seems to hang causing a screen saver 
    ' to kick in. One can exit the screen saver, but the slideshow never starts again. It seems
    ' more like a Roku bug because one cannot even click the HOME button or CTRL-C to exit or 
    ' crash the app. It just stays locked indefinitely until the Roku reboots! This timer will
    ' will just print a status every 30 seconds as a type of health check. 
    if obj.TimerHealth = invalid then
        time = 30*1000
        obj.TimerHealth = createTimer()
        obj.TimerHealth.Name = "HealthCheck"
        obj.TimerHealth.SetDuration(time, true)
        obj.TimerHealth.Active = true
        obj.TimerHealth.Mark()
        GetViewController().AddTimer(obj.TimerHealth, obj)
    end if

    obj.GetSlideImage() 'Get first image!

    return obj

End Function

Function photoContextMenuHandleButton(command, data) As Boolean
    handled = true
    obj = m.ParentScreen

    if command = "shuffle" then 
 
        if obj.IsShuffled then 
            obj.SetShuffle(0)
            m.SetButton(command, "Shuffle: Off")
        else 
            obj.SetShuffle(1)
            m.SetButton(command, "Shuffle: On")
        end if
     
        ' buttons swapped, refresh dialog/slideshow screens
        m.Refresh()
        obj.Refresh()

        ' keep dialog open
        handled = false
    else if command = "SectionSorting" then
        dialog = createGridSortingDialog(m,obj)
        if dialog <> invalid then dialog.Show(true)
        handled = false
    end if

    ' close the dialog 
    return handled
end function


Function ICphotoPlayerHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roImageCanvasEvent" then
        handled = true

        if msg.isScreenClosed() then
            ' cleanup the local cached images
            m.purgeSlideImages()
            m.purgeMetadata()

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
            ' 8: KeyRwd :: 
            ' 9: KeyFwd :: 
            ' 7: InstantReplay:: 

            if msg.GetIndex() = 0 then 
                ' back: close
                m.Stop()
            else if msg.GetIndex() = 2 then
                ' down/up : toggle overlay
                ' - if someone manually toggles the overlay -- remember state for this slideshow (overlayEnabled) 
                ' - Legacy devices require the up button to exit the screen (no back button)
                ' UPDATE: some people use old remotes.. no back button, so we will have to close on up
                if NOT m.isLegacyRemote then 
                    m.overlayEnabled = not(m.OverlayOn)
                    m.OverlayToggle()
                else 
                    m.Stop()
                end if
            else if msg.GetIndex() = 3 then 
                m.overlayEnabled = not(m.OverlayOn)
                m.OverlayToggle()
            else if msg.GetIndex() = 4 or msg.GetIndex() = 5 then 
                ' we do not load the Full Context to just display one image
                ' - however let us allow EU to browse full context if requested 
                if NOT m.isSlideShow and NOT m.FullContext = true then 
                    GetPhotoContextFromFullGrid(m,m.item.origindex) 
                end if 

                m.userRequest = true

                if msg.GetIndex() = 4 then 
                    ' left: previous
                    m.prev()
                else if msg.GetIndex() = 5 then 
                    ' right: next
                    m.next()
                end if
            else if msg.GetIndex() = 6 then
                ' we may do something different based on physical remote 
                if NOT m.isLegacyRemote then 
                    ' OK: pause or start (photo only)
                    if m.IsPaused then 
                        m.resume()
                    else 
                        m.pause()
                    end if
                 else 
                    ' this will be the info key for legacy remote (they don't have an * key)
                    ' show context menu
                    m.forceResume = NOT(m.isPaused)
                    m.Pause()
                    m.ShowContextMenu(invalid,false,false)
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
                m.ShowContextMenu(invalid,false,false)
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
            item = m.item ' use the item we are actually viewing ( not the curIndex as that could have failed )

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

            ' count of the image being display
            ' note: if the image failed to show, we will still be showing the previous image and overlay 
            ' info will be accurate. The count will show what we *should* be on though
            overlayTopRight = tostr(m.curindex+1) + " of " + tostr(m.context.count())
            overlayTopLeft = item.TextOverlayUL
            overlayCenter = item.title
            overlayErrorBG = "#70FF0000"
            overlayErrorText = "#FFFFFFFF"
            overlayBG = "#90000000"
            overlayText = "#FFCCCCCC"

            display = [
                { 
                    color: overlayBG, 
                    TargetRect: { x:0, y:overlayY, w:m.canvasrect.w, h:0 }
                },
                {
                    Text: overlayTopLeft, 
                    TextAttrs: {Color:overlayText, Font:"Small", HAlign:"Left", VAlign:"Top",  Direction:"LeftToRight"}, 
                    TargetRect: {x:overlayPaddingLR,y:overlayY+overlayPaddingTop,w:m.canvasrect.w,h:0} 
                }, 
                {
                    Text: overlayTopRight, 
                    TextAttrs: {Color:overlayText, Font:"Small", HAlign:"Right", VAlign:"Top",  Direction:"LeftToRight"}, 
                    TargetRect: {x:int(overlayPaddingLR*-1),y:overlayY+overlayPaddingTop,w:m.canvasrect.w,h:0} 
                }, 
                {
                    Text: overlayCenter, 
                    TextAttrs: {Color:overlayText, Font:"Small", HAlign:"HCenter", VAlign:"VCenter",  Direction:"LeftToRight"}, 
                    TargetRect: {x:0,y:overlayY,w:m.canvasrect.w,h:0} 
                }
            ]
            
            ' if Paused or HeaderText sent, include it in the bottom overlay Top Middle
            if (m.IsPaused = true and m.isSlideShow) or headerText <> invalid then 
                if headerText <> invalid then 
                    overlayHeader = tostr(headerText)
                else 
                    overlayHeader = "Paused"
                end if
                display.Push( {
                    Text: overlayHeader, 
                    TextAttrs:{Color:overlayText, Font:"Small", HAlign:"HCenter", VAlign:"Top",  Direction:"LeftToRight"}, 
                    TargetRect:{x:0,y:overlayY+overlayPaddingTop,w:m.canvasrect.w,h:0} 
                } )
            end if

            ' show a red overlay on the top with the last failure and count 
            if m.ImageFailure = true and m.ImageFailureReason <> invalid and m.isSlideShow then 
                ' show the EU failure info -- will help support issues if slideShow are not working as expected
                failCountText = tostr(m.ImageFailureCount)
                if m.ImageFailureCount = 1 then 
                    failCountText = failCountText + " failure"
                else 
                    failCountText = failCountText + " failures"
                end if
                overlayFail = failCountText + " : " + tostr(m.ImageFailureReason)
                display.Push({ 
                    color: OverlayErrorBG, 
                    TargetRect:{x:0,y:0,w:m.canvasrect.w,h:failureHeight}
                })
                display.Push({
                    Text: overlayFail, 
                    TextAttrs:{Color:overlayErrorText, Font:"Small", HAlign:"HCenter", VAlign:"VCenter",  Direction:"LeftToRight"}, 
                    TargetRect:{x:0,y:overlayPaddingTop,w:m.canvasrect.w,h:failureHeight} 
                })
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

    if timer.Name = "HealthCheck" then
        amountPlayed = m.playbackTimer.GetElapsedSeconds()
        Debug("HealthCheck:: PING! slideshow running for " + tostr(amountPlayed) + " seconds")
        Debug("HealthCheck:: idle time: " + tostr(m.idleTimer.GetElapsedSeconds()) + " seconds")

        ' Check to see if the slideshow is paused but should be active. The timer could have been deactivated 
        ' to complete a task (urlTransfer). We should cancel any pending requests as we would have reactivated
        ' when we received a completed transfer (failure or success) but somehow didn't
        if m.IsPaused = false and m.Timer.Active = false then  
            Debug("HealthCheck:: cancel any pending requests and start fresh on screenID: " + tostr(m.screenID))
            GetViewController().CancelRequests(m.ScreenID)
            Debug("HealthCheck:: Reactivate slideshow timer")
            m.Timer.Mark()
            m.Timer.Active = true
        end if

    end if

    if timer.Name = "slideshow" then
        if m.context.count() > 1 then 
            Debug("ICphotoPlayerOnTimerExpired:: slideshow popped")
            m.Next()
        end if
    end if

    if timer.Name = "overlay" then
        Debug("ICphotoPlayerOnTimerExpired:: overlay popped")
        m.OverlayToggle("hide")
    end if

End Sub

sub ICshowSlideImage()
    Debug("ICshowSlideImage:: Displaying the image now")
    if m.ImageFailure = true then m.setImageFailureInfo() ' reset any failures

    m.item = m.context[m.CurIndex]
    SaveImagesForScreenSaver(m.item, ImageSizes(m.item.ViewGroup, m.item.Type))

    y = int((m.canvasrect.h-m.CurFile.metadata.height)/2)
    x = int((m.canvasrect.w-m.CurFile.metadata.width)/2)
    m.screen.AllowUpdates(false)
    m.screen.Clear()

    m.screen.setLayer(0, {Color:"#000000", CompositionMode:"Source"})
    display=[{
        url:m.CurFile.localFilePath, 
        targetrect:{x:x,y:y,w:m.CurFile.metadata.width,h:m.CurFile.metadata.height}
    }]
    'TODO(ljunkie) -- testing purge Cached Images before setting layer
    m.screen.PurgeCachedImages()
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
    m.Timer.Mark()
    GetViewController().ResetIdleTimer() ' lockscreen
    m.nonIdle() ' inhibit screensaver
end sub

sub ICnonIdle(reset=false)
   ' NOTE: calling this will will reset the idle time inhibiting the screen saver, by 
   ' sending a remote request: keyboard request for letter x -- should be ok
   ' *DO NOT* call this unless you know the slideshow is working
   '
   ' reset=true: only used when we know user clicked a button -- causing a non-idle event
   '
   ' INFO: we don't know what the user has set the screen saver idle time too we do know 
   ' 5 minutes is the lowest setting, so set this number lower than 300, preferably no 
   ' higher than 200 to be safe
    maxIdle = 120
    if reset then 
        Debug("idle time reset (forced)")
        m.idleTimer.mark()
    else if m.idleTimer.GetElapsedSeconds() > maxIdle then 
        Debug("idle time reset (popped)")
        m.idleTimer.mark()
        SendRemoteKey("Lit_x") ' sending keyboard command (x) -- stop idle
    end if
    Debug("ICnonIdle:: idle time: " + tostr(m.idleTimer.GetElapsedSeconds()) + " seconds")
end sub

sub ICphotoPlayerNext()
    Debug("ICphotoPlayerNext:: next called")

    if m.context.count() = 1 then return 

    ' allow the user to quickly press next button
    if m.userRequest <> invalid then 
        ' cancel any pending request as we are trying to view the next image 
        Debug("ICphotoPlayerNext:: cancel any pending requests and start fresh on screenID: " + tostr(m.screenID))
        GetViewController().CancelRequests(m.ScreenID)
        m.userRequest = invalid
    end if

    Debug("ICphotoPlayerNext:: viewing:" + tostr(m.curIndex))

    ' calculate the next index to view
    if m.nextindex <> invalid then 
        i = m.nextindex
    else 
        i = m.curindex+1
        m.nextindex = i
    end if

    ' reset index to 0 if we are at the end 
    ' reload context if enabled in prefs
    if i > m.context.count()-1 then 
        Debug("ICphotoPlayerNext:: end of loop, calling reloadSlideContext() and restarting loop [not exiting]")
        i=0:m.reloadSlideContext()
    end if

    m.curindex = i

    m.GetSlideImage()

    ' increment the next index even if we are unsuccessful at retrieving the image
    ' this will allow us to move past failures ( we will show an error after too many failures )
    m.nextindex = i+1
    Debug("ICphotoPlayerNext:: next:" + tostr(m.nextIndex))
end sub

sub ICphotoPlayerPrev()
    Debug("ICphotoPlayerPrev:: previous called")
    if m.context.count() = 1 then return 

    ' allow the user to quickly press next button without requesting image
    if m.userRequest <> invalid then 
        ' cancel any pending request as we are trying to view the previous image 
        Debug("ICphotoPlayerPrev:: cancel any pending requests and start fresh on screenID: " + tostr(m.screenID))
        GetViewController().CancelRequests(m.ScreenID)
        m.userRequest = invalid
    end if

    Debug("ICphotoPlayerPrev:: viewing:" + tostr(m.curIndex))

    ' calculate the previous index to view
    i=m.curindex-1
    if i < 0 then i = m.context.count()-1

    m.curindex=i

    ' request/set in the image ( http or cached )
    m.GetSlideImage()

    m.nextindex = i+1
    Debug("ICphotoPlayerPrev:: next:" + tostr(m.nextIndex))
end sub

sub ICphotoPlayerPause()
    if m.context.count() = 1 then return 
    m.IsPaused = true
    m.Timer.Active = false
    m.OverlayToggle("show","Paused")
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "paused", 0)
end sub

sub ICphotoPlayerResume()
    if m.context.count() = 1 then return 

    ' we do not load the Full Context to just display one image
    ' - however let us allow EU to browse full context if requested
    if NOT m.isSlideShow and NOT m.FullContext = true then 
        GetPhotoContextFromFullGrid(m,m.item.origindex) 
    end if 

    m.IsPaused = false
    m.isSlideShow = true
    m.Timer.Active = true
    m.OverlayToggle("show","Resumed")
    NowPlayingManager().UpdatePlaybackState("photo", m.Context[m.CurIndex], "playing", 0)
end sub

sub ICphotoPlayerStop()
    m.Screen.Close()
end sub

Sub ICphotoPlayerSetShuffle(shuffleVal)
    if m.context.count() = 1 then return 
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
    if m.NextIndex <> invalid and m.CurIndex < m.context.count() - 1 then
        m.NextIndex = m.CurIndex + 1
    else
        m.NextIndex = 0 ' End or Start of slideShow
    end if

    NowPlayingManager().timelines["photo"].attrs["shuffle"] = tostr(shuffleVal)
End Sub

function ICgetSlideImage(bufferNext=false, FromMetadataRequest = false)
    if bufferNext =true and m.context.count() = 1 then 
        Debug("cancelling bufferNext request -- context only contains 1 image")
        return false
    end if

    ' by default we cache locally and show the curIndex. If this is a bufferNext, then
    ' we will retrieve curIndex+1 or 0 and cache only. 
    itemIndex = m.curindex
    if bufferNext then 
        ' normally we load the next image when bufferNext is set
        bufferIndex = itemIndex+1
        if bufferIndex > m.context.count()-1 then bufferIndex = 0
        itemIndex = bufferIndex
    end if 
    item = m.context[itemIndex]

    ' purge expired metadata records (retain the index we are using)
    if m.CachedMetadata > 500 then m.PurgeMetadata(itemIndex)

    ' send a request for the metadata/url and return 
    ' we must have this info before we can request/save/show the image
    if item.url = invalid and FromMetadataRequest = false then  
        request = item.server.CreateRequest("", item.key )
        context = CreateObject("roAssociativeArray")
        context.requestType = "slideshowMetadata"
        context.bufferNext = bufferNext
        context.ItemIndex = itemIndex
        context.server = item.server
    
        GetViewController().StartRequest(request, m, context)

        ' Stop the slideshow timer if we are trying to show the current image. We do not want to keep 
        ' making requests if we are still waiting on a response. This will reactivate when we recieve 
        ' a response OR during the health check in case the response was "lost"
        if m.IsPaused = false and NOT bufferNext and m.Timer.Active = true  then 
            Debug("Deactivate slideshow timer.. had to request metadata for image ( before downloading )")
            m.Timer.Active = false
            m.TimerHealth.Mark() ' mark Health Timer (failsafe reactivation)
        end if

        return false
    end if

    ' location/name of the cached file ( to read or to save )
    if item <> invalid and item.ratingKey <> invalid and item.title <> invalid then 
        localFilePath = "tmp:/" + item.ratingKey + "_" + item.title + ".jpg"
    else 
        ' ignore if the item is missing context if it's the next image we were trying to save
        ' it will be requested once more when it's up (next). 
        if bufferNext = true and FromMetadataRequest = true then  
            Debug("getSlideImage:: item missing required metadata -- bufferNext request -- ignoring")
        else 
            Debug("getSlideImage:: item missing required metadata -- skipping -- [server response failure or removed item?]")
            if item <> invalid then print item
            Debug("getSlideImage:: reloading context due to failure")
            ' maybe the context has changed on us? someone removed photos during a slideshow... or?
            ' reload the slide context.. safe to run multiple times as there is a expiration time
            m.reloadSlideContext(true)
        end if
        return false
    end if 

    Debug("-- cached files: " + tostr(m.LocalFiles.count()))
    Debug("   bytes: " + tostr(m.LocalFileSize))
    Debug("      MB: " + tostr(int(m.LocalFileSize/1048576)))
    Debug("-- cached metadata: " + tostr(m.CachedMetadata))

    ' Purge the local cache if we have more than X images or 10MB used on disk 
    if m.LocalFiles.count() > 500 or (m.LocalFileSize/1048576) > 5 then m.purgeSlideImages()

    ' return the cached image ( if we have one )
    if m.LocalFiles.count() > 0 then 
        for each local in m.LocalFiles 
            if local.localFilePath = localFilePath then 
                ' stop processing if this was a request for the next image (buffer)
                if BufferNext then
                    Debug(tostr(localFilePath) + " is already cached (next image buffer)")
                    return false ' ignore the rest if we loaded the next images (bufferNext)
                end if
                ' continue on and show the image

                ba=CreateObject("roByteArray")
                ba.ReadFile(localFilePath)
                if ba.Count() > 0 then 
                    Debug("using cached file: " + tostr(localFilePath))

                    m.CurFile = local ' set it and return
                    m.ShowSlideImage()
        
                    ' buffer the next image now ( current image cached was successful, it's ok to load another now )
                    if NOT BufferNext then m.GetSlideImage(true)

                    ' do not wait for urlEvent -- it's cached!
                    return true
                else 
                    Debug("loading cache file failed: " + tostr(localFilePath) +  " requesting now")
                end if 

            end if 
        end for
    end if

    ' cache the image on disk
    request = CreateObject("roUrlTransfer")
    request.EnableEncodings(true)
    request.SetUrl(item.url)
    context = CreateObject("roAssociativeArray")
    context.requestType = "slideshowImage"
    context.localFilePath = localFilePath
    context.bufferNext = bufferNext

    if bufferNext then 
        Debug("Get Slide Show Image (next image buffer): " + item.url + " save to " + localFilePath)
    else 
        Debug("Get Slide Show Image (current image): " + item.url + " save to " + localFilePath)
    end if
    GetViewController().StartRequest(request, m, context, invalid, localFilePath)

    if NOT BufferNext then 
        Debug("GetSlideImage:: starting GetSlideImage again as a next buffer request")
        m.GetSlideImage(true)
    end if

    return false ' false means we wait for response
end function

sub ICPurgeMetadata(retainIndex=invalid)
    ' this resets the metadata to the lightweight original
    Debug("Purging Full Metadata from " + tostr(m.context.count()) + " items")
    count = 0
    retain = 0
    for index = 0 to m.context.count()-1
        if m.context[index].origItem <> invalid then 
            if retainIndex <> invalid and retainIndex = index then 
                retain = retain+1
                Debug("retaining item at Index " + tostr(index))
            else 
                count = count+1
                m.context[index] = m.context[index].origItem
            end if
        end if
    next
    m.CachedMetadata = retain
    Debug("Purged " + tostr(count) + " items")
end sub

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
        print ListDir("tmp:/")
    else 
        Debug("Purge files called -- no files to purge")
    end if

    Debug("screen PurgeCachedImages() called")
    m.screen.PurgeCachedImages()

    'Debug("Running Garbage Collector")
    'RunGarbageCollector()
end sub

sub ICphotoPlayerActivate(priorScreen) 
    ' pretty basic for now -- we will resume the slide show if paused and forceResume is set
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

    ' metadata request: set the metadata for the response and try GetSlideImage again 
    '  will save/show image, save image if next buffer, or re-request metadata on failure
    if requestContext.requestType = "slideshowMetadata" then 
        url = tostr(requestContext.Request.GetUrl())

        if msg.GetResponseCode() = 200 then 
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + url)

            origItem = m.context[requestContext.ItemIndex]
            xml = CreateObject("roXMLElement")
            xml.Parse(msg.GetString())
            response = CreateObject("roAssociativeArray")
            response.xml = xml
            response.server = requestContext.server
            response.sourceUrl = requestContext.Request.GetUrl()
            container = createPlexContainerForXml(response)
            item = container.getmetadata()[0]

            if item <> invalid and item.url <> invalid then 
                ' anything we need to set before we reset the item
                ' * OrigIndex might exist if shuffled
                if m.context[requestContext.ItemIndex].OrigIndex <> invalid then item.OrigIndex = m.context[requestContext.ItemIndex].OrigIndex
                m.context[requestContext.ItemIndex] = item
                m.context[requestContext.ItemIndex].origItem = origItem
                m.CachedMetadata = m.CachedMetadata+1
                ' testing in new port -- use to just blindly call this on failure or not
                Debug("photoSlideShowOnUrlEvent:: GetSlideImage called")
                m.GetSlideImage(requestContext.bufferNext, true)
            else 
                Debug("could not set context from metadata -- getmetadata() failed?")
                print "------------- msg response string -------------------"
                print msg.GetString()
                print "------------- msg response string -------------------"
                if item <> invalid then 
                    print "item context invalid from getmetadata() -- missing url key?"
                    print item
                else 
                    print "item context invalid from getmetadata() -- showing container"
                    print container
                end if
            end if
        else 
            ' urlEventFailure - nothing to see here
            failureReason = msg.GetFailureReason()
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + url + " - " + tostr(failureReason))
            m.setImageFailureInfo(failureReason)
        end if  

        ' If we recieved an response (failure or success) enable the slideshow again. It will move on to the next image
        ' depending on the response. 
        if m.IsPaused = false and m.Timer.Active = false then  
            Debug("Reactivate slideshow timer.. metadata request completed")
            m.Timer.Mark()
            m.Timer.Active = true
        end if

    else if requestContext.requestType = "slideshowImage" then 

        ' Image Request Response: save and show image
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
                ' show the failure on the every 5th consecutive failure
                showFailureInfo = m.ImageFailureCount/5
                if int(showFailureInfo) = showFailureInfo then m.OverlayToggle("forceShow")
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
    
            ' after height scale - verify the width is < canvas width
            if obj.metadata.width > m.canvasrect.w then 
                mp = m.canvasrect.w/obj.metadata.width
                obj.metadata.height = int(mp*obj.metadata.height)
                obj.metadata.width = m.canvasrect.w
            end if
    
            ' set UnderScan -- TODO(ljunkie) verify this is right for other TV's
            obj.metadata.height = int(obj.metadata.height*((100-m.UnderScan)/100))
            obj.metadata.width = int(obj.metadata.width*((100-m.UnderScan)/100))
    
            ' container to know what file(s) we have created to purge later
            m.LocalFiles.Push(obj)
    
            ' current image to display
            ' skip if it is a bufferNext ( we preload the next image )
            if NOT requestContext.bufferNext then 
                Debug(tostr(obj.localFilePath) + " saved to cache (current)")
                m.CurFile = obj
                m.ShowSlideImage()
            else 
                Debug(tostr(obj.localFilePath) + " saved to cache (next image buffer)")
            end if
        else 
            ' urlEventFailure - nothing to see here
            failureReason = msg.GetFailureReason()
            url = tostr(requestContext.Request.GetUrl())
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + url + " - " + tostr(failureReason))
            m.setImageFailureInfo(failureReason)
        end if
    end if ' End request image


End Sub

' overlay info -- so EU can know what's happening if the slideShow isn't working
sub ICsetImageFailureInfo(failureReason=invalid)
    if failureReason <> invalid then 
        m.ImageFailure = true
        m.ImageFailureReason = failureReason
        m.ImageFailureCount = int(m.ImageFailureCount+1)
        Debug("    fail Count: " + tostr(m.ImageFailureCount))
        ' show (force the overlay) on the every 100th failure if we have files ( or every 5th if we don't )
        if m.LocalFiles.count() = 0 then 
            showFailureInfo = m.ImageFailureCount/5
        else 
            showFailureInfo = m.ImageFailureCount/100
        end if

        if int(showFailureInfo) = showFailureInfo then m.OverlayToggle("forceShow")
    else 
        ' reset any image failures
        m.ImageFailure = false
        m.ImageFailureReason = invalid
        m.ImageFailureCount = 0
    end if
end sub

' this can be called independently while passing the object 
sub photoShowContextMenu(screen = invalid,force_show = false, forceExif = true)
    if screen <> invalid then
        Debug("context menu using passed object from previous screen")
        obj = screen.item
    else if type(m.context) = "roArray" and m.CurIndex <> invalid then 
        ' try and use the actually item being show -- otherwise fall back to the curIndex
        screen = m ' m is the screen in this context, but we sometimes pass the screen (above)
        if m.item <> invalid then 
            obj = m.item
        else 
            obj = m.context[m.CurIndex]
        end if
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

    getExifData(obj,false,forceExif)

    ' TODO(ljunkie) it's ugly! -- convert this to an image canvas 
    ' I was hoping to convert this to an image canvas, but the roGridScreen
    ' doesn't work with an ImageCanvas as an overlay... verified by Roku
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
            if m.IsShuffled then
                dialog.SetButton("shuffle", "Shuffle: On")
            else
                dialog.SetButton("shuffle", "Shuffle: Off")
            end if
        end if

        dialogSetSortingButton(dialog,screen) 

        dialog.SetButton("close", "Close")
        dialog.HandleButton = photoContextMenuHandleButton
        dialog.EnableOverlay = true
        dialog.ParentScreen = screen
        dialog.Show()
    end if

End sub

sub ICreloadSlideContext(forced=false)
    if RegRead("slideshow_reload", "preferences", "disabled") <> "disabled" or forced = true then 

        ' only reload every 5 minutes max  -- stops delay from clicking back/forth 
        ' between last and 1st image. forced=true does NOT override this
        expireSec = 300 
        if m.lastreload <> invalid and getEpoch()-m.lastReload < expireSec then 
            Debug("Skipping Reload " + tostr(getEpoch()-m.lastReload) + " seconds < expire seconds " + tostr(expireSec))
            return
        end if

        if forced = true then 
            Debug("ICreloadSlideContext:: checking for new content (forced)")
        else 
            Debug("ICreloadSlideContext:: checking for new content")
        end if

        m.lastReload = getEpoch()
        if m.item <> invalid and m.item.server <> invalid and (m.item.sourceurl <> invalid or m.sourceReloadURL <> invalid) then 
            Debug("purge any cache before attempting to reload context")
            m.purgeSlideImages() ' cleanup the local cached images
            m.purgeMetadata() ' cleanup the retrieved metadata during the slide show ( maybe just set invalid )

            obj = {}:dummyItem = {}
            dummyItem.server = m.item.server
            ' we really should only be reloading from the sourceReloadURL
            ' m.item.sourcurl is now most likely the specific item.. we will skip if only 1 result
            ' TODO(ljunkie) we could also speed this up by using createPlexContainerForUrlSizeOnly()  
            ' to verify the total size ( won't be perfect - response could contain dirs )
            dummyItem.sourceUrl = firstof(m.sourceReloadURL,m.item.sourceurl)
            dummyItem.hideErrors = true ' do not show warning about loading errors
            if dummyItem.sourceUrl = invalid then Debug("no valid url to reload"):return
            PhotoMetadataLazy(obj, dummyItem, true)

            ' set to true to test the reload function 
            ' only used for debugging -- we can remove this at a later date
            forceReloadTest = false 

            newCount = obj.context.count():curCount = m.context.count()
            Debug("Cur Items: " + tostr(curCount)):Debug("New Items: " + tostr(newCount))

            ' return if newCount = 1 -- possible sourceReloadURL/item.sourceurl is set to the specific item key
            if newCount = 1 then Debug("not reloading with 1 item -- we probably queried the direct item"):return

            if forceReloadTest or (newCount > 0 and newCount <> curCount) then 
                cleanContext = ICphotoPlayerCleanContext(obj.context,0)
                cleanCount = cleanContext.context.count()
                Debug("New (cleaned) Items: " + tostr(cleanCount)) 
                if forceReloadTest or (cleanCount > 0 and cleanCount <> curCount) then 
                    m.context = cleanContext.context
                    Debug("reloading slideshow with new context " + tostr(m.context.count()) + " items")
                    if m.isShuffled and m.Context.count() > 1 then 
                        Debug("slideshow was shuffled - we need to reshuffle due to new context")
                        ShuffleArray(m.Context, m.CurIndex)
                        Debug("shuffle done")
                    end if
                    'Debug("Running Garbage Collector")
                    'RunGarbageCollector()
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

' we need a quicker, more memory efficient way to load images. We don't need all the metadata as we do normally
' by default (lazy=true) we will only set the library key and some other necessities 
' NOTE: lazy=false should not be used.. defeats the purpose -- but nice for testing
sub GetPhotoContextFromFullGrid(obj,curindex = invalid, lazy=true) 
    Debug("----- get Photo Context from Full Grid")
    Debug("----- lazy Mode: " + tostr(lazy) )
    if NOT fromFullGrid() then Debug("NOT from a full grid.. nothing to see here"):return

    ' full context already loaded -- but we still might need to reset the CurIndex
    if obj.FullContext = true then 
       Debug("All context is already loaded! total: " + tostr(obj.context.count()))
       ' if we are still in the full grid, we will have to calculate the index again 
       '  rows are only 5 items -- curIndex is always 0-5
       if obj.isFullGrid = true then obj.CurIndex = getFullGridCurIndex(obj,CurIndex,1)
       return
    end if

    dialog=ShowPleaseWait("Loading Items... Please wait...","")

    if obj.metadata <> invalid and obj.metadata.sourceurl <> invalid then 
        sourceUrl = obj.metadata.sourceurl
        server = obj.metadata.server
    else if obj.item <> invalid and obj.item.sourceurl <> invalid then 
        sourceUrl = obj.item.sourceurl
        server = obj.item.server
    end if
    if sourceUrl = invalid or server = invalid then return
    if curindex = invalid then curindex = obj.curindex

    ' strip any limits imposed by the full grid - we need it all ( not start or container size)
    sourceUrl = rfStripAPILimits(sourceUrl)

    ' no quickly load the required metadata (lazy)
    dummyItem = {}
    dummyItem.server = server
    dummyItem.sourceUrl = sourceUrl
    dummyItem.hasWaitDialog = dialog
    PhotoMetadataLazy(obj, dummyItem, lazy)

    ' this should be closed in the PhotoMetadataLazy section
    if dummyItem.hasWaitDialog <> invalid then dummyItem.hasWaitDialog.close()
end sub

sub PhotoMetadataLazy(obj, dummyItem, lazy = true)
    ' this will only load a minimal set of metadata per item
    ' break api calls to 1k item chunks ( Roku has issues parsing large XML result sets )
    chunks = 3000

    ' set some variables if invalid: we might be passing an empty object to fill ( we expect some results )
    if obj.context = invalid then obj.context = []
    if obj.CurIndex = invalid then obj.CurIndex = 0

    if dummyItem.showWait = true and dummyItem.hasWaitDialog = invalid then 
        dummyItem.hasWaitDialog=ShowPleaseWait("Loading Items... Please wait...","")
    end if

    ' verify we have enough info to continue ( server and sourceurl )
    if dummyItem.server = invalid or dummyItem.sourceUrl = invalid then 
        if NOT dummyItem.hideErrors = true then
            ShowErrorDialog("Sorry! We were unable to load your photos [1].","Warning")
        end if
        if dummyItem.hasWaitDialog <> invalid then dummyItem.hasWaitDialog.close()
        return 
    end if

    dummyItem.sourceUrl = rfStripAPILimits(dummyItem.sourceUrl)

    ' lazy loading .. we need this for later to reload the slideshow
    Debug("PhotoMetadataLazy:: source reload url = " + tostr(dummyItem.sourceUrl))
    obj.sourceReloadURL = dummyItem.sourceUrl 

    ' we might have to figure out the total size before we know to split
    container = createPlexContainerForUrlSizeOnly(dummyItem.server, invalid , dummyItem.sourceUrl)    

    ' verify we have some results from the api to process
    if container = invalid or container.totalsize = invalid or container.totalsize.toint() < 1 then 
        if NOT dummyItem.hideErrors = true then
            ShowErrorDialog("Sorry! We were unable to load your photos [2].","Warning")
        end if
        if dummyItem.hasWaitDialog <> invalid then dummyItem.hasWaitDialog.close()
        return 
    end if

    ' OLD: container = createPlexContainerForUrl(dummyItem.server, invalid, dummyItem.sourceUrl)
    ' break each request into 1000 max items per request ( or whatever we set chunks too )
    results = []
    for index = 0 to container.totalsize.toInt()-1 step chunks

        newurl = rfStripAPILimits(dummyItem.sourceUrl)
        f = "?"
        if instr(1, newurl, "?") > 0 then f = "&"
        newurl = newurl + f + "X-Plex-Container-Start="+tostr(index)+"&X-Plex-Container-Size="+tostr(chunks)
        container = createPlexContainerForUrl(dummyItem.server, invalid, newurl)

        ' verify we have some results from the api to process
        if isnonemptystr(container.xml@header) AND isnonemptystr(container.xml@message) then
            Debug("skipping results for item: " + tostr(index) + " - " + tostr(index+chunks) + "  reason: no results from " + tostr(newurl))
        else     
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

                ' only push valid metadata - we only expect Photo and Directories
                if metadata <> invalid and metadata.key <> invalid then results.Push(metadata)
                metadata = invalid
            next
        end if

    end for

    ' verify we have some results 
    if results.count() = 0 then 
        if NOT dummyItem.hideErrors = true then
            ShowErrorDialog("Sorry! We were unable to process your photos [3].","Warning")
        end if
        if dummyItem.hasWaitDialog <> invalid then dummyItem.hasWaitDialog.close()
        return 
    end if

    obj.context = results:results = invalid
    obj.CurIndex = getFullGridCurIndex(obj,dummyItem.CurIndex,1) ' when we load the full context, we need to fix the curindex
    obj.FullContext = true

    ' cleanup
    nodes = invalid
    metadata = invalid 
    container = invalid
    'RunGarbageCollector()

    if dummyItem.hasWaitDialog <> invalid then dummyItem.hasWaitDialog.close()
end sub

' Depending on where we come from, we may not have all the context loaded yet
' we will need to lazy load the rest
sub PhotoPlayerCheckLoaded(obj,index = 0)
    Debug("verifying the required metadata is loaded")
    if obj.context[obj.context.count()-1].key = invalid then
        item = obj.context[index]
        Debug("context is not fully loaded yet.. loading now.. be patient for large libraries")
        dummyItem = {}
        dummyItem.server = obj.context[index].server
        if type(obj.context) = "roAssociativeArray" and obj.context.sourceReloadURL <> invalid then 
            dummyItem.sourceUrl = obj.sourceReloadUrl
        else 
            dummyItem.sourceUrl = obj.context[index].sourceurl
        end if
        dummyItem.showWait = true
        PhotoMetadataLazy(obj, dummyItem, true)
        ' reset the initial item if it was already loaded ( usually the case )
        if item.key <> invalid then obj.context[index] = item
    end if
end sub

sub PhotoPlayerRefresh() 
    ' show the current status in the overlay on refresh
    m.OverlayToggle("forceShow")
end sub
