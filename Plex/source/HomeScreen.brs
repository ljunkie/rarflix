'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function preShowHomeScreen(breadA=invalid, breadB=invalid) As Object

    if validateParam(breadA, "roString", "preShowHomeScreen", true) = false return -1
    if validateParam(breadA, "roString", "preShowHomeScreen", true) = false return -1

    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
    end if

    screen.SetListStyle("flat-category")
    screen.setListDisplayMode("zoom-to-fill")
    return screen

End Function


Function showHomeScreen(screen, servers) As Integer

    if validateParam(screen, "roPosterScreen", "showHomeScreen") = false return -1
	displayServerName = servers.count() > 1
	sectionList = CreateObject("roArray", 10, true)
	for each server in servers
    	sections = server.GetHomePageContent()
    	for each section in sections
    		if displayServerName then
    			section.Title = section.Title + " ("+server.name+")"
    			section.ShortDescriptionLine1 = section.ShortDescriptionLine1 + " ("+server.name+")"
    		endif
    		sectionList.Push(section)
    	end for
	end for
	
	prefs = CreateObject("roAssociativeArray")
	prefs.server = m
    prefs.sourceUrl = ""
	prefs.ContentType = "series"
	prefs.Key = "prefs"
	prefs.Title = "Preferences"
	prefs.ShortDescriptionLine1 = "Preferences"
	prefs.SDPosterURL = "file://pkg:/images/prefs.jpg"
	prefs.HDPosterURL = "file://pkg:/images/prefs.jpg"
	sectionList.Push(prefs)
	
	
    screen.SetContentList(sectionList)
    screen.Show()
    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            print "showHomeScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex()
            if msg.isListFocused() then
                print "list focused | index = "; msg.GetIndex(); " | category = "; m.curCategory
            else if msg.isListItemSelected() then
                print "list item selected | index = "; msg.GetIndex()
                section = sectionList[msg.GetIndex()]
                print "section selected ";section.Title
                displaySection(section)
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

    return 0

End Function

Function displaySection(section As Object) As Dynamic
    if validateParam(section, "roAssociativeArray", "displaySection") = false return -1
    
    if section.key = "globalsearch" then
    	queryString = getQueryString()
    	if len(queryString) > 0 then
    		screen = preShowSearchPosterScreen(section.Title, "")
    		showSearchPosterScreen(screen, section.server, queryString)
    		'showSearchGridScreen(section.server, queryString)
    	end if
    else if section.key = "prefs" then
    	ChangePreferences()
    else
    	screen = preShowPosterScreen(section.Title, "")
    	showPosterScreen(screen, section)
    	'showGridScreen(section)
    endif
    return 0
End Function

'* One depth preference dialog for now. If we add more preferences make this multi-depth.
Function ChangePreferences()
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(true)
	dialog.SetTitle("Preferences") 
	dialog.setText("Choose quality setting. Higher settings produce better video quality but require more network bandwidth.")
	buttonCommands = CreateObject("roAssociativeArray")
	qualities = CreateObject("roArray", 6 , true)
	
	qualities.Push("Auto")			 'N=1, Q=Auto
	qualities.Push("720 kbps, 320p") 'N=2, Q=4
	qualities.Push("1.5 Mbps, 480p") 'N=3, Q=5
	qualities.Push("2.0 Mbps, 720p") 'N=4, Q=6
	qualities.Push("3.0 Mbps, 720p") 'N=5, Q=7
	qualities.Push("4.0 Mbps, 720p") 'N=6, Q=8
	qualities.Push("8.0 Mbps, 1080p") 'N=7, Q=9
	
	if not(RegExists("quality", "preferences")) then
		RegWrite("quality", "7", "preferences")
	end if
	current = RegRead("quality", "preferences")
	
	buttonCount = 1
	for each quality in qualities
		title = quality
		if current = quality then
			title = "> "+title
		end if
		if current = (2 + buttonCount).tostr() then
			title = "> "+title
		end if
		dialog.AddButton(buttonCount, title)
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
				if msg.getIndex() = 1 then
					quality = "Auto"
				else
        			quality = (2 + msg.getIndex()).tostr()
        		end if
        		print "Set selected quality to ";quality
        		RegWrite("quality", quality, "preferences")
				dialog.close()
			end if 
		end if
	end while
End Function

Function getQueryString() As String
	queryString = ""
	
	searchHistory = CreateObject("roSearchHistory")
	port = CreateObject("roMessagePort") 
	searchScreen = CreateObject("roSearchScreen") 
	searchScreen.SetMessagePort(port)
	searchScreen.SetSearchTerms(searchHistory.GetAsArray())
	searchScreen.show()
	done = false
	while done = false
		msg = wait(0, searchScreen.getMessagePort())
		if type(msg) = "roSearchScreenEvent" then
			if msg.isFullResult() then
				queryString = msg.getMessage()
				if len(queryString) > 0 then
					searchHistory.Push(queryString)
				end if
				done = true
			else if msg.isScreenClosed() then
				done = true
			end if
		end if
	end while
	print "Query string:";queryString
	return queryString
End Function
