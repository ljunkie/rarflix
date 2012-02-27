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

        loader.contentArray[index] = status
    end for

    loader.GetContent = loaderGetContent
    loader.LoadMoreContent = loaderLoadMoreContent
    loader.GetLoadStatus = loaderGetLoadStatus
    loader.GetNames = loaderGetNames

    loader.Listener = invalid

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
'* hasn't been fully loaded. The return value indicates whether the current
'* row (and any extra rows) are now fully loaded.
'*
Function loaderLoadMoreContent(focusedIndex, extraRows=0)
    status = invalid
    extraRowsAlreadyLoaded = true
    for i = 0 to extraRows
        index = focusedIndex + i
        if index >= m.contentArray.Count() then
            exit for
        else if m.contentArray[index].loadStatus < 2 then
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

    startItem = status.content.Count()
    if startItem = 0 then
        count = m.initialLoadSize
    else
        count = m.pageSize
    end if

    response = m.server.GetPaginatedQueryResponse(m.sourceUrl, status.key, startItem, count)
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
        return extraRowsAlreadyLoaded
    end if

    status.content.Append(container.GetMetadata())

    if status.content.Count() < totalSize then
        status.loadStatus = 1
        ret = false
    else
        status.loadStatus = 2
        ret = extraRowsAlreadyLoaded
    end if

    if m.Listener <> invalid then
        m.Listener.OnDataLoaded(loadingRow, status.content, startItem, container.Count())
    end if

    return ret
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

