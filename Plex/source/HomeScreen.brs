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
	print "About to show home screen"
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
	
	'** Prefs
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
                displaySection(section, screen)
            else if msg.isScreenClosed() then
                return -1
            end if
        end If
    end while

    return 0

End Function

Function displaySection(section As Object, homeScreen As Object) As Dynamic
    if validateParam(section, "roAssociativeArray", "displaySection") = false return -1
    
    if section.key = "globalsearch" then
    	queryString = getQueryString()
    	if len(queryString) > 0 then
    		screen = preShowSearchPosterScreen(section.Title, "")
    		showSearchPosterScreen(screen, section.server, queryString)
    		'showSearchGridScreen(section.server, queryString)
    	end if
    else if section.key = "prefs" then
    	Preferences(homeScreen)  
    else
    	screen = preShowPosterScreen(section.Title, "")
    	showPosterScreen(screen, section)
    	'showGridScreen(section)
    endif
    return 0
End Function

Function Preferences(homeScreen)

	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(false)
	dialog.SetTitle("Preferences")
	dialog.AddButton(1, "Plex Media Servers")
	dialog.AddButton(2, "Quality")
	dialog.AddButton(3, "Tweaks")
	dialog.AddButton(4, "Close Preferences")
	dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
				if msg.getIndex() = 1 then
					ConfigureMediaServers()
        			dialog.close()
        			  
    				homeScreen.Close()
    				screen=preShowHomeScreen("", "")
    				showHomeScreen(screen, PlexMediaServers())

				else if msg.getIndex() = 2 then
        			ConfigureQuality()
				else if msg.getIndex() = 3 then
        			Tweaks(homeScreen)
        			else if msg.getIndex() = 4 then
        			dialog.close()

        		end if
			end if 
		end if
	end while
End Function

Function Tweaks(homeScreen)

	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(false)
	dialog.SetTitle("Tweaks")
	dialog.AddButton(1, "H264 Levels")
	dialog.AddButton(2, "Channels and Search")
	'dialog.AddButton(3, "SRT Subtitles")
	dialog.AddButton(4, "Close Tweaks")
	dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
				if msg.getIndex() = 1 then
        			H264Level()
				else if msg.getIndex() = 2 then
        			ChannelsAndSearch()
				'else if msg.getIndex() = 3 then
        			'SRTSubtitles()
        			else if msg.getIndex() = 4 then
        			dialog.close()
        		end if
			end if 
		end if
	end while
End Function


Function ConfigureMediaServers()
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(false)
	dialog.SetTitle("Plex Media Servers") 
	dialog.setText("Manage Plex Media Servers")
	
	dialog.AddButton(1, "Close manage servers dialog")
	dialog.AddButton(2, "Add server manually")
	dialog.AddButton(3, "Discover servers")
	dialog.AddButton(4, "Remove all servers")
	
	fixedSections = 4
	buttonCount = fixedSections + 1
	for each server in PlexMediaServers()
		title = "Remove "+server.name + " ("+server.serverUrl+")"
		dialog.AddButton(buttonCount, title)
		buttonCount = buttonCount + 1
	next
	
	dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				print "Manage servers closed event"
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
				if msg.getIndex() = 1 then
					print "Closing dialog"
				else if msg.getIndex() = 2 then
					address = AddServerManually()
					print "Returned from add server manually:";address
					if address <> invalid then
						AddUnnamedServer(address)
					end if
					
					' Not sure why this is needed here. It appears that exiting the keyboard
					' dialog removes all dialogs then locks up screen. Redrawing the home screen
					' works around it.
    				screen=preShowHomeScreen("", "")
    				showHomeScreen(screen, PlexMediaServers())
				else if msg.getIndex() = 3 then
        			DiscoverPlexMediaServers()
        		else if msg.getIndex() = 4 then
        			RemoveAllServers()
        		else
        			RemoveServer(msg.getIndex()-(fixedSections+1))
        		end if
        		dialog.close()
			end if 
		end if
	end while
End Function

Function AddServerManually()
	port = CreateObject("roMessagePort") 
	keyb = CreateObject("roKeyboardScreen")    
	keyb.SetMessagePort(port)
    keyb.SetDisplayText("Enter Host Name or IP without http:// or :32400")
	keyb.SetMaxLength(80)
	keyb.AddButton(1, "Done") 
	keyb.AddButton(2, "Close")
	keyb.setText("")
	keyb.Show()
	while true 
		msg = wait(0, keyb.GetMessagePort()) 
		if type(msg) = "roKeyboardScreenEvent"
			if msg.isScreenClosed() then
				print "Exiting keyboard dialog screen"
			   	return invalid
			else if msg.isButtonPressed() then
				if msg.getIndex() = 1 then
					return keyb.GetText()
       			end if
       			return invalid
			end if 
		end if
	end while
End Function

Function ConfigureQuality()
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(false)
	dialog.SetTitle("Quality Settings") 
	dialog.setText("Choose quality setting. Higher settings produce better video quality but require more network bandwidth.")
	buttonCommands = CreateObject("roAssociativeArray")
	qualities = CreateObject("roArray", 6 , true)
	
	qualities.Push("720 kbps, 320p") 'N=1, Q=4
	qualities.Push("1.5 Mbps, 480p") 'N=2, Q=5
	qualities.Push("2.0 Mbps, 720p") 'N=3, Q=6
	qualities.Push("3.0 Mbps, 720p") 'N=4, Q=7
	qualities.Push("4.0 Mbps, 720p") 'N=5, Q=8
	qualities.Push("8.0 Mbps, 1080p") 'N=6, Q=9
	
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
		if current = (3 + buttonCount).tostr() then
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
        			quality = (3 + msg.getIndex()).tostr()
        		end if
        		print "Set selected quality to ";quality
        		RegWrite("quality", quality, "preferences")
				dialog.close()
			end if 
		end if
	end while
End Function

Function H264Level()
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(false)
	dialog.SetTitle("H264 Level") 
	dialog.setText("H264 Encoding Level. Set to Maximum to allow more media to be streamed without transcoding. If you have troubles playing some videos, set back to Default.")
	buttonCommands = CreateObject("roAssociativeArray")
	levels = CreateObject("roArray", 5 , true)
	
	levels.Push("Level 4.0 (Default)") 'N=1
	levels.Push("Level 4.1") 'N=2
	levels.Push("Level 4.2") 'N=3
	levels.Push("Level 5.0") 'N=4
	levels.Push("Level 5.1") 'N=5
	
	if not(RegExists("level", "preferences")) then
		RegWrite("level", "40", "preferences")
	end if

	if RegRead("level", "preferences") = "40" then
		current = "Level 4.0 (Default)"
	else if RegRead("level", "preferences") = "41" then
		current = "Level 4.1"
	else if RegRead("level", "preferences") = "42" then
		current = "Level 4.2"
	else if RegRead("level", "preferences") = "50" then
		current = "Level 5.0"
	else if RegRead("level", "preferences") = "51" then
		current = "Level 5.1"
	end if
	buttonCount = 1
	for each level in levels
		title = level
		if current = level then
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
					level = "40"
				else if msg.getIndex() = 2 then
					level = "41"
				else if msg.getIndex() = 3 then
					level = "42"
				else if msg.getIndex() = 4 then
					level = "50"
				else if msg.getIndex() = 5 then
					level = "51"
				end if
        		end if
        		print "Set selected level to ";level
        		RegWrite("level", level, "preferences")
				dialog.close()
			end if 
	end while
End Function

Function ChannelsAndSearch()
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(false)
	dialog.SetTitle("Channels and Search") 
	dialog.setText("Enable/Disable 'Channel' and 'Search' options showing up on the main screen.")
	buttonCommands = CreateObject("roAssociativeArray")
	options = CreateObject("roArray", 2 , true)
	
	options.Push("Enabled (Default)") 'N=1
	options.Push("Disabled") 'N=2

	if not(RegExists("ChannelsAndSearch", "preferences")) then
		RegWrite("ChannelsAndSearch", "1", "preferences")
	end if
	
	if RegRead("ChannelsAndSearch", "preferences") = "1" then
		current = "Enabled (Default)"
	else if RegRead("ChannelsAndSearch", "preferences") = "2" then
		current = "Disabled"
	end if
	buttonCount = 1
	for each option in options
		title = option
		if current = option then
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
				option = msg.getIndex().tostr()	
        		end if
        		RegWrite("ChannelsAndSearch", option, "preferences")
			screen=preShowHomeScreen("", "")
    			showHomeScreen(screen, PlexMediaServers())
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
