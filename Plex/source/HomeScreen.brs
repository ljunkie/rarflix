'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")

    grid = createGridScreen(viewController)
    grid.SetStyle("flat-square")
    grid.SetUpBehaviorAtTopRow("stop")
    grid.Screen.SetDisplayMode("photo-fit")
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
    obj.Show1080pScreen = show1080pScreen

    ' Data loader interface used by the grid screen
    obj.LoadMoreContent = homeLoadMoreContent
    obj.GetNames = homeGetNames
    obj.HandleMessage = homeHandleMessage

    ' The home screen owns the myPlex manager
    obj.myplex = createMyPlexManager(viewController)

    obj.AddPendingRequest = homeAddPendingRequest
    obj.AddOrStartRequest = homeAddOrStartRequest

    obj.CreateRow = homeCreateRow
    obj.CreateServerRequests = homeCreateServerRequests
    obj.CreateMyPlexRequests = homeCreateMyPlexRequests
    obj.CreateQueueRequests = homeCreateQueueRequests
    obj.RemoveFromRowIf = homeRemoveFromRowIf

    obj.contentArray = []
    obj.RowNames = []
    obj.PendingRequests = {}
    obj.FirstLoad = true
    obj.FirstServer = true

    obj.ChannelsRow = obj.CreateRow("Channels")
    obj.SectionsRow = obj.CreateRow("Library Sections")
    obj.QueueRow = obj.CreateRow("Queue")
    obj.SharedSectionsRow = obj.CreateRow("Shared Library Sections")
    obj.MiscRow = obj.CreateRow("Miscellaneous")

    ' Kick off an asynchronous GDM discover.
    obj.GDM = createGDMDiscovery(obj.Screen.Port)
    if obj.GDM = invalid then
        print "Failed to create GDM discovery object"
    end if

    configuredServers = PlexMediaServers()
    print "Setting up home screen content, server count:"; configuredServers.Count()
    for each server in configuredServers
        obj.CreateServerRequests(server, false)
    next

    obj.myplex.CheckAuthentication()
    if obj.myplex.IsSignedIn then
        obj.CreateMyPlexRequests(false)
    end if

    '** Prefs
    prefs = CreateObject("roAssociativeArray")
    prefs.sourceUrl = ""
    prefs.ContentType = "prefs"
    prefs.Key = "globalprefs"
    prefs.Title = "Preferences"
    prefs.ShortDescriptionLine1 = "Preferences"
    prefs.SDPosterURL = "file://pkg:/images/prefs.jpg"
    prefs.HDPosterURL = "file://pkg:/images/prefs.jpg"
    obj.contentArray[obj.MiscRow].content.Push(prefs)

    return obj
End Function

Function homeCreateRow(name) As Integer
    index = m.RowNames.Count()

    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0

    m.contentArray.Push(status)
    m.RowNames.Push(name)

    return index
End Function

Sub homeCreateServerRequests(server As Object, startRequests As Boolean)
    PutPlexMediaServer(server)

    ' Request server details (ensure we have a machine ID, check transcoding
    ' support, etc.)
    req = server.CreateRequest("", "/")
    req.SetPort(m.Screen.Port)
    req.AsyncGetToString()
    serverInfo = CreateObject("roAssociativeArray")
    serverInfo.request = req
    serverInfo.requestType = "server"
    serverInfo.server = server
    m.AddPendingRequest(serverInfo)

    ' Request sections
    sections = CreateObject("roAssociativeArray")
    sections.server = server
    sections.key = "/library/sections"
    m.AddOrStartRequest(sections, m.SectionsRow, startRequests)

    ' Request recently used channels
    channels = CreateObject("roAssociativeArray")
    channels.server = server
    channels.key = "/channels/recentlyViewed"

    allChannels = CreateObject("roAssociativeArray")
    allChannels.Title = "More Channels"
    if AreMultipleValidatedServers() then
        allChannels.ShortDescriptionLine2 = "All channels on " + server.name
    else
        allChannels.ShortDescriptionLine2 = "All channels"
    end if
    allChannels.Description = allChannels.ShortDescriptionLine2
    allChannels.server = server
    allChannels.sourceUrl = ""
    allChannels.Key = "/channels/all"
    allChannels.SDPosterURL = "file://pkg:/images/plex.jpg"
    allChannels.HDPosterURL = "file://pkg:/images/plex.jpg"
    channels.item = allChannels
    m.AddOrStartRequest(channels, m.ChannelsRow, startRequests)
End Sub

Sub homeCreateMyPlexRequests(startRequests As Boolean)
    if NOT m.myplex.IsSignedIn then return

    ' Find any servers linked through myPlex
    req = m.myplex.CreateRequest("", "/pms/servers")
    req.SetPort(m.Screen.Port)
    req.AsyncGetToString()
    servers = CreateObject("roAssociativeArray")
    servers.request = req
    servers.requestType = "servers"
    m.AddPendingRequest(servers)

    ' Queue request
    m.CreateQueueRequests(startRequests)

    ' Shared sections request
    shared = CreateObject("roAssociativeArray")
    shared.server = m.myplex
    shared.key = "/pms/system/library/sections"
    m.AddOrStartRequest(shared, m.SharedSectionsRow, startRequests)
End Sub

Sub homeCreateQueueRequests(startRequests As Boolean)
    if NOT m.myplex.IsSignedIn then return

    queue = CreateObject("roAssociativeArray")
    queue.server = m.myplex
    queue.requestType = "queue"
    queue.key = "/pms/playlists/queue/unwatched"
    m.AddOrStartRequest(queue, m.QueueRow, startRequests)
End Sub

Sub homeAddOrStartRequest(request As Object, row As Integer, startRequests As Boolean)
    status = m.contentArray[row]

    if startRequests then
        httpRequest = request.server.CreateRequest("", request.key)
        httpRequest.SetPort(m.Screen.Port)
        request.request = httpRequest
        request.row = row
        request.requestType = firstOf(request.requestType, "row")

        if httpRequest.AsyncGetToString() then
            m.AddPendingRequest(request)
            status.pendingRequests = status.pendingRequests + 1
        end if
    else
        status.toLoad.AddTail(request)
    end if
End Sub

Sub homeAddPendingRequest(request)
    id = request.request.GetIdentity().ToStr()
    print "Adding pending request "; id; " -> "; request.request.GetUrl()

    if m.PendingRequests.DoesExist(id) then
        print Chr(10) + "!!! Duplicate pending request ID !!!" + Chr(10)
    end if
    m.PendingRequests[id] = request
End Sub

Function IsMyPlexServer(item) As Boolean
    return (item.server <> invalid AND NOT item.server.IsConfigured)
end function

Function AlwaysTrue(item) As Boolean
    return true
End Function

Function IsInvalidServer(item) As Boolean
    server = item.server
    if server <> invalid AND server.IsConfigured AND server.machineID <> invalid then
        return (GetPlexMediaServer(server.machineID) = invalid)
    else if item.key = "globalsearch"
        return (GetPrimaryServer() = invalid)
    else
        return false
    end if
end function

Sub refreshHomeScreen(changes)
    PrintAA(changes)

    ' If myPlex state changed, we need to update the queue, shared sections,
    ' and any owned servers that were discovered through myPlex.
    if changes.DoesExist("myplex") then
        print "myPlex status changed"

        if m.myplex.IsSignedIn then
            m.CreateMyPlexRequests(true)
        else
            m.RemoveFromRowIf(m.SectionsRow, IsMyPlexServer)
            m.RemoveFromRowIf(m.ChannelsRow, IsMyPlexServer)
            m.RemoveFromRowIf(m.MiscRow, IsMyPlexServer)
            m.RemoveFromRowIf(m.QueueRow, AlwaysTrue)
            m.RemoveFromRowIf(m.SharedSectionsRow, AlwaysTrue)
        end if
    else
        ' Always refresh the queue when we get back from the prefs screen
        m.CreateQueueRequests(true)
    end if

    ' If a server was added or removed, we need to update the sections,
    ' channels, and channel directories.
    if changes.DoesExist("servers") then
        for each server in PlexMediaServers()
            if server.machineID <> invalid AND GetPlexMediaServer(server.machineID) = invalid then
                PutPlexMediaServer(server)
            end if
        next

        servers = changes["servers"]
        didRemove = false
        for each machineID in servers
            print "Server "; machineID; " was "; servers[machineID]
            if servers[machineID] = "removed" then
                DeletePlexMediaServer(machineID)
                didRemove = true
            else
                server = GetPlexMediaServer(machineID)
                if server <> invalid then
                    m.CreateServerRequests(server, true)
                end if
            end if
        next

        if didRemove then
            m.RemoveFromRowIf(m.SectionsRow, IsInvalidServer)
            m.RemoveFromRowIf(m.ChannelsRow, IsInvalidServer)
            m.RemoveFromRowIf(m.MiscRow, IsInvalidServer)
        end if
    end if

    ' Recompute our capabilities
    Capabilities(true)
End Sub

Sub homeRemoveFromRowIf(row, predicate)
    newContent = []
    modified = false
    status = m.contentArray[row]

    for each item in status.content
        if predicate(item) then
            modified = true
        else
            newContent.Push(item)
        end if
    next

    if modified then
        print "Removed"; (status.content.Count() - newContent.Count()); " items from row"; row
        status.content = newContent
        m.Screen.OnDataLoaded(row, newContent, 0, newContent.Count(), true)
    end if
End Sub

Function showHomeScreen() As Integer
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
            m.Screen.OnDataLoaded(m.QueueRow, [], 0, 0, true)
            m.Screen.OnDataLoaded(m.SharedSectionsRow, [], 0, 0, true)
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

        origCount = status.pendingRequests
        for each toLoad in status.toLoad
            m.AddOrStartRequest(toLoad, loadingRow, true)
        next
        numRequests = status.pendingRequests - origCount

        status.toLoad.Clear()

        print "Successfully kicked off"; numRequests; " requests for row"; loadingRow; ", pending requests now:"; status.pendingRequests
    else if status.pendingRequests > 0 then
        status.loadStatus = 1
        print "No additional requests to kick off for row"; loadingRow; ", pending request count:"; status.pendingRequests
    else
        ' Special case, if we try loading the Misc row and have no servers,
        ' this is probably a first run scenario, try to be helpful.
        if loadingRow = m.MiscRow AND RegRead("serverList", "servers") = invalid AND NOT m.myplex.IsSignedIn then
            ' Give GDM discovery a chance...
            m.Screen.MsgTimeout = 5000
            m.LoadingFacade = CreateObject("roOneLineDialog")
            m.LoadingFacade.SetTitle("Looking for Plex Media Servers...")
            m.LoadingFacade.ShowBusyAnimation()
            m.LoadingFacade.Show()
        else
            status.loadStatus = 2
            m.Screen.OnDataLoaded(loadingRow, status.content, 0, status.content.Count(), true)
        end if
    end if

    return extraRowsAlreadyLoaded
End Function

Function homeHandleMessage(msg) As Boolean
    if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
        id = msg.GetSourceIdentity().ToStr()
        request = m.PendingRequests[id]
        if request = invalid then return false
        m.PendingRequests.Delete(id)

        if request.row <> invalid then
            status = m.contentArray[request.row]
            status.pendingRequests = status.pendingRequests - 1
        end if

        if msg.GetResponseCode() <> 200 then
            print "Got a"; msg.GetResponseCode(); " response from "; request.request.GetUrl(); " - "; msg.GetFailureReason()

            if request.row <> invalid AND status.loadStatus < 2 AND status.pendingRequests = 0 then
                status.loadStatus = 2
                m.Screen.OnDataLoaded(request.row, status.content, 0, status.content.Count(), true)
            end if

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
                    if item.SDPosterURL <> invalid AND Left(item.SDPosterURL, 4) = "http" AND item.server <> invalid AND item.server.AccessToken <> invalid then
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

            m.Screen.OnDataLoaded(request.row, status.content, startItem, countLoaded, true)
        else if request.requestType = "queue" then
            response = CreateObject("roAssociativeArray")
            response.xml = xml
            response.server = request.server
            response.sourceUrl = request.request.GetUrl()
            container = createPlexContainerForXml(response)

            status.content = container.GetMetadata()

            if request.item <> invalid then
                status.content.Push(request.item)
            end if

            status.loadStatus = 2

            m.Screen.OnDataLoaded(request.row, status.content, 0, status.content.Count(), true)
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

            status = m.contentArray[m.MiscRow]

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
            status.content.Push(channelDir)

            if m.FirstServer then
                m.FirstServer = false

                if m.LoadingFacade <> invalid then
                    m.LoadingFacade.Close()
                    m.LoadingFacade = invalid
                end if

                ' Add universal search now that we have a server
                univSearch = CreateObject("roAssociativeArray")
                univSearch.sourceUrl = ""
                univSearch.ContentType = "search"
                univSearch.Key = "globalsearch"
                univSearch.Title = "Search"
                univSearch.ShortDescriptionLine1 = "Search"
                univSearch.SDPosterURL = "file://pkg:/images/icon-search.jpg"
                univSearch.HDPosterURL = "file://pkg:/images/icon-search.jpg"
                status.content.Unshift(univSearch)
                m.Screen.OnDataLoaded(m.MiscRow, status.content, 0, status.content.Count(), true)
            else
                m.Screen.OnDataLoaded(m.MiscRow, status.content, status.content.Count() - 1, 1, true)
            end if
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
                        m.CreateServerRequests(server, true)
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
                server.IsConfigured = true
                PutPlexMediaServer(server)
                m.CreateServerRequests(server, true)
            end if

            return true
        end if
    else if msg = invalid then
        ' We timed out waiting for servers to load

        m.Screen.MsgTimeout = 0
        if m.LoadingFacade <> invalid then
            m.LoadingFacade.Close()
            m.LoadingFacade = invalid
        end if

        if RegRead("serverList", "servers") = invalid AND NOT m.myplex.IsSignedIn then
            print "No servers and no myPlex, appears to be a first run"
            ShowHelpScreen()
            status = m.contentArray[m.MiscRow]
            status.loadStatus = 2
            m.Screen.OnDataLoaded(m.MiscRow, status.content, 0, status.content.Count(), true)
        end if
    end if

    return false
End Function

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

Sub ShowHelpScreen()
    ' TODO(schuyler): Finalize content
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)
    screen.AddHeaderText("Welcome to Plex for Roku!")
    screen.AddParagraph("Plex for Roku automatically connects to Plex Media Servers on your local network and also works with myPlex to view queued items and connect to your published and shared servers.")
    screen.AddParagraph("To download and install Plex Media Server on your computer, visit http://plexapp.com/getplex")
    screen.AddParagraph("For more information on getting started, visit http://plexapp.com/roku")
    screen.AddButton(1, "close")

    screen.Show()

    while true
        msg = wait(0, port)
        if type(msg) = "roParagraphScreenEvent" then
            if msg.isButtonPressed() OR msg.isScreenClosed() then
                exit while
            end if
        end if
    end while
End Sub

