'* Displays the content in a poster screen. Can be any content type.

Function preShowSearchPosterScreen(breadA=invalid, breadB=invalid) As Object
    if validateParam(breadA, "roString", "preShowSearchPosterScreen", true) = false return -1
    if validateParam(breadA, "roString", "preShowSearchPosterScreen", true) = false return -1

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


Function showSearchPosterScreen(screen, server, query) As Integer

    if validateParam(screen, "roPosterScreen", "showSearchPosterScreen") = false return -1
	print "show search poster screen with query ";query
	'* Showing the screen before setting content results in the backgroud 'retrieving ...'
	'* screen which I prefer over the dialog box and seems to be the common approach used 
	'* by other Roku apps.
	screen.Show()
	
	focusedIndex = 0
	searchResults = server.Search(query)
	screen.SetListNames(searchResults.names)
	screen.SetFocusedList(0)
	contentList = searchResults.content[focusedIndex]
	screen.SetContentList(contentList)
    screen.show()
	
    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            if msg.isListFocused() then
				print "List focused"
				focusedIndex = msg.GetIndex()
				contentList = searchResults.content[focusedIndex]
				screen.SetContentList(contentList)
            else if msg.isListItemSelected() then
                print "List item selected"
                selectedIndex = msg.GetIndex()
                selectedItem = contentList[selectedIndex]
                print "Selected:";selectedItem.title
                contentType = selectedItem.ContentType
                print "Content type in search poster screen:";contentType
                if contentType = "movie" OR contentType = "episode" then
                	displaySpringboardScreen("Search Results", contentList, selectedIndex)
                else if contentType = "clip" then
        			playPluginVideo(server, selectedItem)
        		else if contentType = "album" then
        		    playAlbum(server, selectedItem)
        		end if
            else if msg.isListItemFocused() then
                print "List item focused"
            else if msg.isListItemInfo() then
            	print "list item info"
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while
    return 0
End Function