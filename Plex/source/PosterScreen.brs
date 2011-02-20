'* Displays the content in a poster screen. Can be any content type.

Function preShowPosterScreen(section, breadA=invalid, breadB=invalid) As Object
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
	print "show poster screen for key ";content.key
	
	'retrieving = CreateObject("roOneLineDialog")
	'retrieving.SetTitle("Retrieving from Plex Media Server ...")
	'retrieving.ShowBusyAnimation()
	'retrieving.Show()
	server = content.server
	contentKey = content.key
	currentTitle = content.Title
	
	queryResponse = server.GetQueryResponse(content.sourceUrl, contentKey)
    viewGroup = queryResponse.xml@viewGroup
	names = server.GetListNames(queryResponse)
	keys = server.GetListKeys(queryResponse)
	contentType = invalid
	if names.Count() > 0 then
	    focusedItem = 0
		screen.SetListNames(names)
		screen.SetFocusedListItem(focusedItem)
		contentKey = keys[focusedItem]
		subSectionResponse = server.GetQueryResponse(queryResponse.sourceUrl, contentKey)
		contentList = server.GetContent(subSectionResponse)
		if contentList.Count() > 0 then
			contentType = contentList[0].ContentType
		endif
    	screen.SetContentList(contentList)
    	viewGroup = subSectionResponse.xml@viewGroup
	else
		contentList = server.GetContent(queryResponse)
		if contentList.Count() > 0 then
			contentType = contentList[0].ContentType
		endif
    	screen.SetContentList(contentList)
    endif
    SetListStyle(screen, viewGroup, contentType)
    screen.Show()
	'retrieving.Close()

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            if msg.isListFocused() then
                if names.Count() > 0 then
                	focusedItem = msg.GetIndex()
                	key = keys[focusedItem]
                	print "Focused key:";key
					screen.SetFocusedListItem(focusedItem)
					newXmlResponse = server.GetQueryResponse(queryResponse.sourceUrl, key)
					contentList = server.GetContent(newXmlResponse)
					contentType = invalid
					if contentList.Count() > 0 then
						contentType = contentList[0].ContentType
					endif
    				SetListStyle(screen, newXmlResponse.xml@viewGroup, contentType)
    				screen.SetContentList(contentList)
                endif
            else if msg.isListItemSelected() then
                selected = contentList[msg.GetIndex()]
                contentType = selected.ContentType
                if contentType = "movie" OR contentType = "episode" OR contentType = "clip" then
                	playVideo(selected)
                elseif contentType = "Directory" then
                	showNextPosterScreen(currentTitle, selected)
                endif
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

    return 0

End Function

Function SetListStyle(screen, viewGroup, contentType)
    print "View group:";viewGroup
    print "View group:";contentType
	listStyle = "arced-square"
    
    if viewGroup = "episode" AND contentType = "episode" then
    	listStyle = "flat-episodic"
    else if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" then
    	listStyle = "arced-portrait"
    endif
    screen.SetListStyle(listStyle)
End Function

Function showNextPosterScreen(currentTitle, selected As Object) As Dynamic
    if validateParam(selected, "roAssociativeArray", "showNextPosterScreen") = false return -1
    screen = preShowPosterScreen(selected, selected.Title, currentTitle)
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