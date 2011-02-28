

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
	metaDataArray = Populate(screen, contentList, index)
	metadata = metaDataArray.metadata
	
    while true
        msg = wait(0, screen.GetMessagePort())
        if msg.isScreenClosed() then 
        	return -1
        else if msg.isButtonPressed() then
        	buttonCommand = metaDataArray[str(msg.getIndex())]
        	print "Button command:";buttonCommand
			startTime = 0
			if buttonCommand = "resume" then
				startTime = int(val(metadata.viewOffset))
			endif
        	mediaData = metaDataArray.media
        	playVideo(server, metadata, mediaData, startTime)
        	'* Refresh play data after playing
        	Populate(screen, contentList, index)
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
    
	metaDataArray = CreateObject("roAssociativeArray")
	metadata = server.DetailedVideoMetadata(content.sourceUrl, content.key)
	metaDataArray.metadata = metadata
	screen.AllowNavLeft(true)
	screen.AllowNavRight(true)
	screen.setContent(metadata)
	screen.ClearButtons()
	buttonCount = 0
	
	'* Buttons for play and resume of preferred media item.
	'* TODO: add ability to turn subtitles on/off, pick one and pick audio stram
	'* 
	media = PickMediaItem(metadata.media)
	metaDataArray.media = media
	screen.AddButton(buttonCount, "Play")
	metaDataArray[str(buttonCount)] = "play"
	buttonCount = buttonCount + 1
	if metadata.viewOffset <> invalid then
	
		intervalInSeconds = fix(val(metadata.viewOffset)/(1000))	
		resumeTitle = "Resume from "+TimeDisplay(intervalInSeconds)
		screen.AddButton(buttonCount, resumeTitle)
		metaDataArray[str(buttonCount)] = "resume"
		buttonCount = buttonCount + 1
	endif
	screen.PrefetchPoster(metadata.SDPosterURL, metadata.HDPosterURL)
	screen.Show()
	retrieving.Close()
	return metaDataArray
End Function

Function TimeDisplay(intervalInSeconds) As String
	hours = fix(intervalInSeconds/(60*60))
	remainder = intervalInSeconds - hours*60*60
	minutes = fix(remainder/60)
	seconds = remainder - minutes*60
	hoursStr = hours.tostr()
	if hoursStr.len() = 1 then
		hoursStr = "0"+hoursStr
	endif
	minsStr = minutes.tostr()
	if minsStr.len() = 1 then
		minsStr = "0"+minsStr
	endif
	secsStr = seconds.tostr()
	if secsStr.len() = 1 then
		secsStr = "0"+secsStr
	endif
	return hoursStr+":"+minsStr+":"+secsStr
End Function

'* Logic for choosing which Media item to use from the list of possibles
Function PickMediaItem(mediaItems) As Object
	if mediaItems.count()  = 0 then
		return mediaItems[0]
	else
		return mediaItems[0]
	endif
End Function
