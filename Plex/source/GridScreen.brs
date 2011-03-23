'*
'* Initial attempt at a grid screen. 
'*
'* Static content works
'* Pagination does not - I obviously aren't understanding how the subset method is to be used
'* There's a bug in screen navigation that Roku devs say will be fixed in an upcoming
'* release (http://forums.roku.com/viewtopic.php?f=34&t=37984&p=248090&hilit=grid#p248090)
'*
'* Consider it a to be added in the future feature.
'*
Function showGridScreen(section) As Integer
	retrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Retrieving ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()

    port=CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")
    grid.SetMessagePort(port)
    grid.SetDisplayMode("scale-to-fit")
    
    'grid.SetGridStyle("Flat-Movie")
    grid.SetGridStyle("Flat-Square")
    
    print "Section key:"+section.key
    server = section.server
	queryResponse = server.GetQueryResponse(section.sourceUrl, section.key)
	names = server.GetListNames(queryResponse)
	keys = server.GetListKeys(queryResponse)
	
    grid.SetupLists(names.Count()) 
	grid.SetListNames(names)
    
    paginationPageSize = 15
    
    contentArray = []
    rowCount = 0
    for each key in keys
    	print "Page key:";key
    	response = server.GetPaginatedQueryResponse(queryResponse.sourceUrl, key, 0, paginationPageSize)
		'printXML(response.xml, 1)
    	content = server.GetContent(response)
    	emptyContent = CreateObject("roArray", strtoi(response.xml@totalSize), true)
    	count = 0
    	for count = 0 to strtoi(response.xml@totalSize)
    		emptyContent[count] = CreateObject("roAssociativeArray")
     	next
    	grid.setContentList(rowCount, emptyContent)
   		grid.SetContentListSubset(rowCount, content, 0, paginationPageSize)
   		
   		contentArray[rowCount] = []
   		itemCount = 0
   		for each item in content
   			contentArray[rowCount][itemCount] = item
   			itemCount = itemCount + 1
   		next
    	rowCount = rowCount + 1
    next
    grid.show()
    retrieving.close()
	while true
        msg = wait(0, port)
        if type(msg) = "roGridScreenEvent" then
            if msg.isListItemSelected() then
                row = msg.GetIndex()
                selection = msg.getData()
                contentSelected = contentArray[row][selection]
                contentType = contentSelected.ContentType
                print "Content type in grid screen:";contentType
                if contentType = "movie" OR contentType = "episode" then
                	grid.close()
                	displaySpringboardScreen(contentSelected.title, contentArray[row], selection)
                else if contentType = "series" then
                	grid.close()
                	showNextPosterScreen(contentSelected.title, contentSelected)
                else if contentType = "clip" then
                	grid.close()
        			playPluginVideo(server, contentSelected)
                end if
            else if msg.isListItemFocused() then
            	row = msg.GetIndex()
                focused = msg.getData()
                print "Row: ";row
                print "Focused: ";focused
                if focused > contentArray[row].Count() - 5 then
                	
                	print "Count before: ";contentArray[row].Count()
                	response = server.GetPaginatedQueryResponse(queryResponse.sourceUrl, keys[row], contentArray[row].Count(), paginationPageSize)
    				content = server.GetContent(response)
   					grid.SetContentListSubset(row, content, contentArray[row].Count(), paginationPageSize)
    				itemCount = contentArray[row].Count()
   					for each item in content
   						contentArray[row][itemCount] = item
   						itemCount = itemCount + 1
   					next
                	print "Count after: ";contentArray[row].Count()
                	grid.show()
                end if
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while
    return 0
End Function
