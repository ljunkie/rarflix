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
	names = server.GetListNames(queryResponse)
	keys = server.GetListKeys(queryResponse)
	
	middlePoint = 5
	paginationStart = 0
	currentFocus = middlePoint
	contentKey = invalid
	paginationMode = invalid
	if names.Count() > 0 then
		paginationMode = true
	    focusedList = 0
		screen.SetListNames(names)
		screen.SetFocusedList(focusedList)
		contentKey = keys[focusedList]
		contentList = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart)
		screen.SetFocusedListItem(currentFocus)
	else
		paginationMode = false
		contentList = server.GetContent(queryResponse)
		contentType = invalid
		if contentList.Count() > 0 then
			contentType = contentList[0].ContentType
		endif
    	screen.SetContentList(contentList)
		viewGroup = queryResponse.xml@viewGroup
    	SetListStyle(screen, viewGroup, contentType)
    endif
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
        	'* Focus change on the filter bar causes content change
            if msg.isListFocused() then
                if names.Count() > 0 then
					paginationMode = true
					screen.SetContentList(invalid)
                	focusedItem = msg.GetIndex()
                	contentKey = keys[focusedItem]
                	'print "Focused key:";key
                	paginationStart = 0
					contentList = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart)
					screen.SetFocusedListItem(currentFocus)
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
        '* List item focus change causes content scolling via page reload
            else if msg.isListItemFocused() then
            	if paginationMode then
					focused = msg.GetIndex()
					difference = focused - currentFocus
					if focused < middlePoint then
						currentFocus = focused
					endif
					if focused >= middlePoint then
						currentFocus = middlePoint
					endif
					print "Focused:";focused
					print "Diff:";difference
					print "Current focus:";currentFocus
					if difference > 0 then
						paginationStart = paginationStart + 1
						screen.SetFocusedListItem(currentFocus)
						contentList = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart)
					else if difference < 0 then
						paginationStart = paginationStart - 1
						if paginationStart < 0 then
							paginationStart = 0
						endif
						screen.SetFocusedListItem(currentFocus)
						contentList = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart)
					endif
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

Function PopulateContentList(server, screen, sourceUrl, contentKey, start) As Object
	subSectionResponse = server.GetPaginatedQueryResponse(sourceUrl, contentKey, start, 11)
	contentList = server.GetContent(subSectionResponse)
	contentType = invalid
	if contentList.Count() > 0 then
		contentType = contentList[0].ContentType
	endif
    screen.SetContentList(contentList)
    viewGroup = subSectionResponse.xml@viewGroup
    SetListStyle(screen, viewGroup, contentType)
    return contentList
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
