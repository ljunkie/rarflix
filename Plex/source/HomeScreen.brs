'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")

    grid = createGridScreen(viewController, "flat-square")
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

    ' Data loader interface used by the grid screen
    obj.LoadMoreContent = homeLoadMoreContent
    obj.GetNames = homeGetNames
    obj.HandleMessage = homeHandleMessage
    obj.GetLoadStatus = homeGetLoadStatus
    obj.RefreshData = homeRefreshData

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
    if RegRead("autodiscover", "preferences", "1") = "1" then
        obj.GDM = createGDMDiscovery(obj.Screen.Port)
        if obj.GDM = invalid then
            Debug("Failed to create GDM discovery object")
        end if
    end if

    configuredServers = PlexMediaServers()
    Debug("Setting up home screen content, server count: " + tostr(configuredServers.Count()))
    for each server in configuredServers
        obj.CreateServerRequests(server, false, false)
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
    prefs.SDPosterURL = "file://pkg:/images/gear.png"
    prefs.HDPosterURL = "file://pkg:/images/gear.png"
    obj.contentArray[obj.MiscRow].content.Push(prefs)

    obj.lastMachineID = RegRead("lastMachineID")
    obj.lastSectionKey = RegRead("lastSectionKey")

    return obj
End Function

Function homeCreateRow(name) As Integer
    index = m.RowNames.Count()

    status = CreateObject("roAssociativeArray")
    status.content = []
    status.loadStatus = 0
    status.toLoad = CreateObject("roList")
    status.pendingRequests = 0
    status.refreshContent = invalid
    status.loadedServers = {}

    m.contentArray.Push(status)
    m.RowNames.Push(name)

    return index
End Function

Sub homeCreateServerRequests(server As Object, startRequests As Boolean, refreshRequest As Boolean)
    if not refreshRequest then
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
    end if

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
    allChannels.SDPosterURL = "file://pkg:/images/more.png"
    allChannels.HDPosterURL = "file://pkg:/images/more.png"
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

    ' Unwatched queue items
    queue = CreateObject("roAssociativeArray")
    queue.server = m.myplex
    queue.requestType = "queue"
    queue.key = "/pms/playlists/queue/unwatched"

    ' A dummy item to pull up the full queue
    allQueue = CreateObject("roAssociativeArray")
    allQueue.Title = "All Queued Items"
    allQueue.Description = "All queued items, including already watched items"
    allQueue.ShortDescriptionLine2 = allQueue.Description
    allQueue.server = m.myplex
    allQueue.sourceUrl = ""
    allQueue.Key = "/pms/playlists/queue"
    allQueue.SDPosterURL = "file://pkg:/images/more.png"
    allQueue.HDPosterURL = "file://pkg:/images/more.png"
    allQueue.ContentType = "series"
    queue.item = allQueue
    queue.emptyItem = allQueue

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
    Debug("Adding pending request " + tostr(id) + " -> "+ tostr(request.request.GetUrl()))

    if m.PendingRequests.DoesExist(id) then
        Debug(Chr(10) + "!!! Duplicate pending request ID !!!" + Chr(10))
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
        Debug("myPlex status changed")

        if m.myplex.IsSignedIn then
            m.CreateMyPlexRequests(true)
        else
            m.RemoveFromRowIf(m.SectionsRow, IsMyPlexServer)
            m.RemoveFromRowIf(m.ChannelsRow, IsMyPlexServer)
            m.RemoveFromRowIf(m.MiscRow, IsMyPlexServer)
            m.RemoveFromRowIf(m.QueueRow, AlwaysTrue)
            m.RemoveFromRowIf(m.SharedSectionsRow, AlwaysTrue)
        end if
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
            Debug("Server " + tostr(machineID) + " was " + tostr(servers[machineID]))
            if servers[machineID] = "removed" then
                DeletePlexMediaServer(machineID)
                didRemove = true
            else
                server = GetPlexMediaServer(machineID)
                if server <> invalid then
                    m.CreateServerRequests(server, true, false)
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
        Debug("Removed " + tostr(status.content.Count() - newContent.Count()) + " items from row" + tostr(row))
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
        else
            ' It'll be made visible if we get any data.
            m.Screen.Screen.SetListVisible(m.SharedSectionsRow, false)
        end if

        m.Screen.hasBeenFocused = false
        m.Screen.ignoreNextFocus = true

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

        Debug("Successfully kicked off " + tostr(numRequests) + " requests for row " + tostr(loadingRow) + ", pending requests now: " + tostr(status.pendingRequests))
    else if status.pendingRequests > 0 then
        status.loadStatus = 1
        Debug("No additional requests to kick off for row " + tostr(loadingRow) + ", pending request count: " + tostr(status.pendingRequests))
    else
        ' Special case, if we try loading the Misc row and have no servers,
        ' this is probably a first run scenario, try to be helpful.
        if loadingRow = m.MiscRow AND RegRead("serverList", "servers") = invalid AND NOT m.myplex.IsSignedIn then
            if RegRead("autodiscover", "preferences", "1") = "1" then
                ' Give GDM discovery a chance...
                m.Screen.MsgTimeout = 5000
                m.LoadingFacade = CreateObject("roOneLineDialog")
                m.LoadingFacade.SetTitle("Looking for Plex Media Servers...")
                m.LoadingFacade.ShowBusyAnimation()
                m.LoadingFacade.Show()
            else
                ' Slightly strange, GDM disabled but no servers configured
                Debug("No servers, no GDM, and no myPlex...")
                ShowHelpScreen()
                status.loadStatus = 2
                m.Screen.OnDataLoaded(loadingRow, status.content, 0, status.content.Count(), true)
            end if
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
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + tostr(request.request.GetUrl()) + " - " + tostr(msg.GetFailureReason()))

            if request.row <> invalid AND status.loadStatus < 2 AND status.pendingRequests = 0 then
                status.loadStatus = 2
                if status.refreshContent <> invalid then
                    status.content = status.refreshContent
                    status.refreshContent = invalid
                end if
                m.Screen.OnDataLoaded(request.row, status.content, 0, status.content.Count(), true)
            end if

            return true
        else
            Debug("Got a 200 response from " + tostr(request.request.GetUrl()) + " (type " + tostr(request.requestType) + ", row " + tostr(request.row) + ")")
        end if

        xml = CreateObject("roXMLElement")
        xml.Parse(msg.GetString())

        if request.requestType = "row" then
            countLoaded = 0
            content = firstOf(status.refreshContent, status.content)
            startItem = content.Count()

            request.server.IsAvailable = true
            machineId = tostr(request.server.MachineID)

            if status.loadedServers.DoesExist(machineID) then
                Debug("Ignoring content for server that was already loaded: " + machineID)
                items = []
                request.item = invalid
                request.emptyItem = invalid
            else
                status.loadedServers[machineID] = "1"
                response = CreateObject("roAssociativeArray")
                response.xml = xml
                response.server = request.server
                response.sourceUrl = request.request.GetUrl()
                container = createPlexContainerForXml(response)
                items = container.GetMetadata()

                if AreMultipleValidatedServers() then
                    serverStr = " on " + request.server.name
                else
                    serverStr = ""
                end if
            end if

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
                        Debug("Found a server for the section: " + tostr(item.Title) + " on " + tostr(server.name))
                        item.server = server
                        serverStr = " on " + server.name
                    else
                        Debug("Found a shared section for an unknown server: " + tostr(item.MachineID))
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
                        Debug("Skipping unsupported channel type: " + tostr(channelType))
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
                    Debug("Skipping unsupported section type: " + tostr(item.Type))
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

                    content.Push(item)
                    countLoaded = countLoaded + 1
                end if
            next

            if request.item <> invalid AND countLoaded > 0 then
                countLoaded = countLoaded + 1
                content.Push(request.item)
            else if request.emptyItem <> invalid AND countLoaded = 0 then
                countLoaded = countLoaded + 1
                content.Push(request.emptyItem)
            end if

            if status.toLoad.Count() = 0 AND status.pendingRequests = 0 then
                status.loadStatus = 2
            end if

            if status.refreshContent <> invalid then
                if status.toLoad.Count() = 0 AND status.pendingRequests = 0 then
                    status.content = status.refreshContent
                    status.refreshContent = invalid
                    m.Screen.OnDataLoaded(request.row, status.content, 0, status.content.Count(), true)
                end if
            else
                m.Screen.OnDataLoaded(request.row, status.content, startItem, countLoaded, true)
            end if

            if m.Screen.hasBeenFocused = false AND request.row = m.SectionsRow AND type(m.Screen.Screen) = "roGridScreen" AND request.server.machineID = m.lastMachineID then
                Debug("Trying to focus last used section")
                for i = 0 to status.content.Count() - 1
                    if status.content[i].key = m.lastSectionKey then
                        m.Screen.Screen.SetFocusedListItem(request.row, i)
                        exit for
                    end if
                next
            end if
        else if request.requestType = "queue" then
            response = CreateObject("roAssociativeArray")
            response.xml = xml
            response.server = request.server
            response.sourceUrl = request.request.GetUrl()
            container = createPlexContainerForXml(response)

            status.content = container.GetMetadata()

            if request.item <> invalid AND status.content.Count() > 0 then
                status.content.Push(request.item)
            else if request.emptyItem <> invalid AND status.content.Count() = 0 then
                status.content.Push(request.emptyItem)
            end if

            status.loadStatus = 2

            m.Screen.OnDataLoaded(request.row, status.content, 0, status.content.Count(), true)
        else if request.requestType = "server" then
            ' If the machine ID doesn't match what we expected then disregard,
            ' it was probably a myPlex local address that hasn't been updated.
            ' If we already have a server then disregard, we might have made
            ' multiple requests for local addresses and the first one back wins.

            existing = GetPlexMediaServer(xml@machineIdentifier)
            if request.server.machineID <> invalid AND request.server.machineID <> xml@machineIdentifier then
                Debug("Ignoring server response from unexpected machine ID")
            else if existing <> invalid AND existing.online then
                Debug("Ignoring server response from already configured address (" + request.server.serverUrl + " / " + existing.serverUrl + ")")
            else
                request.server.name = xml@friendlyName
                request.server.machineID = xml@machineIdentifier
                request.server.owned = true
                request.server.online = true
                request.server.SupportsAudioTranscoding = (xml@transcoderAudio = "1")
                request.server.IsAvailable = true
                PutPlexMediaServer(request.server)

                Debug("Fetched additional server information (" + tostr(request.server.name) + ", " + tostr(request.server.machineID) + ")")
                Debug("URL: " + tostr(request.server.serverUrl))
                Debug("Server supports audio transcoding: " + tostr(request.server.SupportsAudioTranscoding))

                status = m.contentArray[m.MiscRow]

                machineId = tostr(request.server.machineID)
                if NOT status.loadedServers.DoesExist(machineID) then
                    status.loadedServers[machineID] = "1"
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
                    channelDir.SDPosterURL = "file://pkg:/images/more.png"
                    channelDir.HDPosterURL = "file://pkg:/images/more.png"
                    status.content.Push(channelDir)
                end if

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
                    univSearch.Description = "Search for items across all your sections and channels"
                    univSearch.ShortDescriptionLine2 = univSearch.Description
                    univSearch.SDPosterURL = "file://pkg:/images/search.png"
                    univSearch.HDPosterURL = "file://pkg:/images/search.png"
                    status.content.Unshift(univSearch)
                    m.Screen.OnDataLoaded(m.MiscRow, status.content, 0, status.content.Count(), true)
                else
                    m.Screen.OnDataLoaded(m.MiscRow, status.content, status.content.Count() - 1, 1, true)
                end if
            end if
        else if request.requestType = "servers" then
            for each serverElem in xml.Server
                ' If we already have a server for this machine ID then disregard
                existing = GetPlexMediaServer(serverElem@machineIdentifier)
                addr = "http://" + serverElem@host + ":" + serverElem@port
                if existing <> invalid AND (existing.IsAvailable OR existing.ServerUrl = addr) then
                    Debug("Ignoring duplicate shared server: " + tostr(serverElem@machineIdentifier))
                else
                    if existing = invalid then
                        server = newPlexMediaServer(addr, serverElem@name, serverElem@machineIdentifier)
                    else
                        server = existing
                        server.ServerUrl = addr
                    end if

                    server.AccessToken = firstOf(serverElem@accessToken, m.myplex.AuthToken)

                    if serverElem@owned = "1" then
                        ' If we got local addresses, kick off simultaneous requests for all
                        ' of them. The first one back will win, so we should always use the
                        ' most efficient connection.
                        localAddresses = strTokenize(serverElem@localAddresses, ",")
                        for each localAddress in localAddresses
                            localServer = newPlexMediaServer("http://" + localAddress + ":32400", serverElem@name, serverElem@machineIdentifier)
                            localServer.name = serverElem@name
                            localServer.owned = true
                            localServer.AccessToken = firstOf(serverElem@accessToken, m.myplex.AuthToken)
                            m.CreateServerRequests(localServer, true, false)
                        next

                        server.name = serverElem@name
                        server.owned = true

                        ' An owned server that we didn't have configured, request
                        ' its sections and channels now.
                        m.CreateServerRequests(server, true, false)
                    else
                        server.name = serverElem@name + " (shared by " + serverElem@sourceTitle + ")"
                        server.owned = false
                    end if
                    PutPlexMediaServer(server)

                    Debug("Added shared server: " + tostr(server.name))
                end if
            next
        end if

        Debug("Remaining pending requests:")
        for each id in m.PendingRequests
            Debug(m.PendingRequests[id].request.GetUrl())
        next

        return true
    else if type(msg) = "roSocketEvent" then
        serverInfo = m.GDM.HandleMessage(msg)
        if serverInfo <> invalid then
            Debug("GDM discovery found server at " + tostr(serverInfo.Url))

            existing = GetPlexMediaServer(serverInfo.MachineID)
            if existing <> invalid then
                if existing.ServerUrl = serverInfo.Url then
                    Debug("GDM discovery ignoring already configured server")
                else
                    Debug("Found new address for " + serverInfo.Name + ": " + existing.ServerUrl + " -> " + serverInfo.Url)
                    existing.Name = serverInfo.Name
                    existing.ServerUrl = serverInfo.Url
                    existing.owned = true
                    existing.IsConfigured = true
                    m.CreateServerRequests(existing, true, false)
                    UpdateServerAddress(existing)
                end if
            else
                AddServer(serverInfo.Name, serverInfo.Url, serverInfo.MachineID)
                server = newPlexMediaServer(serverInfo.Url, serverInfo.Name, serverInfo.MachineID)
                server.owned = true
                server.IsConfigured = true
                PutPlexMediaServer(server)
                m.CreateServerRequests(server, true, false)
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
            Debug("No servers and no myPlex, appears to be a first run")
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

Function homeGetLoadStatus(row)
    return m.contentArray[row].loadStatus
End Function

Function getCurrentMyPlexLabel(myplex) As String
    if myplex.IsSignedIn then
        return "Disconnect myPlex account (" + myplex.EmailAddress + ")"
    else
        return "Connect myPlex account"
    end if
End Function

Sub ShowHelpScreen()
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

Sub homeRefreshData()
    ' Refresh the queue
    m.CreateQueueRequests(true)

    ' Refresh the sections and channels for all of our owned servers
    m.contentArray[m.SectionsRow].refreshContent = []
    m.contentArray[m.SectionsRow].loadedServers.Clear()
    m.contentArray[m.ChannelsRow].refreshContent = []
    m.contentArray[m.ChannelsRow].loadedServers.Clear()
    for each server in GetOwnedPlexMediaServers()
        m.CreateServerRequests(server, true, true)
    next

    ' Clear any screensaver images, use the default.
    SaveImagesForScreenSaver(invalid, {})
End Sub

