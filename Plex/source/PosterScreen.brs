'* Displays the content in a poster screen. Can be any content type.

Function preShowPosterScreen(breadA=invalid, breadB=invalid) As Object

    if validateParam(breadA, "roString", "preShowPosterScreen", true) = false return -1
    if validateParam(breadA, "roString", "preShowPosterScreen", true) = false return -1

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


Function showPosterScreen(screen, content) As Integer

    if validateParam(screen, "roPosterScreen", "showPosterScreen") = false return -1
    if validateParam(content, "roAssociativeArray", "showPosterScreen") = false return -1
	print "show poster screen for key ";
	
	retrieving = CreateObject("roOneLineDialog")
	content.keyretrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Retrieving from Plex Media Server ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()
	server = content.server
	content = server.GetContent(content.sourceUrl, content.key)
    screen.SetContentList(content)
    screen.Show()
	retrieving.Close()

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            print "showHomeScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex()
            if msg.isListFocused() then
                print "list focused | index = "; msg.GetIndex(); " | category = "; m.curCategory
                ' TODO: Change content after fetching from server
            else if msg.isListItemSelected() then
                selected = content[msg.GetIndex()]
                contentType = selected.ContentType
                print "list item selected | index = "; msg.GetIndex()
                print "item type = "; contentType
                if contentType = "movie" OR contentType = "episode" then
                	playVideo(selected)
                elseif contentType = "Directory" then
                	showNextPosterScreen(selected)
                endif
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

    return 0

End Function

Function showNextPosterScreen(selected As Object) As Dynamic
    if validateParam(selected, "roAssociativeArray", "showNextPosterScreen") = false return -1
    screen = preShowPosterScreen(selected.Title, "")
    showPosterScreen(screen, selected)
    return 0
End Function

Function playVideo(videoData) 
	print "Displaying video: ";videoData.MediaKey
	
	server = videoData.Server
	video = server.VideoScreen(videoData.MediaKey, videoData.title)
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