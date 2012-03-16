'*
'* Loads data from search results into rows separated by content type. If
'* any search returns a reference to another search provider then another
'* is started for that provider.
'*

Function createSearchLoader(searchTerm)
    loader = CreateObject("roAssociativeArray")

    loader.LoadMoreContent = searchLoadMoreContent
    loader.GetNames = searchGetNames
    loader.HandleMessage = searchHandleMessage
    loader.GetLoadStatus = searchGetLoadStatus
    loader.RefreshData = searchRefreshData

    loader.Listener = invalid
    loader.SearchTerm = searchTerm

    loader.contentArray = []
    loader.RowNames = []
    loader.PendingRequests = {}
    loader.FirstLoad = true
    loader.StartedRequests = false
    loader.ContentTypes = {}

    loader.StartRequest = searchStartRequest
    loader.CreateRow = searchCreateRow

    ' Create rows for each of our fixed buckets.
    loader.MovieRow = loader.CreateRow("Movies", "movie")
    loader.ShowRow = loader.CreateRow("Shows", "show")
    loader.EpisodeRow = loader.CreateRow("Episodes", "episode")
    loader.ArtistRow = loader.CreateRow("Artists", "artist")
    loader.AlbumRow = loader.CreateRow("Albums", "album")
    loader.TrackRow = loader.CreateRow("Tracks", "track")
    loader.ActorRow = loader.CreateRow("Actors", "person")
    loader.ClipRow = loader.CreateRow("Clips", "clip")

    return loader
End Function

Function searchCreateRow(name, typeStr)
    index = m.RowNames.Count()

    status = CreateObject("roAssociativeArray")
    status.content = []
    status.numLoaded = 0
    m.contentArray.Push(status)
    m.RowNames.Push(name)

    m.ContentTypes[typeStr] = index

    return index
End Function

Sub searchStartRequest(server, url, title)
    if instr(1, url, "?") > 0 then
        url = url + "&query=" + HttpEncode(m.SearchTerm)
    else
        url = url + "?query=" + HttpEncode(m.SearchTerm)
    end if

    httpRequest = server.CreateRequest("", url)
    httpRequest.SetPort(m.Listener.Port)
    httpRequest.AsyncGetToString()

    req = CreateObject("roAssociativeArray")
    req.request = httpRequest
    req.server = server
    req.title = firstOf(title, "unknown") + " (" + server.name + ")"
    m.PendingRequests[httpRequest.GetIdentity().tostr()] = req

    print "Kicked off search request for "; req.title
End Sub

Function searchLoadMoreContent(focusedRow, extraRows=0) As Boolean
    ' We don't really load by row. If this is the first load call, kick off
    ' the initial search requests. Otherwise disregard.
    if m.FirstLoad then
        m.FirstLoad = false

        for i = 0 to m.contentArray.Count() - 1
            content = m.contentArray[i].content
            m.Listener.OnDataLoaded(i, content, 0, content.Count(), true)
        next

        for each server in GetOwnedPlexMediaServers()
            m.StartRequest(server, "/search", "Root")
        next

        m.StartedRequests = true
    end if

    return true
End Function

Function searchGetNames()
    return m.RowNames
End Function

Function searchHandleMessage(msg) As Boolean
    if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
        id = msg.GetSourceIdentity()
        request = m.PendingRequests[id.tostr()]
        if request = invalid then return false
        m.PendingRequests.Delete(id.tostr())

        if msg.GetResponseCode() <> 200 then
            print "Got a "; msg.GetResponseCode(); " response from "; request.request.GetUrl(); " - "; msg.GetFailureReason()
            return true
        end if

        xml = CreateObject("roXMLElement")
        if NOT xml.Parse(msg.GetString()) then
            print "Failed to parse XML from "; request.request.GetUrl()
            return true
        end if

        print "Processing search results for: "; request.title

        response = CreateObject("roAssociativeArray")
        response.xml = xml
        response.server = request.server
        response.sourceUrl = request.request.GetUrl()
        container = createPlexContainerForXml(response)

        items = container.GetMetadata()
        for each item in items
            typeStr = firstOf(item.type, item.ContentType)
            if item.type = invalid then
                item = invalid
            else
                index = m.ContentTypes[item.type]
                if index = invalid then
                    item = invalid
                else
                    status = m.contentArray[index]
                end if
            end if

            if item = invalid then
                print "Ignoring search result for "; typeStr
            else
                if item.sourceTitle <> invalid then
                    item.Description = "(" + item.sourceTitle + ") " + firstOf(item.Description, "")
                end if

                if item.SDPosterURL <> invalid AND Left(item.SDPosterURL, 4) = "http" AND item.server <> invalid AND item.server.AccessToken <> invalid then
                    item.SDPosterURL = item.SDPosterURL + "&X-Plex-Token=" + item.server.AccessToken
                    item.HDPosterURL = item.HDPosterURL + "&X-Plex-Token=" + item.server.AccessToken
                end if

                status.content.Push(item)
                status.numLoaded = status.numLoaded + 1
            end if
        next

        for each node in xml.Provider
            ' We should already have searched other local servers, ignore
            ' those providers.
            if node@machineIdentifier = invalid then
                m.StartRequest(request.server, node@key, node@title)
            end if
        next

        for i = 0 to m.contentArray.Count() - 1
            status = m.contentArray[i]
            if status.numLoaded > 0 then
                m.Listener.OnDataLoaded(i, status.content, status.content.Count() - status.numLoaded, status.numLoaded, true)
                status.numLoaded = 0
            end if
        next

        return true
    else if (type(msg) = "roGridScreenEvent" OR type(msg) = "roPosterScreenEvent") AND msg.isScreenClosed() then
        for each id in m.PendingRequests
            m.PendingRequests[id].request.AsyncCancel()
        next
        m.PendingRequests.Clear()
        return false
    end if

    return false
End Function

Function searchGetLoadStatus(row)
    if NOT m.StartedRequests then
        return 0
    else if m.PendingRequests.IsEmpty() then
        return 2
    else
        return 1
    end if
End Function

Sub searchRefreshData()
    ' Ignore, at least for now. Redoing the search is expensive and there's
    ' no obvious scenario where the content changed.
End Sub

