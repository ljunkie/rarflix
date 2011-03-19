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
	contentKey = invalid
	paginationMode = names.Count() > 0
	if paginationMode then
	    focusedList = 0
		screen.SetListNames(names)
		screen.SetFocusedList(focusedList)
		contentKey = keys[focusedList]
		contentListArray = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart, invalid)
		contentList = contentListArray[0]
		totalSize = contentListArray[1] 
		screen.SetFocusedListItem(middlePoint)
	else
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
				paginationMode = names.Count() > 0
                if names.Count() > 0 then
					screen.SetContentList(invalid)
                	focusedItem = msg.GetIndex()
                	contentKey = keys[focusedItem]
                	'print "Focused key:";key
                	paginationStart = 0
					contentListArray = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart, totalSize)
					contentList = contentListArray[0]
					totalSize = contentListArray[1] 
					screen.SetFocusedListItem(middlePoint)
                endif
            else if msg.isListItemSelected() then
                selected = contentList[msg.GetIndex()]
                contentType = selected.ContentType
                print "Content type in poster screen:";contentType
                if contentType = "movie" OR contentType = "episode" then
                	displaySpringboardScreen(currentTitle, contentList, msg.GetIndex())
                else if contentType = "clip" then
        			playPluginVideo(server, selected)
        		else if contentType = "album" then
        		    playAlbum(server, selected)
        		else if selected.viewGroup <> invalid AND selected.viewGroup = "Store:Info" then
        			ChannelInfo(selected)
                else
                	showNextPosterScreen(currentTitle, selected)
                endif
                
        '* Scrolling pagination allowing navigation of large libraries.
        '* 
        '* Roku model has a fixed content list containing all the content and navigates by scrolling
        '* through that list by changing the focus point. I've reversed that model by having a
        '* fixed focus point (5) in the middle of a small fixed content list (N=11) and when
        '* focus is moved the content is reloaded from a paginated PMS query.
        '*
        '* This involves more PMS calls but with smaller result list. Also, since the real bottle
        '* neck appears to be the XML parsing, some caching of parsed results could also be
        '* performed to speed things up.
        '* 
            else if msg.isListItemFocused() then
                print "List item focused. Length:";contentList.Count()
            	if paginationMode AND contentList.Count() = 11 then
					focused = msg.GetIndex()
					difference = focused - middlePoint
					if difference <> 0 then
						'print "Difference:";difference
						'print "Old pagination start:";paginationStart
						'print "Total size:";totalSize
						paginationStart = PaginationStartPoint(totalSize, paginationStart, difference)
						'print "New pagination start:";paginationStart
						screen.SetFocusedListItem(middlePoint)
						contentListArray = PopulateContentList(server, screen, queryResponse.sourceUrl, contentKey, paginationStart, totalSize)
					    contentList = contentListArray[0]
					    totalSize = contentListArray[1] 
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

Function ChannelInfo(channel) 

    print "Store info for:";channel
    port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(true)
	dialog.SetTitle(channel.title) 
	dialog.SetText(channel.description) 
	queryResponse = channel.server.GetQueryResponse(channel.sourceUrl, channel.key)
	content = channel.server.GetContent(queryResponse)
	buttonCommands = CreateObject("roAssociativeArray")
	buttonCount = 0
	for each item in content
		buttonTitle = item.title
		dialog.AddButton(buttonCount, buttonTitle)
		buttonCommands[str(buttonCount)+"_key"] = item.key
		buttonCount = buttonCount + 1
	next
	dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
				print "Button pressed:";msg.getIndex()
				commandKey = buttonCommands[str(msg.getIndex())+"_key"]
				print "Command Key:"+commandKey
				dialog.close()
				retrieving = CreateObject("roOneLineDialog")
				retrieving.SetTitle("Please wait ...")
				retrieving.ShowBusyAnimation()
				retrieving.Show()
				commandResponse = channel.server.GetQueryResponse(channel.sourceUrl, commandKey)
				retrieving.Close()
			end if 
		end if
	end while
End Function

'* Calculates new start point which is effectively a modular arithmatic with modulus=size
Function PaginationStartPoint(size, currentStartPoint, difference) As Integer
	newStartPoint = currentStartPoint + difference
	if newStartPoint < 0 then
		newStartPoint = size + newStartPoint
	else if newStartPoint = size then
		newStartPoint = 0
	endif
	return newStartPoint
End Function

Function PopulateContentList(server, screen, sourceUrl, contentKey, start, totalSize) As Object
	pageSize = 11
	'* If we straddle the totalSize boundry split pagination into 2 queries across
	'* the boundry then merge the results to get wrap around
	if totalSize <> invalid AND start + pageSize > totalSize then
		contentList = CreateObject("roArray", pageSize, true)
		firstStart = start
		firstSize = totalSize - start
		firstResponse = server.GetPaginatedQueryResponse(sourceUrl, contentKey, firstStart, firstSize)
    	viewGroup = firstResponse.xml@viewGroup
    	newTotalSize = firstResponse.xml@totalSize
		firstContentList = server.GetContent(firstResponse)
		for each entry in firstContentList
			contentList.Push(entry)
		next
		secondStart = 0
		secondSize = pageSize - firstSize
		secondResponse = server.GetPaginatedQueryResponse(sourceUrl, contentKey, secondStart, secondSize)
		secondContentList = server.GetContent(secondResponse)
		for each entry in secondContentList
			contentList.Push(entry)
		next
	else
		subSectionResponse = server.GetPaginatedQueryResponse(sourceUrl, contentKey, start, pageSize)
    	viewGroup = subSectionResponse.xml@viewGroup
    	newTotalSize = subSectionResponse.xml@totalSize
		contentList = server.GetContent(subSectionResponse)
	endif
	
	contentType = invalid
	if contentList.Count() > 0 then
		contentType = contentList[0].ContentType
	endif
    screen.SetContentList(contentList)
    SetListStyle(screen, viewGroup, contentType)
    
    contentArray = []
    contentArray.Push(contentList)
    if newTotalSize <> invalid then
    	contentArray.Push(strtoi(newTotalSize))
    endif
    return contentArray
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
