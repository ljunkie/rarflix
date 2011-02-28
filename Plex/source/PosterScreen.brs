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
    screen.SetListStyle("arced-square")
    screen.setListDisplayMode("scale-to-fit")
    return screen

End Function


Function showPosterScreen(screen, content) As Integer

    if validateParam(screen, "roPosterScreen", "showPosterScreen") = false return -1
    if validateParam(content, "roAssociativeArray", "showPosterScreen") = false return -1
	print "show poster screen for key ";content.key
	'* Showing the screen before setting content results in the backgroud 'retrieving ...'
	'* screen which I prefer over the dialog box and seems to be the common approach used 
	'* by other Roku apps.
	screen.Show()
	server = content.server
	contentKey = content.key
	currentTitle = content.Title
	
	queryResponse = server.GetQueryResponse(content.sourceUrl, contentKey)
    viewGroup = queryResponse.xml@viewGroup
	names = server.GetListNames(queryResponse)
	keys = server.GetListKeys(queryResponse)
	contentType = invalid
	if names.Count() > 0 then
	    focusedList = 0
		screen.SetListNames(names)
		screen.SetFocusedList(focusedList)
		screen.SetFocusedListItem(0)
		contentKey = keys[focusedList]
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

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
        	'* The list focused even changes content of the screen. While 'correct'
        	'* it does make navigation a little slow. Maybe change on selection would
        	'* be better. Or is there a way to say 'focused for >500ms' to detect 
        	'* scroll pauses
            if msg.isListFocused() then
                if names.Count() > 0 then
					screen.SetContentList(invalid)
                	focusedItem = msg.GetIndex()
                	key = keys[focusedItem]
                	'print "Focused key:";key
					screen.SetFocusedListItem(0)
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
                print "Content type in poster screen:";contentType
                if contentType = "movie" OR contentType = "episode" then
                	displaySpringboardScreen(currentTitle, contentList, msg.GetIndex())
                else if contentType = "clip" then
        			playPluginVideo(server, selected)
                else
                	showNextPosterScreen(currentTitle, selected)
                endif
            else if msg.isListItemInfo() then
            	print "list item info"
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

    return 0

End Function

Function SetListStyle(screen, viewGroup, contentType)
    print "View group:";viewGroup
    print "Content type:";contentType
	listStyle = "arced-square"
    displayMode = "scale-to-fit"
    if viewGroup = "episode" AND contentType = "episode" then
    	listStyle = "flat-episodic"
    	displayMode = "zoom-to-fill"
    else if viewGroup = "Details" then
    	listStyle = "arced-square"
    	displayMode = "scale-to-fit"
    else if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" then
    	listStyle = "arced-portrait"
    endif
    screen.SetListStyle(listStyle)
    screen.SetListDisplayMode(displayMode)
End Function

Function showNextPosterScreen(currentTitle, selected As Object) As Dynamic
    if validateParam(selected, "roAssociativeArray", "showNextPosterScreen") = false return -1
    screen = preShowPosterScreen(selected.Title, currentTitle)
    showPosterScreen(screen, selected)
    return 0
End Function

Function displaySpringboardScreen(currentTitle, contentList, index)
    print "Current title:";currentTitle
	selected = contentList[index]
	screen = preShowSpringboardScreen(selected, currentTitle, "")
	showSpringboardScreen(screen, contentList, index)
End Function
