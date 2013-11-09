'*
'* Loads data for multiple keys one page at a time. Useful for things
'* like the grid screen that want to load additional data in the background.
'*

Function createPaginatedLoader(container, initialLoadSize, pageSize, item = invalid as dynamic)
    loader = CreateObject("roAssociativeArray")
    initDataLoader(loader)

    loader.server = container.server
    loader.sourceUrl = container.sourceUrl
    loader.names = container.GetNames()
    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize

    loader.contentArray = []

    keys = container.GetKeys()


    subsecItems = []
    if type(container.GetMetadata) = "roFunction" then 
        subsecItems = container.GetMetadata() ' grab subsections for FULL grid. We might want to hide some (same index as container.GetKeys())
        ' Hide Rows - ljunkie ( remove key and loader.names )
        if type(item) = "roAssociativeArray" and item.contenttype = "section" then 
            itype = item.type
            for index = 0 to keys.Count() - 1
                if keys[index] <> invalid then  ' delete from underneath does this
                    hide = false
                    rf_hide_key = "rf_hide_" + keys[index]
    
                    ' recentlyAdded and newest(recently Release/Aired) are special/hidden per type
                    if keys[index] = "recentlyAdded" or keys[index] = "newest" and (itype = "movie" or itype = "show" or itype = "artist" or itype = "show") then 
                        rf_hide_key = rf_hide_key + "_" + itype 'print "Checking " + keys[index] + " for specific type of hide: " + itype
                    end if
    
                    if RegRead(rf_hide_key, "preferences", "show") <> "show"  then 
                        Debug("---- ROW HIDDEN: " + keys[index] + " - hide specified via reg " + rf_hide_key )
                        keys.Delete(index)
                        loader.names.Delete(index)
                        subsecItems.Delete(index)
                        index = index - 1
                    end if
                end if
            end for
        end if
    end if
    ' End Hide Rows

    ' ljunkie - CUSTOM new rows (movies only for now) -- allow new rows based on allows PLEX filters
    subsec_extras = []

    if type(item) = "roAssociativeArray" and item.contenttype = "section" and item.type = "show" then 
        size_limit = RegRead("rf_rowfilter_limit", "preferences","200") 'gobal size limit Toggle for filter rows
       
        ' unwatched recently Added season
        new_key = "recentlyAdded?stack=1"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            keys.Push(new_key)
            new_name = "Recently Added Seasons"
            loader.names.Push(new_name)
            subsec_extras.Push({ key: new_key, name: new_name, key_copy: "all" })
        end if

        ' unwatched recently Aired EPISODES
        new_key = "all?timelineState=1&type=4&unwatched=1&sort=originallyAvailableAt:desc"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
            keys.Push(new_key)
            new_name = "Unwatched Recently Aired"
            loader.names.Push(new_name)
            subsec_extras.Push({ key: new_key, name: new_name, key_copy: "all" })
        end if

        ' unwatched recently Aired EPISODES
        new_key = "all?timelineState=1&type=4&unwatched=1&sort=addedAt:desc"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
            keys.Push(new_key)
            new_name = "Unwatched Recently Added"
            loader.names.Push(new_name)
            subsec_extras.Push({ key: new_key, name: new_name, key_copy: "all" })
        end if

    end if

    if type(item) = "roAssociativeArray" and item.contenttype = "section" and item.type = "movie" then 
        size_limit = RegRead("rf_rowfilter_limit", "preferences","200") 'gobal size limit Toggle for filter rows

        ' unwatched recently released
        new_key = "all?type=1&unwatched=1&sort=originallyAvailableAt:desc"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
            keys.Push(new_key)
            new_name = "Unwatched Recently Released"
            loader.names.Push(new_name)
            subsec_extras.Push({ key: new_key, name: new_name, key_copy: "all" })
        end if

        ' unwatched recently Added
        new_key = "all?type=1&unwatched=1&sort=addedAt:desc"
        if RegRead("rf_hide_"+new_key, "preferences", "show") = "show" then 
            new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
            keys.Push(new_key)
            new_name = "Unwatched Recently Added"
            loader.names.Push(new_name)
            subsec_extras.Push({ key: new_key, name: new_name, key_copy: "all" })
        end if

    end if

    ' we will have to add the custom rows to the subsections too ( quick filter row (0) for the full grid )
    if subsec_extras.count() > 0 and type(subsecItems) = "roArray" and subsecItems.count() > 0 then
        for each sec in subsec_extras
            for index = 0 to subsecItems.Count() - 1
                if subsecItems[index].key = sec.key_copy  then 
                    template = subsecItems[index]
                    exit for
                end if
            end for
            copy = ShallowCopy(template,2) ' really? brs doesn't have a clone/copy
            ' now set the uniq characters
            copy.key = sec.key
            copy.name = sec.name
            copy.umtitle = sec.name
            copy.title = sec.name
            rfCDNthumb(copy,sec.name,invalid)
            subsecItems.Push(copy)
        end for
    end if
    ' END custom rows

    for index = 0 to keys.Count() - 1
        status = CreateObject("roAssociativeArray")
        status.content = []
        status.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
        itype = invalid
        if type(item) = "roAssociativeArray" then itype = item.type
        status.key = keyFiler(keys[index],tostr(itype)) ' ljunkie - allow us to use the new filters for the simple keys
        status.name = loader.names[index]
        status.pendingRequests = 0
        status.countLoaded = 0

        loader.contentArray[index] = status
    end for

    ' Set up search nodes as the last row if we have any
    if RegRead("rf_hide_search", "preferences", "show") = "show" then     ' ljunkie - or hide it ( why would someone do this? but here is the option...)
        searchItems = container.GetSearch()
        if searchItems.Count() > 0 then
            status = CreateObject("roAssociativeArray")
            status.content = searchItems
            status.loadStatus = 0
            status.key = "_search_"
            status.name = "Search"
            status.pendingRequests = 0
            status.countLoaded = 0

            loader.contentArray.Push(status)
        end if
    end if

    ' Reorder container sections so that frequently accessed sections
    ' are displayed first. Make sure to revert the search row's dummy key
    ' to invalid so we don't try to load it.
    ReorderItemsByKeyPriority(loader.contentArray, RegRead("section_row_order", "preferences", ""))

    ' LJUNKIE - Special Header Row - will show the sub sections for a section ( used for the full grid view )
    ' TOD: toggle this? I don't think it's needed now as this row (0) is "hidden" - we focus to row (1)
    if item <> invalid then 
        if loader.sourceurl <> invalid and item <> invalid and item.contenttype <> invalid and item.contenttype = "section" then 
            Debug("---- Adding sub sections row for contenttype:" + tostr(item.contenttype))
            ReorderItemsByKeyPriority(subsecItems, RegRead("section_row_order", "preferences", ""))
            header_row = CreateObject("roAssociativeArray")
            header_row.content = subsecItems
            header_row.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
            header_row.key = "_subsec_"
            header_row.name = firstof(item.title,"Sub Sections")
            header_row.pendingRequests = 0
            header_row.countLoaded = 0
    
            loader.contentArray.Unshift(header_row)
            keys.Unshift(header_row.key)
            loader.names.Unshift(header_row.name)
            loader.focusrow = 1 ' we want to hide this row by default
        else 
            Debug("---- NOT Adding sub sections row for contenttype:" + tostr(item.contenttype))
        end if
    end if
    ' end testing

    for index = 0 to loader.contentArray.Count() - 1
        status = loader.contentArray[index]
        loader.names[index] = status.name
        if status.key = "_search_"  or status.key = "_subsec_" then
            status.key = invalid
        end if
    next

    loader.LoadMoreContent = loaderLoadMoreContent
    loader.GetLoadStatus = loaderGetLoadStatus
    loader.RefreshData = loaderRefreshData
    loader.StartRequest = loaderStartRequest
    loader.OnUrlEvent = loaderOnUrlEvent
    loader.GetPendingRequestCount = loaderGetPendingRequestCount

    ' When we know the full size of a container, we'll populate an array with
    ' dummy items so that the counts show up correctly on grid screens. It
    ' should generally provide a smoother loading experience. This is the
    ' metadata that will be used for pending items.
    loader.LoadingItem = {
        title: "Loading..."
    }

    return loader

End Function

'*
'* Load more data either in the currently focused row or the next one that
'* hasn't been fully loaded. The return value indicates whether subsequent
'* rows are already loaded.
'*
Function loaderLoadMoreContent(focusedIndex, extraRows=0)
    Debug("----- loaderMoreContent called: " + tostr(m.names[focusedIndex]))
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

    startItem = status.countLoaded
    if startItem = 0 then
        count = m.initialLoadSize
    else
        count = m.pageSize
    end if

    status.loadStatus = 1
    Debug("----- focusIndex = " + tostr(focusedIndex))
    Debug("----- starting request for row:" + tostr(loadingRow) + " start:" + tostr(startItem) + " stop:" + tostr(count))
    m.StartRequest(loadingRow, startItem, count)

    return extraRowsAlreadyLoaded
End Function

Sub loaderRefreshData()
   ' ljunkie - (2013-11-08) I think the MAIN thing we really care about when refreshing a grid row, is updating watched status in a row
   ' We can look at removing "watched" items in an "unwatched" row, but that may be a kludge... 
   ' This will give us some huge speed ups with a trade off of items in a row sometimes being a little stale. 
    sel_row = m.listener.selectedRow
    sel_item = m.listener.focusedindex
    if type(m.listener.contentarray) = "roArray" and m.listener.contentarray.count() >= sel_row then
        if type(m.listener.contentarray[sel_item]) = "roArray" and m.listener.contentarray[sel_item].count() >= sel_item then
            item = m.listener.contentarray[sel_row][sel_item]
            wkey = m.listener.contentarray[sel_row][sel_item].key
            if item <> invalid and type(item.refresh) = "roFunction" then 
                Debug("---- Refreshing metadata for item " + tostr(wkey))
                item.Refresh()
                ' iterate through loaded rows and update focus item
                for row = 0 to m.contentArray.Count() - 1
                    status = m.contentArray[row]
                    if status.key <> invalid AND status.loadStatus <> 0 and type(status.content) = "roArray" then 
                        isDynamic = CreateObject("roRegex", "ondeck", "i") ' unwatched? this can still cause major slow downs for some large libraries
                        if isDynamic.isMatch(status.key) then 
                            ' only reload the row if it's in view or 1 up/down
                            doLoad = (m.listener.selectedRow = row or m.listener.selectedRow = row-1 or m.listener.selectedRow = row+1)
                            if doLoad then
                                Debug("----- full reload row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
                                m.StartRequest(row, 0, m.pagesize)
                            else 
                                Debug("----- invalidate row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
                                status.loadStatus = 0 ' set to reload on focus
                                status.countloaded = 0 ' set to reload on focus
                            end if
                        else
                            Debug("----- skipping full reload - row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
                            for index = 0 to status.content.count() - 1 
                                if status.content[index] <> invalid and status.content[index].key = wkey then 
                                    status.content[index] = item
                                    Debug("---- Refreshing item " + tostr(wkey) + " in row " + tostr(row))
                                    m.listener.Screen.SetContentListSubset(row, status.content, index , 1)
                                    ' status_item.refresh() ' no need to refresh again - same item
                                    ' m.listener.Screen.SetContentList(row, status.content)
                                end if
                            end for
                        end if 
                    end if
                end for
            end if
        end if
    end if
 
    ' TO REMOVE - kept for testing/code notes
    ' newer - but old way of doing updates. This would normally try and load the entire focus row all over again. It will also invalidate other rows
    ' which in turn would reload the entire row when focused again. This has major penalties, however it did make sure we always had the most current
    ' data in the rows. A trade off for speed has deprecated this.
    '
    ' ljunkie - normally this would re-load all the rows if they have already been loaded. This will cause serious 
    ' slow downs if one loads many rows, stacks a new screen on grid, then returns to said grid. We should only 
    ' reload the focused row, and invalidate the load status of the existing. The invalidated rows on the screen
    ' will reload when selected again. 
    '        doLoad = (m.listener.selectedRow = row) ' only reload the current row, invalidate the others (that are fully loaded)
    '                                                ' we might want to reload m.listener.selectedRow+1 too.. we will see
    '        'print "------------- checking row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus)
    '
    '            if doLoad then
    '                Debug("----- skipping - loading row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
    '                'Debug("----- loading row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
    '                'm.StartRequest(row, 0, m.pageSize)
    '            else 
    '                Debug("----- skipping - invalidate row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
    '                'Debug("----- invalidate row: " + tostr(row) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
    '                'status.loadStatus = 0 ' set to reload on focus
    '                'status.countloaded = 0 ' set to reload on focus
    '            end if
    '        end if
    '    next
End Sub

Sub loaderStartRequest(row, startItem, count)
    status = m.contentArray[row]
    request = CreateObject("roAssociativeArray")

    httpRequest = m.server.CreateRequest(m.sourceUrl, status.key)
    httpRequest.AddHeader("X-Plex-Container-Start", startItem.tostr())
    httpRequest.AddHeader("X-Plex-Container-Size", count.tostr())
    request.row = row

    ' Associate the request with our listener's screen ID, so that any pending
    ' requests are canceled when the screen is popped.
    m.ScreenID = m.Listener.ScreenID

    if GetViewController().StartRequest(httpRequest, m, request) then
        status.pendingRequests = status.pendingRequests + 1
    else
        Debug("Failed to start request for row " + tostr(row) + ": " + tostr(httpRequest.GetUrl()))
    end if
 
    ' we could hack to to always highlate item 1 in row 0.. but this is just weird.     
    '    if m.listener.selectedrow <> invalid and m.listener.selectedrow = 0 then 
    '        m.Listener.screen.SetFocusedListItem(0,0)
    '    end if
End Sub

Sub loaderOnUrlEvent(msg, requestContext)
    status = m.contentArray[requestContext.row]
    status.pendingRequests = status.pendingRequests - 1

    url = requestContext.Request.GetUrl()

    if msg.GetResponseCode() <> 200 then
        Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + tostr(url) + " - " + tostr(msg.GetFailureReason()))
        return
    end if

    xml = CreateObject("roXMLElement")
    xml.Parse(msg.GetString())

    response = CreateObject("roAssociativeArray")
    response.xml = xml
    response.server = m.server
    response.sourceUrl = url
    container = createPlexContainerForXml(response)

    ' If the container doesn't play nice with pagination requests then
    ' whatever we got is the total size.
    if response.xml@totalSize <> invalid then
        totalSize = strtoi(response.xml@totalSize)
    else
        totalSize = container.Count()
    end if

    ' ljunkie - hack to limit the unwatched rows ( we can remove this if Plex ever gives us Unwatched Recently Added/Released Directories )
    ' INFO: Normally Plex will continue to load data when the "loaded content size" < "XML MediaContainer totalSize" ( status.countLoaded < totalSize )
    ' Since we are specifying the Container-Size - we will never be able to load the totalSize; reset the totalSize to "MediaContainer Size"
    '  old:  r = CreateObject("roRegex", "all\?.*X-Plex-Container-Size\=", "i")
    ' changed to allow us to use X-Plex-Container-Size= for any query - we can thing stop when request size is loaded (2013-10-13) -- fullGridScreen!
    reSize = CreateObject("roRegex", "X-Plex-Container-Size\=", "i")
    reStart = CreateObject("roRegex", "X-Plex-Container-Start\=", "i")
    isLimited = false
    isReqSize = false
    if reSize.IsMatch(container.sourceurl) then isReqSize = true
    if reSize.IsMatch(container.sourceurl) then
        isLimited = true
        totalSize = container.Count()
        Debug("----------- " + container.sourceurl)
        Debug("----------- RF isLimited (stop loading) after X-Plex-Container-Size=" + tostr(totalSize))
    end if
    ' end hack

    if totalSize <= 0 then
        status.loadStatus = 2
        startItem = 0
        countLoaded = status.content.Count()
        status.countLoaded = countLoaded
    else
        if isReqSize then
            startItem=0 ' we have specified the container start, so the first item must be zero
            Debug("----------- RF isReqSize, set startItem=0")
        else 
            startItem = firstOf(response.xml@offset, msg.GetResponseHeaders()["X-Plex-Container-Start"], "0").toInt()
        end if

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

        if totalSize > status.content.Count() then
            ' We could easily fill the entire array with our dummy loading item,
            ' but it's usually just wasted cycles at a time when we care about
            ' the app feeling responsive. So make the first and last item use
            ' our dummy metadata and everything in between will be blank.
            status.content.Push(m.LoadingItem)
            status.content[totalSize - 1] = m.LoadingItem
        end if

        if status.loadStatus <> 2 then
            status.countLoaded = startItem + countLoaded
        end if

        Debug("Count loaded is now " + tostr(status.countLoaded) + " out of " + tostr(totalSize))

        if status.loadStatus = 2 AND startItem + countLoaded < totalSize then
            ' We're in the middle of refreshing the row, kick off the
            ' next request.
            m.StartRequest(requestContext.row, startItem + countLoaded, m.pageSize)
        else if status.countLoaded < totalSize then
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

    if status.countLoaded > status.content.Count() then
        status.countLoaded = status.content.Count()
    end if

    if m.Listener <> invalid then
        m.Listener.OnDataLoaded(requestContext.row, status.content, startItem, countLoaded, status.loadStatus = 2)
    end if
End Sub

Function loaderGetLoadStatus(row)
    return m.contentArray[row].loadStatus
End Function

Function loaderGetPendingRequestCount() As Integer
    pendingRequests = 0
    for each status in m.contentArray
        pendingRequests = pendingRequests + status.pendingRequests
    end for

    return pendingRequests
End Function


function keyFiler(key as string, itype = "invalid" as string) as string
    ' this will allow us to use the New Filers in the Plex api instead of useing the simple hierarchy api calls
    newkey = key

    ' only show genres for Artists - default API call wills how artist/album genres, where album genres never have children
    if key = "genre" and itype = "artist" then 
        newkey = key + "?type=8"
    end if
 
    if newkey <> key then
        Debug("---- keyOverride for key:" + key + " type:" + itype + " to " + newkey)
    end if
    return newkey
end function
