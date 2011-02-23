

Function preShowSpringboardScreen(section, breadA=invalid, breadB=invalid) As Object
    if validateParam(breadA, "roString", "preShowSpringboardScreen", true) = false return -1
    if validateParam(breadB, "roString", "preShowSpringboardScreen", true) = false return -1

    port=CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
        screen.SetBreadcrumbEnabled(true)
    end if
    return screen

End Function


Function showSpringboardScreen(screen, contentList, index) As Integer
	server = contentList[index].server
	metadata = Populate(screen, contentList, index)
    while true
        msg = wait(0, screen.GetMessagePort())
        if msg.isScreenClosed() then 
        	return -1
        else if msg.isButtonPressed() then
        	videoData = metadata.media[msg.getIndex()]
        	videoKey = videoData.parts[0]
        	playVideo(server, metadata.title, videoKey)
        else if msg.isRemoteKeyPressed() then
        	'* index=4 -> left ; index=5 -> right
			if msg.getIndex() = 4 then
				index = index - 1
				if index < 0 then
					index = contentList.Count()-1
				endif
				Populate(screen, contentList, index)
			else if msg.getIndex() = 5 then
				index = index + 1
				if index > contentList.Count()-1 then
					index = 0
				endif
				Populate(screen, contentList, index)
			endif
        endif
    end while

    return 0
End Function

Function Populate(screen, contentList, index) As Object
	retrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Retrieving ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()
	content = contentList[index]
	server = content.server
    print "About to fetch meta-data for Content Type:";content.contentType
	metadata = server.DetailedVideoMetadata(content.sourceUrl, content.key)
	screen.AllowNavLeft(true)
	screen.AllowNavRight(true)
	screen.setContent(metadata)
	screen.ClearButtons()
	count = 0
	for each media in metadata.media
		resolution = ucase(media.videoResolution)
		if resolution = "1080" OR resolution = "720" then
			resolution = resolution + "p"
		endif
		title = "Play "+resolution+" "+media.videoCodec
		screen.AddButton(count, title)
		count = count + 1
	next
	screen.PrefetchPoster(metadata.SDPosterURL, metadata.HDPosterURL)
	screen.Show()
	retrieving.Close()
	return metadata
End Function

'* TODO: this assumes one part media. Implement multi-part at some point.
'* TODO: currently always transcodes. Check direct stream codecs first.
Function playVideo(server, title, videoKey) 
	print "Displaying video: ";videoKey
	
	video = server.VideoScreen(videoKey, title)
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