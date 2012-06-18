'*
'* Loads data for multiple keys one page at a time. Useful for things
'* like the grid screen that want to load additional data in the background.
'*

Function createPaginatedLoader(container, initialLoadSize, pageSize)

    ' Reorder container sections so that frequently accessed sections
    ' are displayed first.
    priorityKeys = RegRead("priority_keys", "preferences", "newest,recentlyAdded,recentlyViewedShows,onDeck,all").Tokenize(",")
    for each key in priorityKeys
        container.MoveKeyToHead(key)
    next

    loader = CreateObject("roAssociativeArray")

    loader.server = container.server
    loader.sourceUrl = container.sourceUrl
    loader.names = container.GetNames()
    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize

    loader.contentArray = []

    keys = container.GetKeys()
    for index = 0 to keys.Count() - 1
        status = CreateObject("roAssociativeArray")
        status.content = []
        status.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
        status.key = keys[index]
        status.pendingRequests = 0

        loader.contentArray[index] = status
    end for

    ' Set up search nodes as the last row if we have any
    searchItems = container.GetSearch()
    if searchItems.Count() > 0 then
        loader.names.Push("Search")

        status = CreateObject("roAssociativeArray")
        status.content = searchItems
        status.loadStatus = 0
        status.key = invalid
        status.pendingRequests = 0

        loader.contentArray.Push(status)
    end if

    loader.LoadMoreContent = loaderLoadMoreContent
    loader.GetNames = loaderGetNames
    loader.HandleMessage = loaderHandleMessage
    loader.GetLoadStatus = loaderGetLoadStatus
    loader.RefreshData = loaderRefreshData
    loader.StartRequest = loaderStartRequest

    loader.Listener = invalid

    loader.PendingRequests = {}

    return loader
End Function

Function createDummyLoader(content)
    loader = CreateObject("roAssociativeArray")

    loader.content = content

    loader.LoadMoreContent = dummyLoadMoreContent
    loader.GetNames = loaderGetNames
    loader.GetLoadStatus = dummyGetLoadStatus
    loader.RefreshData = dummyRefreshData

    loader.names = []
    for i = 0 to content.Count() - 1
        loader.names[i] = ""
    next

    return loader
End Function

'*
'* Load more data either in the currently focused row or the next one that
'* hasn't been fully loaded. The return value indicates whether subsequent
'* rows are already loaded.
'*
Function loaderLoadMoreContent(focusedIndex, extraRows=0)
    status = invalid
    extraRowsAlreadyLoaded = true
    for i = 0 to extraRows
        index = focusedIndex + i
        if index >= m.contentArray.Count() then
            exit for
        else if m.contentArray[index].loadStatus < 2 AND m.contentArray[index].pendingRequests = 0 then
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

    ' Special case, if this is a row with static content, update the status
    ' and tell the listener about the content.
    if status.key = invalid then
        status.loadStatus = 2
        if m.Listener <> invalid then
            m.Listener.OnDataLoaded(loadingRow, status.content, 0, status.content.Count(), true)
        end if
        return extraRowsAlreadyLoaded
    end if

    startItem = status.content.Count()
    if startItem = 0 then
        count = m.initialLoadSize
    else
        count = m.pageSize
    end if

    status.loadStatus = 1
    m.StartRequest(loadingRow, startItem, count)

    return extraRowsAlreadyLoaded
End Function

Sub loaderRefreshData()
    for row = 0 to m.contentArray.Count() - 1
        status = m.contentArray[row]
        if status.key <> invalid AND status.loadStatus <> 0 then
            m.StartRequest(row, 0, m.pageSize)
        end if
    next
End Sub

Sub loaderStartRequest(row, startItem, count)
    status = m.contentArray[row]
    request = CreateObject("roAssociativeArray")
    httpRequest = m.server.CreateRequest(m.sourceUrl, status.key)
    httpRequest.SetPort(m.Port)
    httpRequest.AddHeader("X-Plex-Container-Start", startItem.tostr())
    httpRequest.AddHeader("X-Plex-Container-Size", count.tostr())
    request.request = httpRequest
    request.row = row

    if httpRequest.AsyncGetToString() then
        m.PendingRequests[httpRequest.GetIdentity().tostr()] = request
        status.pendingRequests = status.pendingRequests + 1
    else
        Debug("Failed to start request for row " + tostr(row) + ": " + tostr(httpRequest.GetUrl()))
    end if
End Sub

Function loaderHandleMessage(msg) As Boolean
    if (type(msg) = "roGridScreenEvent" OR type(msg) = "roPosterScreenEvent") AND msg.isScreenClosed() then
        for each id in m.PendingRequests
            m.PendingRequests[id].request.AsyncCancel()
        next
        m.PendingRequests.Clear()

        ' Let the screen handle this too
        return false
    else if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
        id = msg.GetSourceIdentity()
        request = m.PendingRequests[id.tostr()]
        if request = invalid then return false
        m.PendingRequests.Delete(id.tostr())

        status = m.contentArray[request.row]
        status.pendingRequests = status.pendingRequests - 1

        if msg.GetResponseCode() <> 200 then
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + tostr(request.request.GetUrl()) + " - " + tostr(msg.GetFailureReason()))
            return true
        end if

        xml = CreateObject("roXMLElement")
        xml.Parse(msg.GetString())

        response = CreateObject("roAssociativeArray")
        response.xml = xml
        response.server = m.server
        response.sourceUrl = request.request.GetUrl()
        container = createPlexContainerForXml(response)

        ' If the container doesn't play nice with pagination requests then
        ' whatever we got is the total size.
        if response.xml@totalSize <> invalid then
            totalSize = strtoi(response.xml@totalSize)
        else
            totalSize = container.Count()
        end if

        if totalSize <= 0 then
            status.loadStatus = 2
            startItem = 0
            countLoaded = status.content.Count()
        else
            startItem = firstOf(response.xml@offset, msg.GetResponseHeaders()["X-Plex-Container-Start"], "0").toInt()

            countLoaded = container.Count()

            if startItem <> status.content.Count() then
                Debug("Received paginated response for index " + tostr(startItem) + " of list with length " + tostr(status.content.Count()))
                metadata = container.GetMetadata()
                for i = 0 to countLoaded - 1
                    status.content[startItem + i] = metadata[i]
                next
            else
                status.content.Append(container.GetMetadata())
            end if

            if status.loadStatus = 2 AND startItem + countLoaded < totalSize then
                ' We're in the middle of refreshing the row, kick off the
                ' next request.
                m.StartRequest(request.row, startItem + countLoaded, m.pageSize)
            else if status.content.Count() < totalSize then
                status.loadStatus = 1
            else
                status.loadStatus = 2
            end if
        end if

        while status.content.Count() > totalSize
            status.content.Pop()
        end while

        if countLoaded > status.content.Count() then
            countLoaded = status.content.Count()
        end if

        if m.Listener <> invalid then
            m.Listener.OnDataLoaded(request.row, status.content, startItem, countLoaded, status.loadStatus = 2)
        end if

        return true
    end if

    return false
End Function

Function loaderGetNames()
    return m.names
End Function

Function dummyLoadMoreContent(index, extraRows=0)
    return true
End Function

Function loaderGetLoadStatus(row)
    return m.contentArray[row].loadStatus
End Function

Function dummyGetLoadStatus(row)
    return 2
End Function

Sub dummyRefreshData()
    ' We had static data, nothing to refresh.
End Sub

