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
    obj.Show1080pScreen = show1080pScreen

    ' Data loader interface used by the grid screen
    obj.LoadMoreContent = homeLoadMoreContent
    obj.GetNames = homeGetNames
    obj.HandleMessage = homeHandleMessage

    obj.StartServerRequests = homeStartServerRequests
    obj.InitSectionsRow = homeInitSectionsRow
    obj.InitChannelsRow = homeInitChannelsRow
    obj.InitQueueRow = homeInitQueueRow
    obj.InitSharedRow = homeInitSharedRow
    obj.InitMiscRow = homeInitMiscRow

    ' The home screen owns the myPlex manager
    obj.myplex = createMyPlexManager()

    return obj
End Function

Function refreshHomeScreen()
    ClearPlexMediaServers()
    m.contentArray = []
    m.RowNames = []
    m.PendingRequests = {}
    m.FirstLoad = true

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

        PutPlexMediaServer(server)
    next

    ' Kick off an asynchronous GDM discover.
    m.GDM = createGDMDiscovery(m.Screen.Port)
    if m.GDM = invalid then
        print "Failed to create GDM discovery object"
    end if

    ' Find any servers linked through myPlex
    if m.myplex.IsSignedIn then
        req = m.myplex.CreateRequest("", "/pms/servers")
        req.SetPort(m.Screen.Port)
        req.AsyncGetToString()

        obj = {}
        obj.request = req
        obj.requestType = "servers"
        m.PendingRequests[str(req.GetIdentity())] = obj
    end if

    m.InitChannelsRow(configuredServers)
    m.InitSectionsRow(configuredServers)
    'm.InitQueueRow()
    m.InitSharedRow()
    m.InitMiscRow(configuredServers)

    if type(m.Screen.Screen) = "roGridScreen" then
        m.Screen.Screen.SetFocusedListItem(m.SectionsRow, 0)
    else
        m.Screen.Screen.SetFocusedListItem(m.SectionsRow)
    end if
End Function

Sub homeInitSectionsRow(configuredServers)
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
End Sub

Sub homeInitChannelsRow(configuredServers)
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
End Sub

Sub homeInitQueueRow()
    m.QueueRow = m.contentArray.Count()
    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0
    if m.myplex.IsSignedIn then
        obj = CreateObject("roAssociativeArray")
        obj.server = m.myplex
        obj.requestType = "queue"
        obj.key = "/pms/playlists/queue/unwatched"
        status.toLoad.AddTail(obj)
    end if
    m.contentArray.Push(status)
    m.RowNames.Push("Queue")
End Sub

Sub homeInitSharedRow()
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
End Sub

Sub homeInitMiscRow(configuredServers)
    m.MiscRow = m.contentArray.Count()
    m.RowNames.Push("Miscellaneous")
    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0

    ' Universal search
    univSearch = CreateObject("roAssociativeArray")
    univSearch.sourceUrl = ""
    univSearch.ContentType = "search"
    univSearch.Key = "globalsearch"
    univSearch.Title = "Search"
    univSearch.ShortDescriptionLine1 = "Search"
    univSearch.SDPosterURL = "file://pkg:/images/icon-search.jpg"
    univSearch.HDPosterURL = "file://pkg:/images/icon-search.jpg"
    status.content.Push(univSearch)

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
End Sub

Function showHomeScreen() As Integer
    m.Refresh()
    ret = m.Screen.Show()

    for each id in m.PendingRequests
        m.PendingRequests[id].request.AsyncCancel()
    next
    m.PendingRequests.Clear()

    return ret
End Function

Function homeLoadMoreContent(focusedIndex, extraRows=0)
    if m.FirstLoad then
        m.FirstLoad = false
        if NOT m.myplex.IsSignedIn then
            'm.Screen.OnDataLoaded(m.QueueRow, [], 0, 0)
            m.Screen.OnDataLoaded(m.SharedSectionsRow, [], 0, 0)
        end if

        if type(m.Screen.Screen) = "roGridScreen" then
            m.Screen.Screen.SetFocusedListItem(m.SectionsRow, 0)
        else
            m.Screen.Screen.SetFocusedListItem(m.SectionsRow)
        end if
    end if

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
            toLoad.requestType = firstOf(toLoad.requestType, "row")
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
    if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
        id = msg.GetSourceIdentity()
        request = m.PendingRequests[str(id)]
        if request = invalid then return false
        m.PendingRequests.Delete(str(id))

        if request.row <> invalid then
            status = m.contentArray[request.row]
            status.pendingRequests = status.pendingRequests - 1
        end if

        if msg.GetResponseCode() <> 200 then
            print "Got a"; msg.GetResponseCode(); " response from "; request.request.GetUrl(); " - "; msg.GetFailureReason()
            return true
        else
            print "Got a 200 response from "; request.request.GetUrl(); " (type "; request.requestType; ", row"; request.row; ")"
        end if

        xml = CreateObject("roXMLElement")
        xml.Parse(msg.GetString())

        if request.requestType = "row" then
            response = CreateObject("roAssociativeArray")
            response.xml = xml
            response.server = request.server
            response.sourceUrl = request.request.GetUrl()
            container = createPlexContainerForXml(response)
            countLoaded = 0

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
                    countLoaded = countLoaded + 1
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
        else if request.requestType = "queue" then
            response = CreateObject("roAssociativeArray")
            response.xml = xml
            response.server = GetPrimaryServer()
            response.sourceUrl = request.request.GetUrl()
            container = createPlexContainerForXml(response)

            startItem = status.content.Count()

            items = container.GetMetadata()
            for each item in items
                ' Normally thumbnail requests will have an X-Plex-Token header
                ' added as necessary by the screen, but we can't do that on the
                ' home screen because we're showing content from multiple
                ' servers.
                if item.SDPosterURL <> invalid AND item.server <> invalid AND item.server.AccessToken <> invalid then
                    item.SDPosterURL = item.SDPosterURL + "&X-Plex-Token=" + item.server.AccessToken
                    item.HDPosterURL = item.HDPosterURL + "&X-Plex-Token=" + item.server.AccessToken
                end if

                status.content.Push(item)
            next

            if request.item <> invalid then
                status.content.Push(request.item)
            end if

            status.loadStatus = 2

            m.Screen.OnDataLoaded(request.row, status.content, 0, status.content.Count())
        else if request.requestType = "server" then
            request.server.name = xml@friendlyName
            request.server.machineID = xml@machineIdentifier
            request.server.owned = true
            request.server.online = true
            if xml@version <> invalid then
                request.server.SupportsAudioTranscoding = ServerVersionCompare(xml@version, [0, 9, 6])
            end if
            PutPlexMediaServer(request.server)

            print "Fetched additional server information ("; request.server.name; ", "; request.server.machineID; ")"
            print "URL: "; request.server.serverUrl
            print "Server supports audio transcoding: "; request.server.SupportsAudioTranscoding

            channelDir = CreateObject("roAssociativeArray")
            channelDir.server = request.server
            channelDir.sourceUrl = ""
            channelDir.key = "/system/appstore"
            channelDir.Title = "Channel Directory"
            if AreMultipleValidatedServers() then
                channelDir.ShortDescriptionLine2 = "Browse channels to install on " + request.server.name
            else
                channelDir.ShortDescriptionLine2 = "Browse channels to install"
            end if
            channelDir.Description = channelDir.ShortDescriptionLine2
            channelDir.SDPosterURL = "file://pkg:/images/plex.jpg"
            channelDir.HDPosterURL = "file://pkg:/images/plex.jpg"
            status = m.contentArray[m.MiscRow]
            status.content.Push(channelDir)
            m.Screen.OnDataLoaded(m.MiscRow, status.content, status.content.Count() - 1, 1)
        else if request.requestType = "servers" then
            for each serverElem in xml.Server
                ' If we already have a server for this machine ID then disregard
                if GetPlexMediaServer(xml@machineIdentifier) = invalid then
                    addr = "http://" + serverElem@host + ":" + serverElem@port
                    server = newPlexMediaServer(addr, serverElem@name, serverElem@machineIdentifier)
                    server.AccessToken = firstOf(serverElem@accessToken, m.myplex.AuthToken)

                    if serverElem@owned = "1" then
                        server.name = serverElem@name
                        server.owned = true

                        ' An owned server that we didn't have configured, request
                        ' its sections and channels now.
                        m.StartServerRequests(server)
                    else
                        server.name = serverElem@name + " (shared by " + serverElem@sourceTitle + ")"
                        server.owned = false
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
    else if type(msg) = "roSocketEvent" then
        serverInfo = m.GDM.HandleMessage(msg)
        if serverInfo <> invalid then
            print "GDM discovery found server at "; serverInfo.Url

            existing = GetPlexMediaServer(serverInfo.MachineID)
            if existing <> invalid AND existing.IsConfigured then
                print "GDM discovery ignoring already configured server"
            else
                AddServer(serverInfo.Name, serverInfo.Url, serverInfo.MachineID)
                server = newPlexMediaServer(serverInfo.Url, serverInfo.Name, serverInfo.MachineID)
                server.owned = true
                PutPlexMediaServer(server)
                m.StartServerRequests(server)
            end if

            return true
        end if
    end if

    return false
End Function

Sub homeStartServerRequests(server)
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

    serverInfo = CreateObject("roAssociativeArray")
    serverInfo.server = server
    serverInfo.key = "/"
    serverInfo.requestType = "server"
    req = server.CreateRequest("", "/")
    req.SetPort(m.Screen.Port)
    req.AsyncGetToString()
    serverInfo.request = req
    m.PendingRequests[str(req.GetIdentity())] = serverInfo
End Sub

Function homeGetNames()
    return m.RowNames
End Function

Function getCurrentMyPlexLabel(myplex) As String
    if myplex.IsSignedIn then
        return "Disconnect myPlex account (" + myplex.EmailAddress + ")"
    else
        return "Connect myPlex account"
    end if
End Function

