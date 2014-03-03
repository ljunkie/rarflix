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
    '
    ' 2014-02-16 - music section: firstCharacter
    '              newItems roAssocArray now holds the extra rows - should be easier to add more later or modify all at once
    newItems = []
    size_limit = RegRead("rf_rowfilter_limit", "preferences","200") 'gobal size limit Toggle for filter rows

    if type(item) = "roAssociativeArray" and item.contenttype = "section" and item.type = "artist" then 
        newItems.push({key: "firstCharacter", title: "First Letter", key_copy: "all"})
        newItems.push({key: "recentlyViewed", title: "Recently Viewed", key_copy: "all"})
    end if

    if type(item) = "roAssociativeArray" and item.contenttype = "section" and item.type = "show" then 
        newItems.push({key: "recentlyAdded?stack=1", title: "Recently Added Seasons", key_copy: "all"})
        newItems.push({key: "all?timelineState=1&type=4&unwatched=1&sort=originallyAvailableAt:desc", title: "Unwatched Recently Aired", key_copy: "all"})
        newItems.push({key: "all?timelineState=1&type=4&unwatched=1&sort=addedAt:desc", title: "Unwatched Recently Added", key_copy: "all", size: size_limit})
    end if

    if type(item) = "roAssociativeArray" and item.contenttype = "section" and item.type = "movie" then 
        newItems.push({key: "all?type=1&unwatched=1&sort=originallyAvailableAt:desc", title: "Unwatched Recently Released", key_copy: "all", size: size_limit})
        newItems.push({key: "all?type=1&unwatched=1&sort=addedAt:desc", title: "Unwatched Recently Added", key_copy: "all", size: size_limit})
    end if

    subsec_extras = []
    if newItems.count() > 0 then 
        for each newItem in newItems            
            if RegRead("rf_hide_"+newItem.key, "preferences", "show") = "show" then 
                new_key = newItem.key
                if newItem.size <> invalid then 
                    new_key = new_key + "&X-Plex-Container-Start=0&X-Plex-Container-Size=" + size_limit
                end if
                keys.Push(new_key)
                loader.names.Push(newItem.title)
                subsec_extras.Push({ key: new_key, name: newItem.title, key_copy: newItem.key_copy })
            end if
        end for
    end if

    ' we will have to add the custom rows to the subsections too ( quick filter row (0) for the full grid )
    if subsec_extras.count() > 0 and subsecItems.count() > 0 then
        template = invalid
        for each sec in subsec_extras
            for index = 0 to subsecItems.Count() - 1
                if subsecItems[index].key = sec.key_copy  then 
                    template = subsecItems[index]
                    exit for
                end if
            end for
            if template <> invalid then 
                copy = ShallowCopy(template,2) ' really? brs doesn't have a clone/copy
                ' now set the uniq characters
                copy.key = sec.key
                copy.name = sec.name
                copy.umtitle = sec.name
                copy.title = sec.name
                rfCDNthumb(copy,sec.name,invalid)
                subsecItems.Push(copy)
             end if
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

            ' add the filter item to the row ( first ). This item, when when viewed & closed will close 
            ' the gridScreen and recreate a full grid with the chosen filter/sorts
            filterItem = createSectionFilterItem(loader.server,loader.sourceurl,item.type)
            if filterItem <> invalid then 
                filterItem.forceFilterOnClose = true
                subsecItems.Unshift(filterItem)
            end if

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
    if focusedIndex < 0 then return true

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

    ' ljunkie - this halt the paginated data loader if we have stacked a new screen on top
    ' this should speed up things like the springboard when entering all movies or any rows with thousands of items
    ' we will continue to load items if we don't have many... otherwise stop for rows with thousands of items   
    screen = GetViewController().screens.peek()
    if screen.loader = invalid or screen.loader.screenid <> m.screenid then
        total = status.content.Count()
        if total-startItem > 500 then 
            Debug("loaderLoadMoreContent:: " + tostr(m.names[loadingRow]))
            Debug("loaderLoadMoreContent:: halt loading the rest until we re-enter the screen ( more than 500 left to load )")
            return true  
        end if
    end if

    status.loadStatus = 1
    Debug("----- starting request for row:" + tostr(m.names[loadingRow]) + " : " + tostr(loadingRow) + " start:" + tostr(startItem) + " stop:" + tostr(count))
    m.StartRequest(loadingRow, startItem, count)

    return extraRowsAlreadyLoaded
End Function

Sub loaderRefreshData()
   ' ljunkie - (2013-11-08) I think the MAIN thing we really care about when refreshing a grid row, is updating watched status in a row
   ' We can look at removing "watched" items in an "unwatched" row, but that may be a kludge...
   ' This will give us some huge speed ups with a trade off of items in a row sometimes being a little stale. 
   '  UPDATED: 2013-12-03: 
   '  * Always full reload the onDeck row
   '  * only do a full reload once every 90 seconds ( only for isDynamic regex matches )
   '  * EU can choose Partial|Full reload. Partial will only reload the focused item, for people still having speed issues
   '  * Check the focused item index against the PMS api. If keys do not match, full reload will happen. Usually marking as watched/unwatched/new items added
   '  * FULL Grid screens will always get a full reload. They are fast enough since we only load 5 items per row ( 20 max rows reloaded instantly )
    sel_row = m.listener.selectedRow
    sel_item = m.listener.focusedindex
    if type(m.listener.contentarray) = "roArray" and m.listener.contentarray.count() >= sel_row then
        if type(m.listener.contentarray[sel_row]) = "roArray" and m.listener.contentarray[sel_row].count() >= sel_item then
            item = m.listener.contentarray[sel_row][sel_item]

            ' include what is filtered in popout
            if item <> invalid and tostr(item.viewgroup) = "section_filters" then 
                item.description = getFilterSortDescription(item.server,item.sourceurl)
                m.listener.Screen.SetContentListSubset(m.listener.selectedRow, m.listener.contentArray[m.listener.selectedRow], m.listener.focusedIndex, 1)
            end if

            contentType = tostr(item.contenttype)
            isFullGrid = (m.listener.isfullgrid = true)

            supportedIdentifier = (item.mediaContainerIdentifier = "com.plexapp.plugins.library" OR item.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
            ' it's possible we are returning from a full grid. The focus item will not be supported ( special row )
            if NOT supportedIdentifier and NOT isFullGrid then 
                Debug("trying the listener item -- could be coming from a full grid")
                if m.listener.item <> invalid then 
                    supportedIdentifier = (m.listener.item.mediaContainerIdentifier = "com.plexapp.plugins.library" OR m.listener.item.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
                end if
            end if

            ' skip FullGrid reload if the item is a photo or music item
            if isFullGrid and m.sortingForceReload = invalid then 
                 if contentType = "photo" or contentType = "album" or contentType = "artist" or contentType = "track" then 
                    Debug("----- skip FULL grid reload -- contentType doesn't require it (yet) " + tostr(contentType))
                    return
                 end if
            end if


            if (item <> invalid and type(item.refresh) = "roFunction") or (m.sortingForceReload <> invalid) then 
                wkey = m.listener.contentarray[sel_row][sel_item].key
                Debug("---- Refreshing metadata for item " + tostr(wkey) + " contentType: " + contentType)
                if RegRead("rf_grid_dynamic", "preferences", "full") <> "full" then item.Refresh() ' refresh for pref of partial reload

                ' iterate through loaded rows and update focused item or fully reload row if focused item index differs from PMS api
                for row = 0 to m.contentArray.Count() - 1
                    status = m.contentArray[row]
                    if status.key <> invalid AND status.loadStatus <> 0 and type(status.content) = "roArray" then 
                        ' some are more safe to reload - limit of < 100 items (recentlyAdded?stack=1,others?)
                        ' this can be toggled to skip full reload ( rf_grid_dynamic: [full|partial] )
                        doFullReload = false    ' will reload focused row (+/- MinMaxRow, invalidate the rest)
                        forceFullReload = false ' will always reload the row - no questions

                        ' for now, we will only ever FULLY reload a row if the key is in the regex below
                        ' TODO: depending on how these new changes work, we might want to open this up to all ( since we have a expire time )
                        ' this is only when someone stacks a screen on top of the grid. Grids will always reload when they are re-created.
                        if RegRead("rf_grid_dynamic", "preferences", "full") = "full" then 
                            isDynamic = CreateObject("roRegex", "recentlyAdded\?stack=1|unwatched", "i") ' unwatched? this can still cause major slow downs for some large libraries
                            if isDynamic.isMatch(status.key) then doFullReload = true
                        end if

                        ' Only do a full reload if the time since last reload on the row > x seconds
                        lastReload = GetGlobalAA().Lookup("GridFullReload"+status.key)
                        expireSec = 90 ' set the row to expire in X seconds ( keeps things less stale ) -- reload will still happen upon re-entering parent Grid when content changes
                        Debug("---- last reload: " + tostr(lastReload))

                        ' initial reload - set it so we skip the first
                        epoch = getEpoch()
                        if lastReload = invalid then 
                            lastReload = epoch
                            GetGlobalAA().AddReplace("GridFullReload"+status.key, epoch) 
                        end if

                        ' Override FULL reload (set to false) if we have recently reloaded

                        if lastReload <> invalid and type(lastReload) = "roInteger" then 
                            diff = epoch-lastReload
                            if diff < expireSec and NOT isFullGrid then 
                                doFullReload = false
                                Debug("---- Skipping Full Reload: " + tostr(diff) + " seconds < expire seconds " + tostr(expireSec))
                                ' we might think about updating the last epoch here too.. if someone keeps entering/exiting the grid
                                ' for now we will expire at 5 minutes. 
                            else
                                Debug("---- Full Reload Pending: " + tostr(diff) + " seconds > expiry seconds " + tostr(expireSec))
                                GetGlobalAA().AddReplace("GridFullReload"+status.key, epoch)
                            end if
                        end if

                        forceFull = CreateObject("roRegex", "ondeck", "i") ' for now, onDeck is special. We will always reload it
                        if forceFull.isMatch(status.key) then forceFullReload = true

                        ' rows above and below focused row to be fully reloaded ( if doFullReload )
                        MinMaxRow = 1 ' default to 1 up/down from the focused row

                        if isFullGrid
                            ' the full grid kinda sucks, if items are removed/added then 
                            '  all rows will have to be updated at some point. We cannot
                            '  reload every row every time ( huge performace impact )
                            doFullReload = true 
                            MinMaxRow = 2 ' load up to 2 rows ( up/down ) -- invalidate the others
                        end if


                        if NOT supportedIdentifier and m.sortingForceReload = invalid then 
                            Debug("----- skip FULL grid reload -- not a supported identifier " + tostr(supportedIdentifier))
                            doFullReload = false:forceFullReload = false
                        end if

                        ' skip FullGrid reload if the item is a photo or music item
                        ' we do this check earlier, but later on depending on PMS features, we might have to remove it and 
                        ' try to reload the specific item. This is were we can do this
                        if isFullGrid and m.sortingForceReload = invalid then 
                             if contentType = "photo" or contentType = "album" or contentType = "artist" or contentType = "track" then 
                                Debug("----- skip FULL grid reload -- contentType doesn't require it (yet) " + tostr(contentType))
                                doFullReload = false:forceFullReload = false
                             end if
                        end if

                        ' Either the last reload expired or we are forcing a full reload ( ondeck/fullgrid )
                        if doFullReload or forceFullReload then 
                            ' always load the focused row
                            doLoad = (m.listener.selectedRow = row)

                            ' other rows (not in focus) let's check if we want to fully reload it
                            '      reload: if the row = focusedRow -+ minMaxRows 
                            '  invalidate: any other row ( it will reload when in view again )
                            if NOT doLoad and MinMaxRow > 0 then 
                                if m.listener.selectedRow < MinMaxRow then minMaxRow = minMaxRow*2
                                for index = 1 to MinMaxRow
                                    doLoad = (m.listener.selectedRow+index = row or m.listener.selectedRow-index = row)
                                    if doLoad then exit for
                                end for
                            end if 

                            if doLoad or forceFullReload then
                                Debug("----- Full Reload NOW: " + tostr(row) + " key:" + tostr(status.key) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
                                m.StartRequest(row, 0, m.pagesize)
                            else 
                                Debug("----- Invalidate Row: " + tostr(row) + " key:" + tostr(status.key) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
                                status.loadStatus = 0 ' set to reload on focus
                                status.countloaded = 0 ' set to reload on focus
                            end if
                        ' Skipping a FULL row reload, but refreshing the ITEM. 
                        ' If the item key has changed, full reload is in full effect again ( unless partial pref selected )
                        else
                            Debug("----- skipping full reload (verify pending item) - row: " + tostr(row) + " key:" + tostr(status.key) + " name:" + tostr(m.names[row]) + ", loadStatus=" + tostr(status.loadStatus))
                             
                            ' Query the focused items source url/container key and reload it
                            ' if the item is not longer the same after we query for it, it was removed (watched) or 
                            ' new items have been added: remove and update row
                            for index = 0 to status.content.count() - 1 
                                if status.content[index] <> invalid and status.content[index].key = wkey then 
                                    ' ONLY reload the item if somone disabled FULL reload in prefs
                                    if RegRead("rf_grid_dynamic", "preferences", "full") <> "full" then 
                                        Debug("---- (PARTIAL reload) Refreshing item " + tostr(wkey) + " in row " + tostr(row))
                                        status.content[index] = item
                                        m.listener.Screen.SetContentListSubset(row, status.content, index , 1)
                                    else 
                                        ' some keys already include the X-Plex-Container-Start=/X-Plex-Container-Size parameters
                                        ' remove said paremeters so we can query for Start=Index and Size=1 ( for the specific item )
                                        newKey = rfStripAPILimits(status.key)
                                        joinKey = "?"
                                        if Instr(1, newKey, "?") > 0 then joinKey = "&"

                                        startOffset = index

                                        ' startOffset will be (selectedRow*itemsInRow)+focusedIndex in a full grid screen
                                        if isFullGrid = true then 
                                            selRow = m.listener.selectedrow
                                            rowSize = m.listener.gridRowSize
                                            if m.hasHeaderRow = true and selRow > 0 then selRow = selRow-1
                                            startOffset = (selRow*rowSize)+m.listener.focusedindex
                                        end if
                                        newkey = newKey + joinKey + "X-Plex-Container-Start="+tostr(startOffset)+"&X-Plex-Container-Size=1"
                                        container = createPlexContainerForUrl(m.listener.loader.server, m.listener.loader.sourceurl, newKey)
                                        context = container.getmetadata()

                                        ' Remove the item from the row if the original/new keys are different ( removed, usually marked as watched )
                                        ' change: we cannot assume the item is just watched and remove it. It's possible new content was added and 
                                        ' offsets have changed, so we will have to reload. Also invalidate all row if fullGrid
                                        if context[0] = invalid or status.content[index].key <> context[0].key
                                            Debug("---- FULL reload forced - item removed(watched/new additions) " + tostr(wkey) + " in row " + tostr(row))
                                            status.content.Delete(index) ' delete right away - for a quick update, then reload
                                            if status.content.Count() > 0 then m.listener.Screen.SetContentList(row, status.content)
                                            m.StartRequest(row, 0, m.pagesize)
                                            ' if the items have changed in a full row, then we need to invalidate the the all rows above and beneath
                                            if isFullGrid = true then 
                                                for invalid_row = 0 to m.contentArray.Count() - 1
                                                    if invalid_row <> row then 
                                                        rowReset = m.contentArray[invalid_row]
                                                        Debug("----- Invalidate Row: " + tostr(invalid_row) + " key:" + tostr(rowReset.key) + " name:" + tostr(m.names[invalid_row]) + ", loadStatus=" + tostr(rowReset.loadStatus))
                                                        rowReset.loadStatus = 0
                                                        rowReset.countloaded = 0
                                                    end if
                                                end for
                                            end if
                                            ' Update the item in the row if the original/new key are the same ( same item )
                                        else
                                            Debug("---- refreshing item " + tostr(wkey) + " in row " + tostr(row))
                                            status.content[index] = context[0]
                                            if contentType = "photo" and item.GridDescription <> invalid then 
                                                ' we probably don't need to use the reloaded item, but why not
                                                status.content[index].MediaInfo = item.MediaInfo
                                                status.content[index].Description = item.GridDescription
                                                status.content[index].GridDescription = item.GridDescription
                                            end if
                                            m.listener.Screen.SetContentListSubset(row, status.content, index , 1)
                                        end if 
                                    end if

                                end if
                            end for
                        end if 
                    end if
                end for
            end if
        end if
    end if

    if m.sortingForceReload <> invalid then m.sortingForceReload = invalid
 
    ' UGH -- TODO the above nesting is crazy
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
