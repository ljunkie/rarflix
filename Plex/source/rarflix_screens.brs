'
' screen functions not using PMS API ( roSpringboardScreen, roPosterScreen, etc)
'

function createSpringboardScreenExt(content, index, viewController) as object

    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(obj.Port)

    obj.screen = screen
    obj.buildbuttons = build_buttons

    ' moving to plex standard
    obj.item = content[index]
    obj.contentArray = content
    obj.focusedIndex = index
    ' obj.HandleMessage = ? no generic handler made yet ( refer to trailerSBhandlemessage if needed ) 
    obj.refreshOnActivate = false
    obj.closeOnActivate = false

    screen.SetDescriptionStyle("movie")
    if (content.Count() > 1) then
        screen.AllowNavLeft(true)
        screen.AllowNavRight(true)
    end if
    screen.SetPosterStyle("rounded-rect-16x9-generic")
    screen.SetDisplayMode("zoom-to-fill")
    screen.SetBreadcrumbText("Video","")

    videoHDflag(obj.item)
    obj.buildbuttons()
    obj.screen.SetContent(obj.item)

    return obj
end function

' ljunkie function to create a poster screen with external metadata  
' using the viewController/message handlers
Function createPosterScreenExt(items, viewController, style = invalid) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    SetGlobalPosterStyle(style) 

    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(obj.Port)
    obj.Screen = screen

    ' Not Used
    '    obj.Activate = posterRefresh
    '    obj.ShowList = posterShowContentList
    '    obj.SetListStyle = posterSetListStyle
    '    obj.UseDefaultStyles = true
    '    obj.OnDataLoaded = posterOnDataLoaded

    obj.ListStyle = invalid
    obj.ListDisplayMode = invalid
    obj.FilterMode = invalid
    obj.Facade = invalid

    obj.contentArray = items
    obj.focusedList = 0
    obj.focusedIndex = 0
    obj.screen.SetContentList(items)

    return obj
End Function

Function DisplayVideo(content As Object, waitDialog = invalid)
    ' Generic Video Display - no ties to Plex
    m.ViewController.AudioPlayer.Stop() ' stop and cleanup any audioplayer

    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(5)

    date = CreateObject("roDateTime")
    endString = "invalid"
    if content.Length <> invalid and content.Length.ToInt() > 0 then
        timeLeft = content.Length.ToInt()
        endString = "End Time: " + RRmktime(date.AsSeconds()+timeLeft) + "     (" + GetDurationString(timeLeft,0,1,1) + ")" 'always show min/secs
    else
        endString = "Time: " + RRmktime(date.AsSeconds()) + "     Watched: " + GetDurationString(int(msg.GetIndex()))
    end if
    if endString <> "invalid" then content.releasedate = endString

    video.SetContent(content)
    video.show()
    ret = -1

    ' if we have a messageDialog - close it now, after we started the video
    if waitDialog <> invalid then waitDialog.Close()

    ' TODO - move this into the global port? not really required for now. We don't send timelines on external videos or require to lock the screen
    ' note: if someone pauses a video here, the screen will not be locked if enabled ( idleTimer is not checked here )
    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            'm.ViewController.ResetIdleTimer("DisplayVideo") ' not required, message port is locked to this screen
            if (Instr(1, msg.getMessage(), "interrupted") > 0) then
                ret = 1
            else if msg.isScreenClosed() then 
                content.releasedate = "" 'reset release date -- we don't want dynamic the HUD info displayed in the details
                video.SetContent(content)
                video.Close()
                exit while
            else if msg.isStreamStarted() then
                'print "Video status: "; msg.GetIndex(); " " msg.GetInfo() 
            else if msg.isPlaybackPosition() then
                if msg.GetIndex() > 0
                date = CreateObject("roDateTime")
                endString = "invalid"
                if content.Length <> invalid and content.Length.ToInt() > 0 then
                    timeLeft = int(content.Length.ToInt() - msg.GetIndex())
                    endString = "End Time: " + RRmktime(date.AsSeconds()+timeLeft) + "     (" + GetDurationString(timeLeft,0,1,1) + ")" 'always show min/secs
                else
                    endString = "Time: " + RRmktime(date.AsSeconds()) + "     Watched: " + GetDurationString(int(msg.GetIndex()))
                end if
                
                if endString <> "invalid" then content.releasedate = endString

                video.SetContent(content)
                end if
            else if msg.isStatusMessage()
                'print "Video status: "; msg.GetIndex(); " " msg.GetData() 
            else if msg.isRequestFailed()
		Debug("displayVideo :: play failed" + msg.GetMessage())
            else
                'print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
    return ret
End function

