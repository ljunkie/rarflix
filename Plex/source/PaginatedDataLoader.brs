'*
'* Loads data for multiple keys one page at a time. Useful for things
'* like the grid screen that want to load additional data in the background.
'*

Function createPaginatedLoader(container, initialLoadSize, pageSize)
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

    loader.GetContent = loaderGetContent
    loader.LoadMoreContent = loaderLoadMoreContent
    loader.GetLoadStatus = loaderGetLoadStatus
    loader.GetNames = loaderGetNames
    loader.HandleMessage = loaderHandleMessage

    loader.Listener = invalid

    loader.PendingRequests = {}

    return loader
End Function

Function createDummyLoader(content)
    loader = CreateObject("roAssociativeArray")

    loader.content = content

    loader.GetContent = dummyGetContent
    loader.LoadMoreContent = dummyLoadMoreContent
    loader.GetLoadStatus = dummyGetLoadStatus
    loader.GetNames = loaderGetNames

    loader.names = []
    for i = 0 to content.Count() - 1
        loader.names[i] = ""
    next

    return loader
End Function

Function loaderGetContent(index)
    return m.contentArray[index].content
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
            m.Listener.OnDataLoaded(loadingRow, status.content, 0, status.content.Count())
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

    request = CreateObject("roAssociativeArray")
    httpRequest = m.server.CreateRequest(m.sourceUrl, status.key)
    httpRequest.SetPort(m.Port)
    httpRequest.AddHeader("X-Plex-Container-Start", startItem.tostr())
    httpRequest.AddHeader("X-Plex-Container-Size", count.tostr())
    request.request = httpRequest
    request.row = loadingRow
    m.PendingRequests[str(httpRequest.GetIdentity())] = request

    if httpRequest.AsyncGetToString() then
        status.pendingRequests = status.pendingRequests + 1
    else
        print "Failed to start request for row"; loadingRow; ": "; httpRequest.GetUrl()
    end if

    return extraRowsAlreadyLoaded
End Function

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
        request = m.PendingRequests[str(id)]
        if request = invalid then return false
        m.PendingRequests.Delete(str(id))

        status = m.contentArray[request.row]
        status.pendingRequests = status.pendingRequests - 1

        if msg.GetResponseCode() <> 200 then
            print "Got a " + msg.GetResponseCode(); " response from "; request.request.GetUrl(); " - "; msg.GetFailureReason()
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
            if response.xml@offset <> invalid then
                startItem = strtoi(response.xml@offset)
            else
                startItem = status.content.Count()
            end if

            if startItem <> status.content.Count() then
                print "Received paginated response for index"; startItem; " of list with length"; status.content.Count()
                metadata = container.GetMetadata()
                for i = 0 to metadata.Count() - 1
                    status.content[startItem + i] = metadata[i]
                next
            else
                status.content.Append(container.GetMetadata())
            end if

            if status.content.Count() < totalSize then
                status.loadStatus = 1
            else
                status.loadStatus = 2
            end if

            countLoaded = container.Count()
        end if

        if m.Listener <> invalid then
            m.Listener.OnDataLoaded(request.row, status.content, startItem, countLoaded)
        end if

        return true
    end if

    return false
End Function

Function loaderGetLoadStatus(index) As Integer
    return m.contentArray[index].loadStatus
End Function

Function loaderGetNames()
    return m.names
End Function

Function dummyGetContent(index)
    return m.content[index]
End Function

Function dummyLoadMoreContent(index, extraRows=0)
    return true
End Function

Function dummyGetLoadStatus(index) As Integer
    return 2
End Function

