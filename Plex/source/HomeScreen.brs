'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")

    grid = createGridScreen(viewController)
    grid.SetStyle("flat-square")
    grid.Screen.SetDisplayMode("photo-fit")
    grid.Screen.SetUpBehaviorAtTopRow("stop")
    grid.Loader = obj
    grid.MessageHandler = obj

    ' Standard properties for all our Screen types
    obj.Item = invalid
    obj.Screen = grid
    obj.ViewController = viewController

    obj.Show = showHomeScreen
    obj.Refresh = refreshHomeScreen

    obj.ShowPreferencesScreen = showPreferencesScreen
    
    obj.ShowMediaServersScreen = showMediaServersScreen
    obj.ShowManualServerScreen = showManualServerScreen
    obj.ShowFivePointOneScreen = showFivePointOneScreen
    obj.ShowQualityScreen = showQualityScreen
    obj.ShowH264Screen = showH264Screen
    obj.ShowChannelsAndSearchScreen = showChannelsAndSearchScreen

    obj.Servers = {}

    ' Data loader interface used by the grid screen
    obj.GetContent = homeGetContent
    obj.LoadMoreContent = homeLoadMoreContent
    obj.GetLoadStatus = homeGetLoadStatus
    obj.GetNames = homeGetNames
    obj.HandleMessage = homeHandleMessage

    ' The home screen owns the myPlex manager
    obj.myplex = createMyPlexManager()

    return obj
End Function

Function refreshHomeScreen()
    ClearPlexMediaServers()
    m.contentArray = []
    m.RowNames = []
    m.PendingRequests = {}

    ' Get the list of servers that have been configured/discovered. Servers
    ' found through myPlex are retrieved separately. Once requests to the
    ' servers complete, the full list of validated servers indexed by machine
    ' ID is maintained by the ServerManager.
    configuredServers = PlexMediaServers()

    print "Setting up home screen content, server count:"; configuredServers.Count()

    ' Request more information about all of our configured servers, to make
    ' sure we get machine IDs and friendly names.
    for each server in configuredServers
        req = server.CreateRequest("", "/")
        req.SetPort(m.Screen.Port)
        req.AsyncGetToString()

        obj = {}
        obj.request = req
        obj.requestType = "server"
        obj.server = server
        m.PendingRequests[str(req.GetIdentity())] = obj
    next

    if m.myplex.IsSignedIn then
        req = m.myplex.CreateRequest("", "/pms/servers")
        req.SetPort(m.Screen.Port)
        req.AsyncGetToString()

        obj = {}
        obj.request = req
        obj.requestType = "servers"
        m.PendingRequests[str(req.GetIdentity())] = obj
    end if

    ' Sections, across all servers
    m.SectionsRow = m.contentArray.Count()
    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0
    for each server in configuredServers
        obj = CreateObject("roAssociativeArray")
        obj.server = server
        obj.key = "/library/sections"
        status.toLoad.AddTail(obj)
    next
    m.contentArray.Push(status)
    m.RowNames.Push("Library Sections")

    ' Recently used channels, across all servers
    m.ChannelsRow = m.contentArray.Count()
    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0
    for each server in configuredServers
        obj = CreateObject("roAssociativeArray")
        obj.server = server
        obj.key = "/channels/recentlyViewed"

        allChannels = CreateObject("roAssociativeArray")
        allChannels.Title = "More Channels"
        if configuredServers.Count() > 1 then
            allChannels.ShortDescriptionLine2 = "All channels on " + server.name
        else
            allChannels.ShortDescriptionLine2 = "All channels"
        end if
        allChannels.Description = allChannels.ShortDescriptionLine2
        allChannels.server = server
        allChannels.sourceUrl = ""
        allChannels.Key = "/channels/all"
        'allChannels.contentType = ...
        allChannels.SDPosterURL = "file://pkg:/images/plex.jpg"
        allChannels.HDPosterURL = "file://pkg:/images/plex.jpg"
        obj.item = allChannels

        status.toLoad.AddTail(obj)
    next
    m.contentArray.Push(status)
    m.RowNames.Push("Channels")

    ' TODO(schuyler): Queue

    ' Shared sections
    m.SharedSectionsRow = m.contentArray.Count()
    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0
    if m.myplex.IsSignedIn then
        obj = CreateObject("roAssociativeArray")
        obj.server = m.myplex
        obj.key = "/pms/system/library/sections"
        status.toLoad.AddTail(obj)
    end if
    m.contentArray.Push(status)
    m.RowNames.Push("Shared Library Sections")

    ' Misc: global search, preferences, channel directory
    m.RowNames.Push("Miscellaneous")
    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0
    ' TODO: Search

    ' Channel directory for each server
    for each server in configuredServers
        channels = CreateObject("roAssociativeArray")
        channels.server = server
        channels.sourceUrl = ""
        channels.key = "/system/appstore"
        channels.Title = "Channel Directory"
        if configuredServers.Count() > 1 then
            allChannels.ShortDescriptionLine2 = "Browse channels to install on " + server.name
        else
            allChannels.ShortDescriptionLine2 = "Browse channels to install"
        end if
        channels.Description = channels.ShortDescriptionLine2
        channels.SDPosterURL = "file://pkg:/images/plex.jpg"
        channels.HDPosterURL = "file://pkg:/images/plex.jpg"
        'channels.contentType = ...

        status.content.Push(channels)
    next

    '** Prefs
    prefs = CreateObject("roAssociativeArray")
    prefs.sourceUrl = ""
    prefs.ContentType = "prefs"
    prefs.Key = "globalprefs"
    prefs.Title = "Preferences"
    prefs.ShortDescriptionLine1 = "Preferences"
    prefs.SDPosterURL = "file://pkg:/images/prefs.jpg"
    prefs.HDPosterURL = "file://pkg:/images/prefs.jpg"
    status.content.Push(prefs)

    m.contentArray.Push(status)

    if type(m.Screen.Screen) = "roGridScreen" then
        m.Screen.Screen.SetFocusedListItem(0, 0)
    else
        m.Screen.Screen.SetFocusedListItem(0)
    end if
End Function

Function showHomeScreen() As Integer
    m.Refresh()
    ret = m.Screen.Show()

    for each id in m.PendingRequests
        m.PendingRequests[id].request.AsyncCancel()
    next
    m.PendingRequests.Clear()

    return ret
End Function

Function showPreferencesScreen()
	port = CreateObject("roMessagePort") 

    manifest = ReadAsciiFile("pkg:/manifest")
    lines = manifest.Tokenize(chr(10))
    aa = {}
    for each line in lines
        entry = line.Tokenize("=")
        aa.AddReplace(entry[0],entry[1])
    end for
    
	
	
	
	
	
	
	ls = CreateObject("roListScreen")
	ls.SetMEssagePort(port)
	ls.setTitle("Preferences v."+aa["version"])
	ls.setheader("Set Plex Channel Preferences")
	print "Quality:";currentQualityTitle
	ls.SetContent([{title:"Plex Media Servers"},
		{title:"Quality: "+getCurrentQualityName()},
		{title:"H264 Level: " + getCurrentH264Level()},
		{title:"Channels and Search: " + getCurrentChannelsAndSearchSetting().label},
		{title:"5.1 Support: " + getCurrentFiveOneSetting()},
		{title:"Close Preferences"}])
	
	ls.show()
	
    while true 
        msg = wait(0, ls.GetMessagePort())         
        if type(msg) = "roListScreenEvent"
			'print "Event: ";type(msg)
            'print msg.GetType(),msg.GetIndex(),msg.GetData()
            if msg.isScreenClosed() then
                ls.close()
                exit while
            else if msg.isListItemSelected() then
                if msg.getIndex() = 0 then
                    m.ShowMediaServersScreen()                    
                    m.Refresh()
                else if msg.getIndex() = 1 then
                    m.ShowQualityScreen()
                    ls.setItem(msg.getIndex(), {title:"Quality: "+ getCurrentQualityName() })
                else if msg.getIndex() = 2 then
                    m.ShowH264Screen()
                    ls.setItem(msg.getIndex(), {title:"H264 Level: " + getCurrentH264Level()})
                else if msg.getIndex() = 3 then
                    m.ShowChannelsAndSearchScreen()
                    ls.setItem(msg.getIndex(), {title:"Channels and Search: " + getCurrentChannelsAndSearchSetting().label})
                else if msg.getIndex() = 4 then
                     m.ShowFivePointOneScreen()
                     ls.setItem(msg.getIndex(), {title:"5.1 Support: " + getCurrentFiveOneSetting()})
                else if msg.getIndex() = 5 then
                    ls.close()
                end if
            end if 
        end if
    end while
End Function

Function showMediaServersScreen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen")
	ls.SetMessagePort(port)
	ls.SetTitle("Plex Media Servers") 
	ls.setHeader("Manage Plex Media Servers")
	ls.SetContent([{title:"Close Manage Servers"},
		{title: getCurrentMyPlexLabel(m.myplex)},
		{title: "Add Server Manually"},
		{title: "Discover Servers"},
		{title: "Remove All Servers"}])

	fixedSections = 4
	buttonCount = fixedSections + 1
    servers = RegRead("serverList", "servers")
    if servers <> invalid
        serverTokens = strTokenize(servers, "{")
        counter = 0
        for each token in serverTokens
            print "Server token:";token
            serverDetails = strTokenize(token, "\")

		    itemTitle = "Remove "+serverDetails[1] + " ("+serverDetails[0]+")"
		    ls.AddContent({title: itemTitle})
		    buttonCount = buttonCount + 1
        end for
    end if

	ls.Show()
	while true 
        msg = wait(0, ls.GetMessagePort()) 
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed() then
                print "Manage servers closed event"
                exit while
             else if msg.isListItemSelected() then
                if msg.getIndex() = 0 then
                    print "Closing Manage Servers"
                    ls.close()
                else if msg.getIndex() = 1 then
                    if m.myplex.IsSignedIn then
                        m.myplex.Disconnect()
                    else
                        m.myplex.ShowPinScreen()
                    end if
                    ls.SetItem(msg.getIndex(), {title: getCurrentMyPlexLabel(m.myplex)})
                else if msg.getIndex() = 2 then
                    m.ShowManualServerScreen()

                    ' UPDATE: I'm not seeing this problem, but I'm loathe to remove such a specific workaround...
                    ' Not sure why this is needed here. It appears that exiting the keyboard
                    ' dialog removes all dialogs then locks up screen. Redrawing the home screen
                    ' works around it.
                    'screen=preShowHomeScreen("", "")
                    'showHomeScreen(screen, PlexMediaServers())
                else if msg.getIndex() = 3 then
                    DiscoverPlexMediaServers()
                    m.showMediaServersScreen()
                    ls.setFocusedListItem(0)
                    ls.close()
                else if msg.getIndex() = 4 then
                    RemoveAllServers()
                    m.showMediaServersScreen()
                    ls.setFocusedListItem(0)
                    ls.close()
                                        
                else
                    RemoveServer(msg.getIndex()-(fixedSections+1))
                    ls.removeContent(msg.getIndex())
                    ls.setFocusedListItem(msg.getIndex() -1)
                end if
            end if 
        end if
	end while
End Function

Sub showManualServerScreen()
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
        if type(msg) = "roKeyboardScreenEvent" then
            if msg.isScreenClosed() then
                print "Exiting keyboard dialog screen"
                return
            else if msg.isButtonPressed() then
                if msg.getIndex() = 1 then
                    if (AddUnnamedServer(keyb.GetText())) then
                        return
                    end if
                end if
            end if 
        end if
    end while
End Sub

Function showFivePointOneScreen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("5.1 Support") 
	ls.setHeader("5.1 audio is only supported on the Roku 2 (4.x) firmware. "+chr(10)+"This setting will be ignored if that firmware is not detected.")

	buttonCommands = CreateObject("roAssociativeArray")

	fiveone = CreateObject("roArray", 6 , true)
	fiveone.Push("Enabled")
	fiveone.Push("Disabled")

	if not(RegExists("fivepointone", "preferences")) then
		RegWrite("fivepointone", "1", "preferences")
	end if
	current = RegRead("fivepointone", "preferences")

	for each value in fiveone
		fiveoneTitle = value
		ls.AddContent({title: fiveoneTitle})
	next
	ls.setFocusedListItem(current.toint() -1)
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
        		fiveone = (msg.getIndex()+1).tostr()
        		print "Set 5.1 support to ";fiveone
        		RegWrite("fivepointone", fiveone, "preferences")
				ls.close()
			end if 
		end if
	end while
End Function

Function showQualityScreen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen")
	ls.SetMessagePort(port)
	ls.SetTitle("Quality Settings") 
	ls.setHeader("Higher settings produce better video quality but require more network bandwidth.")
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
	
	
	for each quality in qualities
		listTitle = quality		
		ls.AddContent({title: listTitle})
	next
	ls.setFocusedListItem(current.toint()-4)
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					quality = "Auto"
				else
        			quality = (4 + msg.getIndex()).tostr()
        		end if
        		print "Set selected quality to ";quality
        		RegWrite("quality", quality, "preferences")
				ls.close()
				exit while
			end if 
		end if
	end while
End Function

Function showH264Screen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("H264 Level") 
	ls.setHeader("Use specific H264 level. Only 4.0 is officially supported.")
	
	buttonCommands = CreateObject("roAssociativeArray")
	levels = CreateObject("roArray", 5 , true)
	
	levels.Push("Level 4.0 (Supported)") 'N=1
	levels.Push("Level 4.1") 'N=2
	levels.Push("Level 4.2") 'N=3
	levels.Push("Level 5.0") 'N=4
	levels.Push("Level 5.1") 'N=5
	
	if not(RegExists("level", "preferences")) then
		RegWrite("level", "40", "preferences")
	end if

	current = "Level 4.0 (Default)"
	selected = 0
	if RegRead("level", "preferences") = "40" then
		current = "Level 4.0 (Default)"
		selected = 0
	else if RegRead("level", "preferences") = "41" then
		current = "Level 4.1"
		selected = 1
	else if RegRead("level", "preferences") = "42" then
		current = "Level 4.2"
		selected = 2
	else if RegRead("level", "preferences") = "50" then
		current = "Level 5.0"
		selected = 3
	else if RegRead("level", "preferences") = "51" then
		current = "Level 5.1"
		selected = 4
	end if
	for each level in levels
		levelTitle = level		
		ls.AddContent({title: levelTitle})		
	next
	ls.setFocusedListItem(selected)
	ls.Show()
	while true 
		msg = wait(0, ls.GetMessagePort()) 
		if type(msg) = "roListScreenEvent"
			if msg.isScreenClosed() then
				ls.close()
				exit while
			else if msg.isListItemSelected() then
				if msg.getIndex() = 0 then
					level = "40"
				else if msg.getIndex() = 1 then
					level = "41"
				else if msg.getIndex() = 2 then
					level = "42"
				else if msg.getIndex() = 3 then
					level = "50"
				else if msg.getIndex() = 4 then
					level = "51"
				end if
        		print "Set selected level to ";level
        		RegWrite("level", level, "preferences")
				ls.close()
			end if
		end if 
	end while
End Function

Function showChannelsAndSearchScreen()
	port = CreateObject("roMessagePort") 
	ls = CreateObject("roListScreen") 
	ls.SetMessagePort(port)
	ls.SetTitle("Channels and Search") 
	ls.setHeader("Enable/Disable 'Channel' and 'Search' options on the main screen.")
	
	buttonCommands = CreateObject("roAssociativeArray")
	
	
	
	options = CreateObject("roArray", 2 , true)	
	options.Push("Enabled (Default)") 'N=1
	options.Push("Disabled") 'N=2
	
	current = getCurrentChannelsAndSearchSetting()
	
	for each option in options
		buttonTitle = option
		ls.AddContent({title:buttonTitle})
	next
	ls.SetFocusedListItem(current.value.toint() -1)
	ls.Show()
	while true 
            msg = wait(0, ls.GetMessagePort()) 
            if type(msg) = "roListScreenEvent"
                if msg.isScreenClosed() then
                    ls.close()
                    exit while
                else if msg.isListItemSelected() then
                    option = (msg.getIndex()+1).tostr()	
                    RegWrite("ChannelsAndSearch", option, "preferences")
                    ls.Close()
                    m.Refresh()
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

Function homeGetContent(index)
    return m.contentArray[index].content
End Function

Function homeLoadMoreContent(focusedIndex, extraRows=0)
    status = invalid
    extraRowsAlreadyLoaded = true
    for i = 0 to extraRows
        index = focusedIndex + i
        if index >= m.contentArray.Count() then
            exit for
        else if m.contentArray[index].loadStatus = 0 OR m.contentArray[index].toLoad.Count() > 0 then
            if status = invalid then
                status = m.contentArray[index]
                loadingRow = index
            else
                extraRowsAlreadyLoaded = false
                exit for
            end if
        end if
    end for

    if status = invalid then return true

    if NOT m.myplex.IsSignedIn then
        m.Screen.OnDataLoaded(m.SharedSectionsRow, [], 0, 0)
    end if

    ' If we have something to load, kick off all the requests asynchronously
    ' now. Otherwise return according to whether or not additional rows have
    ' requests that need to be kicked off. As a special case, if there's
    ' nothing to load and no pending requests, we must be in a row with static
    ' content, tell the screen it's been loaded.

    if status.toLoad.Count() > 0 then
        status.loadStatus = 1

        numRequests = 0
        for each toLoad in status.toLoad
            req = toLoad.server.CreateRequest("", toLoad.key)
            req.SetPort(m.Screen.Port)
            toLoad.request = req
            toLoad.row = loadingRow
            toLoad.requestType = "row"
            m.PendingRequests[str(req.GetIdentity())] = toLoad

            if req.AsyncGetToString() then
                status.pendingRequests = status.pendingRequests + 1
                numRequests = numRequests + 1
            end if
        next

        status.toLoad.Clear()

        print "Successfully kicked off"; numRequests; " requests for row"; loadingRow; ", pending requests now:"; status.pendingRequests
    else if status.pendingRequests > 0 then
        status.loadStatus = 1
        print "No additional requests to kick off for row"; loadingRow; ", pending request count:"; status.pendingRequests
    else
        status.loadStatus = 2
        m.Screen.OnDataLoaded(loadingRow, status.content, 0, status.content.Count())
    end if

    return extraRowsAlreadyLoaded
End Function

Function homeHandleMessage(msg) As Boolean
    ' We only handle URL events, leave everything else to the screen
    if type(msg) <> "roUrlEvent" OR msg.GetInt() <> 1 then return false

    id = msg.GetSourceIdentity()
    request = m.PendingRequests[str(id)]
    if request = invalid then return false
    m.PendingRequests.Delete(str(id))

    if request.requestType = "row" then
        status = m.contentArray[request.row]
        status.pendingRequests = status.pendingRequests - 1
    end if

    if msg.GetResponseCode() <> 200 then
        print "Got a"; msg.GetResponseCode(); " response from "; request.request.GetUrl(); " - "; msg.GetFailureReason()
        return true
    end if

    xml = CreateObject("roXMLElement")
    xml.Parse(msg.GetString())

    if request.requestType = "row" then
        response = CreateObject("roAssociativeArray")
        response.xml = xml
        response.server = request.server
        response.sourceUrl = request.request.GetUrl()
        container = createPlexContainerForXml(response)
        countLoaded = container.Count()

        startItem = status.content.Count()

        if AreMultipleValidatedServers() then
            serverStr = " on " + request.server.name
        else
            serverStr = ""
        end if

        items = container.GetMetadata()
        for each item in items
            add = true

            ' A little weird, but sections will only have owned="1" on the
            ' myPlex request, so we ignore them here since we should have
            ' also requested them from the server directly.
            if item.Owned = "1" then
                add = false
            else if item.MachineID <> invalid then
                server = GetPlexMediaServer(item.MachineID)
                if server <> invalid then
                    print "Found a server for the section: "; item.Title; " on "; server.name
                    item.server = server
                    serverStr = " on " + server.name
                else
                    print "Found a shared section for an unknown server: "; item.MachineID
                    add = false
                end if
            end if

            if NOT add then
            else if item.Type = "channel" then
                channelType = Mid(item.key, 2, 5)
                if channelType = "music" then
                    item.ShortDescriptionLine2 = "Music channel" + serverStr
                else if channelType = "photo" then
                    item.ShortDescriptionLine2 = "Photo channel" + serverStr
                else if channelType = "video" then
                    item.ShortDescriptionLine2 = "Video channel" + serverStr
                else
                    print "Skipping unsupported channel type: "; channelType
                    add = false
                end if
            else if item.Type = "movie" then
                item.ShortDescriptionLine2 = "Movie section" + serverStr
            else if item.Type = "show" then
                item.ShortDescriptionLine2 = "TV section" + serverStr
            else if item.Type = "artist" then
                item.ShortDescriptionLine2 = "Music section" + serverStr
            else if item.Type = "photo" then
                item.ShortDescriptionLine2 = "Photo section" + serverStr
            else
                print "Skipping unsupported section type: "; item.Type
                add = false
            end if

            if add then
                item.Description = item.ShortDescriptionLine2

                ' Normally thumbnail requests will have an X-Plex-Token header
                ' added as necessary by the screen, but we can't do that on the
                ' home screen because we're showing content from multiple
                ' servers.
                if item.SDPosterURL <> invalid AND item.server <> invalid AND item.server.AccessToken <> invalid then
                    item.SDPosterURL = item.SDPosterURL + "&X-Plex-Token=" + item.server.AccessToken
                    item.HDPosterURL = item.HDPosterURL + "&X-Plex-Token=" + item.server.AccessToken
                end if

                status.content.Push(item)
            end if
        next

        if request.item <> invalid then
            countLoaded = countLoaded + 1
            status.content.Push(request.item)
        end if

        if status.toLoad.Count() = 0 AND status.pendingRequests = 0 then
            status.loadStatus = 2
        end if

        m.Screen.OnDataLoaded(request.row, status.content, startItem, countLoaded)
    else if request.requestType = "server" then
        request.server.name = xml@friendlyName
        request.server.machineID = xml@machineIdentifier
        request.server.owned = true
        if xml@version <> invalid then
            request.server.SupportsAudioTranscoding = ServerVersionCompare(xml@version, [0, 9, 6])
        end if
        PutPlexMediaServer(request.server)

        print "Fetched additional server information ("; request.server.name; ", "; request.server.machineID; ")"
        print "URL: "; request.server.serverUrl
        print "Server supports audio transcoding: "; request.server.SupportsAudioTranscoding
    else if request.requestType = "servers" then
        for each serverElem in xml.Server
            ' If we already have a server for this machine ID then disregard
            if GetPlexMediaServer(xml@machineIdentifier) = invalid then
                server = newPlexMediaServer("http://" + serverElem@host + ":" + serverElem@port, "")
                server.machineID = serverElem@machineIdentifier
                server.AccessToken = firstOf(serverElem@accessToken, m.myplex.AuthToken)

                if serverElem@owned = "1" then
                    server.name = serverElem@name
                    server.owned = true

                    ' An owned server that we didn't have configured, request
                    ' its sections and channels now.
                    sections = CreateObject("roAssociativeArray")
                    sections.server = server
                    sections.key = "/library/sections"
                    sections.row = m.SectionsRow
                    sections.requestType = "row"
                    req = server.CreateRequest("", sections.key)
                    req.SetPort(m.Screen.Port)
                    req.AsyncGetToString()
                    sections.request = req
                    m.contentArray[sections.row].pendingRequests = m.contentArray[sections.row].pendingRequests + 1
                    m.PendingRequests[str(req.GetIdentity())] = sections

                    channels = CreateObject("roAssociativeArray")
                    channels.server = server
                    channels.key = "/channels/recentlyViewed"
                    channels.row = m.ChannelsRow
                    channels.requestType = "row"
                    req = server.CreateRequest("", channels.key)
                    req.SetPort(m.Screen.Port)
                    req.AsyncGetToString()
                    channels.request = req
                    m.contentArray[channels.row].pendingRequests = m.contentArray[channels.row].pendingRequests + 1
                    m.PendingRequests[str(req.GetIdentity())] = channels

                    allChannels = CreateObject("roAssociativeArray")
                    allChannels.Title = "More Channels"
                    allChannels.ShortDescriptionLine2 = "All channels on " + server.name
                    allChannels.Description = allChannels.ShortDescriptionLine2
                    allChannels.server = server
                    allChannels.sourceUrl = ""
                    allChannels.Key = "/channels/all"
                    allChannels.SDPosterURL = "file://pkg:/images/plex.jpg"
                    allChannels.HDPosterURL = "file://pkg:/images/plex.jpg"
                    channels.item = allChannels
                else
                    server.name = serverElem@name + " (shared by " + serverElem@sourceTitle + ")"
                end if
                PutPlexMediaServer(server)

                print "Added shared server: "; server.name
            end if
        next
    end if

    print "Remaining pending requests:"
    for each id in m.PendingRequests
        print m.PendingRequests[id].request.GetUrl()
    next

    return true
End Function

Function homeGetLoadStatus(index) As Integer
    return m.contentArray[index].loadStatus
End Function

Function homeGetNames()
    return m.RowNames
End Function

Function getCurrentQualityName()
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
	currentQuality = RegRead("quality", "preferences")
	if currentQuality = "Auto" then
		currentQualityTitle = "Auto"
	else 
		currentQualityIndex = currentQuality.toint() -4
		currentQualityTitle = qualities[currentQualityIndex]
	endif
	return currentQualityTitle
End Function

Function getCurrentH264Level()
	if not(RegExists("level", "preferences")) then
		RegWrite("level", "40", "preferences")
	end if

	currentLevel = "Level 4.0 (Default)"
	if RegRead("level", "preferences") = "40" then
		currentLevel = "Level 4.0 (Default)"
	else if RegRead("level", "preferences") = "41" then
		currentLevel = "Level 4.1"
	else if RegRead("level", "preferences") = "42" then
		currentLevel = "Level 4.2"
	else if RegRead("level", "preferences") = "50" then
		currentLevel = "Level 5.0"
	else if RegRead("level", "preferences") = "51" then
		currentLevel = "Level 5.1"
	end if
	return currentLevel
End Function

Function getCurrentFiveOneSetting()
	fiveone = CreateObject("roArray", 6 , true)
	fiveone.Push("Enabled")
	fiveone.Push("Disabled")
	if not(RegExists("fivepointone", "preferences")) then
		RegWrite("fivepointone", "1", "preferences")
	end if
	current = RegRead("fivepointone", "preferences")
	currentText = fiveone[current.toint()-1]
	if currentText = invalid then
		currentText = ""
	endif
		
	return currentText
End Function


Function getCurrentChannelsAndSearchSetting()
	options = CreateObject("roArray", 2 , true)
	options.Push("Enabled (Default)") 'N=1
	options.Push("Disabled") 'N=2
	
	if not(RegExists("ChannelsAndSearch", "preferences")) then
		RegWrite("ChannelsAndSearch", "1", "preferences")
	end if
	regValue = RegRead("ChannelsAndSearch", "preferences")
	if regValue = "2" then
		current = "Disabled"
    else
		current = "Enabled (Default)"
	end if
	return {label: current, value: regValue}
End Function

Function getCurrentMyPlexLabel(myplex) As String
    if myplex.IsSignedIn then
        return "Disconnect myPlex account (" + myplex.EmailAddress + ")"
    else
        return "Connect myPlex account"
    end if
End Function

