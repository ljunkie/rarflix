

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
	
    while true
        msg = wait(0, screen.GetMessagePort())
        if msg.isScreenClosed() then 
        	return -1
        else if msg.isButtonPressed() then
        	buttonCommand = metaDataArray.buttonCommands[str(msg.getIndex())]
        	print "Button command:";buttonCommand
        	if buttonCommand = "play" OR buttonCommand = "resume" then
				startTime = 0
				if buttonCommand = "resume" then
					startTime = int(val(metaDataArray.metadata.viewOffset))
				endif
        		playVideo(server, metaDataArray.metadata, metaDataArray.media, startTime)
        		'* Refresh play data after playing
        		metaDataArray = Populate(screen, contentList, index)
        	else if buttonCommand = "audioStreamSelectionButtons" then
        		metaDataArray.buttonCommands = AddAudioStreamButtons(screen, metaDataArray.media)
        	else if buttonCommand = "subtitleStreamSelectionButtons" then
        		metaDataArray.buttonCommands = AddSubtitleStreamButtons(screen, metaDataArray.media)
        	else if buttonCommand = "selectSubtitle" then
        		subtitleId = metaDataArray.buttonCommands[str(msg.getIndex())+"_id"]
        		print "Media part "+metaDataArray.media.preferredPart.id
        		print "Selected subtitle "+subtitleId
        		server.UpdateSubtitleStreamSelection(metaDataArray.media.preferredPart.id, subtitleId)
        		metaDataArray = Populate(screen, contentList, index)
        		metaDataArray.buttonCommands = AddButtons(screen, metaDataArray.metadata, metaDataArray.media)
        	else if buttonCommand = "selectAudioStream" then
        		audioStreamId = metaDataArray.buttonCommands[str(msg.getIndex())+"_id"]
        		print "Media part "+metaDataArray.media.preferredPart.id
        		print "Selected audio stream "+audioStreamId
        		server.UpdateAudioStreamSelection(metaDataArray.media.preferredPart.id, audioStreamId)
        		metaDataArray = Populate(screen, contentList, index)
        		metaDataArray.buttonCommands = AddButtons(screen, metaDataArray.metadata, metaDataArray.media)
        	endif
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
	metaDataArray.media = metadata.preferredMediaItem
	metaDataArray.buttonCommands = AddButtons(screen, metadata, metadata.preferredMediaItem)
	screen.PrefetchPoster(metadata.SDPosterURL, metadata.HDPosterURL)
	screen.Show()
	retrieving.Close()
	return metaDataArray
End Function

Function AddSubtitleStreamButtons(screen, media) As Object

	screen.ClearButtons()
	buttonCount = 0
	mediaPart = media.preferredPart
	selected = false
	for each Stream in mediaPart.streams
		if Stream.streamType = "3" AND Stream.selected <> invalid then
			selected = true
		endif
	next
	
	buttonCommands = CreateObject("roAssociativeArray")
	noSelectionTitle = "No Subtitles"
	if not selected then
		noSelectionTitle = "> "+noSelectionTitle
	endif
	screen.AddButton(buttonCount, noSelectionTitle)
	buttonCommands[str(buttonCount)] = "selectSubtitle"
	buttonCommands[str(buttonCount)+"_id"] = ""
	buttonCount = buttonCount + 1	
	for each Stream in mediaPart.streams
		if Stream.streamType = "3" then
			buttonTitle = Stream.Language
			if Stream.selected <> invalid then
				buttonTitle = "> " + buttonTitle
			endif
			screen.AddButton(buttonCount, buttonTitle)
			buttonCommands[str(buttonCount)] = "selectSubtitle"
			buttonCommands[str(buttonCount)+"_id"] = Stream.Id
			buttonCount = buttonCount + 1	
		endif
	next
	return buttonCommands
End Function

Function AddAudioStreamButtons(screen, media) As Object

	screen.ClearButtons()
	buttonCount = 0
	
	buttonCommands = CreateObject("roAssociativeArray")
	mediaPart = media.preferredPart
	for each Stream in mediaPart.streams
		if Stream.streamType = "2" then
			buttonTitle = Stream.Language
			subtitle = invalid
			if Stream.Codec <> invalid then
				if Stream.Codec = "dca" then
					subtitle = "DTS"
				else 
					subtitle = ucase(Stream.Codec)
				endif
			endif
			if Stream.Channels <> invalid then
				if Stream.Channels = "2" then
					subtitle = subtitle + " Stereo"
				else if Stream.Channels = "6" then
					subtitle = subtitle + " 5.1"
				else if Stream.Channels = "8" then
					subtitle = subtitle + " 7.1"
				endif
			endif
			if subtitle <> invalid then
				buttonTitle = buttonTitle + " ("+subtitle+")"
			endif
			if Stream.selected <> invalid then
				buttonTitle = "> " + buttonTitle
			endif
			screen.AddButton(buttonCount, buttonTitle)
			buttonCommands[str(buttonCount)] = "selectAudioStream"
			buttonCommands[str(buttonCount)+"_id"] = Stream.Id
			buttonCount = buttonCount + 1	
		endif
	next
	return buttonCommands
End Function

Function AddButtons(screen, metadata, media) As Object

	buttonCommands = CreateObject("roAssociativeArray")
	screen.ClearButtons()
	buttonCount = 0
	screen.AddButton(buttonCount, "Play")
	buttonCommands[str(buttonCount)] = "play"
	buttonCount = buttonCount + 1
	if metadata.viewOffset <> invalid then
		intervalInSeconds = fix(val(metadata.viewOffset)/(1000))	
		resumeTitle = "Resume from "+TimeDisplay(intervalInSeconds)
		screen.AddButton(buttonCount, resumeTitle)
		buttonCommands[str(buttonCount)] = "resume"
		buttonCount = buttonCount + 1
	endif
	
	mediaPart = media.preferredPart
	subtitleStreams = []
	audioStreams = []
	for each Stream in mediaPart.streams
		if Stream.streamType = "2" then
			audioStreams.Push(Stream)
		else if Stream.streamType = "3" then
			subtitleStreams.Push(Stream)
		endif
	next
	print "Found audio streams:";audioStreams.Count()
	print "Found subtitle streams:";subtitleStreams.Count()
	if audioStreams.Count() > 1 then
		screen.AddButton(buttonCount, "Select audio stream")
		buttonCommands[str(buttonCount)] = "audioStreamSelectionButtons"
		buttonCount = buttonCount + 1
	endif
	if subtitleStreams.Count() > 0 then
		screen.AddButton(buttonCount, "Select subtitles")
		buttonCommands[str(buttonCount)] = "subtitleStreamSelectionButtons"
		buttonCount = buttonCount + 1
	endif
	return buttonCommands
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

