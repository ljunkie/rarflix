
Function showSearchGridScreen(server, query) As Integer
	retrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Searching ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()

    port=CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")
    grid.SetMessagePort(port)
    grid.SetDisplayMode("scale-to-fit")
    
    'grid.SetGridStyle("Flat-Movie")
    grid.SetGridStyle("Flat-Square")
    
	searchResults = server.Search(query)
    grid.SetupLists(searchResults.names.Count()) 
	grid.SetListNames(searchResults.names)
    
    rowCount = 0
    for each content in searchResults.content
   		grid.SetContentList(rowCount, content)
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
                contentSelected = searchResults.content[row][selection]
                contentType = contentSelected.ContentType
                print "Content type in search grid screen:";contentType
                if contentType = "movie" OR contentType = "episode" then
                	grid.close()
                	displaySpringboardScreen("Search Results", searchResults.content[row], selection)
                else if contentType = "series" then
                	grid.close()
                	showNextPosterScreen("Search Results", contentSelected)
                else if contentType = "clip" then
                	grid.close()
        			playPluginVideo(server, contentSelected)
                end if
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while
    return 0
End Function
