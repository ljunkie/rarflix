'*
'* Loads data for multiple keys one page at a time. Useful for things
'* like the grid screen that want to load additional data in the background.
'*

Function createPaginatedLoader(server, sourceUrl, keys, initialLoadSize, pageSize)
    loader = CreateObject("roAssociativeArray")

    loader.server = server
    loader.sourceUrl = sourceUrl
    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize

    loader.contentArray = []

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

    return loader
End Function

Function createDummyLoader(content)
    loader = CreateObject("roAssociativeArray")

    loader.content = content

    loader.GetContent = dummyGetContent
    loader.LoadMoreContent = dummyLoadMoreContent
    loader.GetLoadStatus = dummyGetLoadStatus

    return loader
End Function

Function loaderGetContent(index)
    return m.contentArray[index].content
End Function

Function loaderLoadMoreContent(focusedIndex, extraRows=0)
    status = invalid
    for i = 0 to extraRows
        index = focusedIndex + i
        if index >= m.contentArray.Count() then
            return true
        else if m.contentArray[index].loadStatus < 2 then
            status = m.contentArray[index]
            exit for
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
        return true
    end if

    status.content.Append(container.GetMetadata())

    if status.content.Count() < totalSize then
        status.loadStatus = 1
        return false
    else
        status.loadStatus = 2
        return true
    end if
End Function

Function loaderGetLoadStatus(index) As Integer
    return m.contentArray[index].loadStatus
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

