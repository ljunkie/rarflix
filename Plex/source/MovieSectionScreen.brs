'* Displays the content of a movie section
'*
'* Probably not the best way: general solution needed that allows hierarchy desending but
'* figure that out once I've got my head around the Roku screen model


Function preShowMovieSectionScreen(breadA=invalid, breadB=invalid) As Object

    if validateParam(breadA, "roString", "preShowMovieSectionScreen", true) = false return -1
    if validateParam(breadA, "roString", "preShowMovieSectionScreen", true) = false return -1

    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
    end if

    screen.SetListStyle("arced-portrait")
    screen.setAdDisplayMode("scale-to-fill")
    return screen

End Function


Function showMovieSectionScreen(screen, section) As Integer

    if validateParam(screen, "roPosterScreen", "showMovieSectionScreen") = false return -1
	
	server = section.Server
	sectionContent = server.GetLibrarySectionContent(section.Key)
    screen.SetContentList(sectionContent)
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            print "showHomeScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex()
            if msg.isListFocused() then
                print "list focused | index = "; msg.GetIndex(); " | category = "; m.curCategory
            else if msg.isListItemSelected() then
                print "list item selected | index = "; msg.GetIndex()
                print "Key:"+sectionContent[msg.GetIndex()].Key
                video = sectionContent[msg.GetIndex()]
                PlayVideo(video)
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

    return 0

End Function

Function playVideo(videoData) 
	print "Displaying video: ";videoData.Key
	
	server = videoData.Server
	video = server.VideoScreen(videoData.videoKey, videoData.title)
	video.show()
    
    lastSavedPos   = 0
    statusInterval = 10 'position must change by more than this number of seconds before saving

    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                server.StopVideo()
                exit while
            else if msg.isPlaybackPosition() then
                nowpos = msg.GetIndex()
                if nowpos > 10000
                    
                end if
                if nowpos > 0
                    if abs(nowpos - lastSavedPos) > statusInterval
                        lastSavedPos = nowpos
                    end if
                end if
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function