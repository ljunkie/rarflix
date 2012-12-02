'*
'* Loads data from search results into rows separated by content type. If
'* any search returns a reference to another search provider then another
'* is started for that provider.
'*

Function createSearchLoader(searchTerm)
    loader = CreateObject("roAssociativeArray")
    initDataLoader(loader)

    loader.LoadMoreContent = searchLoadMoreContent
    loader.GetLoadStatus = searchGetLoadStatus
    loader.GetPendingRequestCount = searchGetPendingRequestCount

    loader.SearchTerm = searchTerm

    loader.contentArray = []
    loader.PendingRequests = 0
    loader.FirstLoad = true
    loader.StartedRequests = false
    loader.ContentTypes = {}

    loader.StartRequest = searchStartRequest
    loader.CreateRow = searchCreateRow
    loader.OnUrlEvent = searchOnUrlEvent

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
    index = m.names.Count()

    status = CreateObject("roAssociativeArray")
    status.content = []
    status.numLoaded = 0
    m.contentArray.Push(status)
    m.names.Push(name)

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
    context = CreateObject("roAssociativeArray")
    context.server = server
    context.title = firstOf(title, "unknown") + " (" + server.name + ")"

    ' Associate the request with our listener's screen ID, so that any pending
    ' requests are canceled when the screen is popped.
    m.ScreenID = m.Listener.ScreenID

    if GetViewController().StartRequest(httpRequest, m, context) then
        m.PendingRequests = m.PendingRequests + 1
    end if

    Debug("Kicked off search request for " + context.title)
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

Sub searchOnUrlEvent(msg, requestContext)
    m.PendingRequests = m.PendingRequests - 1

    url = requestContext.Request.GetUrl()

    if msg.GetResponseCode() <> 200 then
        Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + tostr(url) + " - " + tostr(msg.GetFailureReason()))
        return
    end if

    xml = CreateObject("roXMLElement")
    if NOT xml.Parse(msg.GetString()) then
        Debug("Failed to parse XML from " + tostr(url))
        return
    end if

    Debug("Processing search results for: " + requestContext.title)

    response = CreateObject("roAssociativeArray")
    response.xml = xml
    response.server = requestContext.server
    response.sourceUrl = url
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
            Debug("Ignoring search result for " + tostr(typeStr))
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
            m.StartRequest(requestContext.server, node@key, node@title)
        end if
    next

    for i = 0 to m.contentArray.Count() - 1
        status = m.contentArray[i]
        if status.numLoaded > 0 then
            m.Listener.OnDataLoaded(i, status.content, status.content.Count() - status.numLoaded, status.numLoaded, true)
            status.numLoaded = 0
        end if
    next

    if m.PendingRequests = 0 then
        foundSomething = false
        for each status in m.contentArray
            if status.content.Count() > 0 then
                foundSomething = true
                exit for
            end if
        next
        if not foundSomething then
            dialog = createBaseDialog()
            dialog.Title = "No Results"
            dialog.Text = "Sorry, we couldn't find anything for '" + m.SearchTerm + "'"
            dialog.Show(true)
            m.Listener.Screen.Close()
        end if
    end if
End Sub

Function searchGetLoadStatus(row)
    if NOT m.StartedRequests then
        return 0
    else if m.PendingRequests <= 0 then
        return 2
    else
        return 1
    end if
End Function

Function searchGetPendingRequestCount() As Integer
    return m.PendingRequests
End Function
