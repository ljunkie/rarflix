Function createFULLGridScreen(item, viewController, style = "flat-movie", SetDisplayMode = "scale-to-fit") As Object
    ' hide header text of each row ( set color to BGcolor )
    hideHeaderText = false
    if RegRead("rf_fullgrid_hidetext", "preferences", "disabled") = "enabled" then hideHeaderText = true

    if style = "Invalid" then style = RegRead("rf_grid_style", "preferences", "flat-movie")

    Debug("---- Creating FULL grid with style" + tostr(style) + " SetDisplayMode:" + tostr(SetDisplayMode))

    obj = createGridScreen(viewController, style, RegRead("rf_up_behavior", "preferences", "exit"), SetDisplayMode, hideHeaderText)
    obj.OriginalItem = item
    obj.grid_style = style
    obj.displaymode_grid = SetDisplayMode 
    obj.isFullGrid = true
    obj.defaultFullGrid = (item.defaultFullGrid = true)

    ' depending on the row we have, we might alrady have filters in place. Lets remove the bad ones (X-Plex-Container-Start and X-Plex-Container-Size)
    re=CreateObject("roRegex", "[&\?]X-Plex-Container-Start=\d+|[&\?]X-Plex-Container-Size=\d+|now_playing", "i")
    if item.key = invalid then return invalid

    item.key = re.ReplaceAll(item.key, "")    

    ' yea, we still need to figure out what section type we are in
    vc_metadata = getSectionType()
    item.key = keyFiler(item.key,tostr(vc_metadata.type)) ' ljunkie - allow us to use the new filters for the simple keys

    ' check if key is a loader row index.. and strip it
    detailKey = item.key
    if viewController.home <> invalid and  type(viewController.home.loader) = "roAssociativeArray" and type(viewController.home.loader.rowindexes) = "roAssociativeArray" then
        for each rkey in viewController.home.loader.rowindexes
             if rkey = item.key then 
                 detailKey = ""
                 exit for
             end if
        end for 
    end if

    'container = createPlexContainerForUrl(item.server, item.sourceUrl, detailKey)
    '  just need a quick way to create a plexContainer request with 0 results returned ( to be quick )
    ' apply the choosen filters if set for this section/server
    container = createPlexContainerForUrlSizeOnly(item.server, item.sourceUrl ,detailKey)    

    ' grid posters per row ( this should cover all of them as of 2013-03-04)
    grid_row_size = 5 ' default HD/SD=5
    if style = "flat-square" then 
        ' HD=7, SD=6
        grid_row_size = 7
        if NOT GetGlobal("IsHD") = true then grid_row_size = 6
    else if style = "flat-landscape" or style = "flat-16x9" or style = "mixed-aspect-ratio" then 
        ' HD=5, SD=4
        grid_row_size = 5
        if NOT GetGlobal("IsHD") = true then grid_row_size = 4
    else if style = "two-row-flat-landscape-custom" or style = "four-column-flat-landscape" then 
        ' HD/SD = 4
        grid_row_size = 4
    end if
    obj.gridRowSize = grid_row_size
    ' apply the choosen filters if set for this section/server
    if item.key = "all" then 
        obj.isFilterable = true
        filterSortObj = getFilterSortParams(container.server,container.sourceurl)
        obj.hasFilters = filterSortObj.hasFilters
        if obj.hasFilters = true then 
            container.hasFilters = obj.hasFilters
            container.sourceurl = addFiltersToUrl(container.sourceurl,filterSortObj)
        end if
    end if

    obj.Loader = createFULLgridPaginatedLoader(container, grid_row_size, grid_row_size, item)
    obj.Loader.isFilterable = (obj.isFilterable = true)
    obj.Loader.Listener = obj
    ' Don't play theme music on top of grid screens on the older Roku models.
    ' It's not worth the DestroyAndRecreate headache.
    if item.theme <> invalid AND GetGlobal("rokuVersionArr", [0])[0] >= 4 AND NOT AudioPlayer().IsPlaying AND RegRead("theme_music", "preferences", "loop") <> "disabled" then
        AudioPlayer().PlayThemeMusic(item)
    end if

    return obj
End Function

function createPlexContainerForUrlSizeOnly(server, sourceUrl, detailKey) 
    Debug("createPlexContainerForUrlSizeOnly:: determine size of xml results -- X-Plex-Container-Size=0 ; " + tostr(sourceUrl) + ", " + tostr(detailKey))
     
    httpRequest = server.CreateRequest(sourceurl, detailKey)
    ' THIS IS VERY IMPORTANT containter and start size of 0
    httpRequest.AddHeader("X-Plex-Container-Start", "0")
    httpRequest.AddHeader("X-Plex-Container-Size", "0")

    fullSourceUrl = httpRequest.GetUrl()
    if detailKey = "all" then 
        filterSortObj = getFilterSortParams(server,fullSourceUrl)
        if filterSortObj <> invalid then 
            fullSourceUrl = addFiltersToUrl(fullSourceUrl,filterSortObj)
            httpRequest.seturl(fullSourceUrl)
        end if
    end if

    Debug("Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
    ' used to be 60 seconds, but upped to 90 -- I still think this is too high. If the server isn't responding with to a request of 0 items, something must be wrong. 
    response = GetToStringWithTimeout(httpRequest, 90)
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then Debug("Can't parse feed: " + tostr(response))
    Debug("Finished - Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
    Debug("Total Items: " + tostr(xml@totalsize) + " size returned: " + tostr(xml@size))
    container = {}
    ' cloudsync doesn't contain a totalsize (yet)
    if xml@totalsize <> invalid then 
        container.totalsize = xml@totalsize
    else 
        container.totalsize = xml@size
    end if
    container.sourceurl = httpRequest.GetUrl()
    container.server = server
    return container
end function

Function createFULLgridPaginatedLoader(container, initialLoadSize, pageSize, item = invalid as dynamic)

    loader = CreateObject("roAssociativeArray")
    initDataLoader(loader)

    loader.server = container.server
    loader.sourceUrl = container.sourceUrl
    totalsize = container.totalsize
    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize
    loader.contentArray = []
 
    if totalsize = invalid or totalsize.toInt() < 1 then 
        dialog = createBaseDialog()
        if container.hasFilters = true then 
            dialog.Title = "No Results"
            if item.defaultFullGrid = true then 
                dialog.Text = "The filter selection results are empty."
            else 
                ' we must clear the filters for anyone not using a full grid by default -- they don't get a header row and the grid will close
                dialog.Text = "The filter selection results are empty. Clearing all filters"
                clearFiltersForUrl(item.server,item.sourceurl)
            end if
        else 
            dialog.Title = "No Results"
            dialog.Text = "This section doesn't contain any items"
        end if 
        dialog.Show(true)
    end if

    keys = []
    loader.names = []
    increment=pagesize

    ' include the header row on the full grid ONLY if we have set this section to default to Full Grid - 
    ' otherwise users already see a header row on the previous grid screen
    headerRow = []
    if item <> invalid and item.defaultFullGrid = true and item.key = "all" and loader.server <> invalid and loader.sourceurl <> invalid then 
        sectionKey = getBaseSectionKey(loader.sourceurl)
        container = createPlexContainerForUrl(loader.server, invalid, sectionKey)
        rawItems = container.GetMetadata() ' grab subsections for FULL grid. We might want to hide some (same index as container.GetKeys())

        for index = 0 to rawItems.Count() - 1
            'if rawItems[index].secondary = invalid and tostr(rawItems[index].key) <> "all"then
            if tostr(rawItems[index].key) <> "all"then
                headerRow.Push(rawItems[index])
            end if
        end for
        ReorderItemsByKeyPriority(headerRow, RegRead("section_row_order", "preferences", ""))

        ' Put Filters before any others
        filterItem = createSectionFilterItem(loader.server,loader.sourceurl,item.type)
        if filterItem <> invalid then headerRow.Unshift(filterItem)
        loader.hasHeaderRow = true
    end if

    ' should we keep adding the sub sections? I think not - btw this code was only to test
    '    pscreen = m.viewcontroller.screens.peek().parentscreen
    '    if pscreen <> invalid then 
    '         subsections = pscreen.loader.contentarray
    '         subsec_sourceurl = pscreen.loader.sourceurl
    '         keys.Push(subsec_sourceurl)
    '         loader.names.Push("Sub Sections")
    '    end if
    ' end testing

    if totalsize <> invalid then 
        for index = 0 to totalsize.toInt() - 1 step increment

            ' verify we are using the filter URL
            'filterURL(loader.sourceurl)

            num_to = index+increment
            if num_to > totalsize.toInt() then num_to = totalsize.toInt()
            name = tostr(index+1) + "-" + tostr(num_to) + " of " + totalsize
            f = "?"
            if instr(1, loader.sourceurl, "?") > 0 then f = "&"
            ' this will limit the grid to 5k items. TODO(ljunkie) we may have to load more?
            if index < 5000 then 
                keys.Push(loader.sourceurl + f + "X-Plex-Container-Start="+tostr(index)+"&X-Plex-Container-Size="+tostr(increment))
                loader.names.Push(name)
            end if
        next

        for index = 0 to keys.Count() - 1
            status = CreateObject("roAssociativeArray")
            status.content = []
            status.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
            status.key =  keys[index]
            status.name = loader.names[index]
            status.pendingRequests = 0
            status.countLoaded = 0
    
            loader.contentArray[index] = status
        end for

        for index = 0 to loader.contentArray.Count() - 1
            status = loader.contentArray[index]
            loader.names[index] = status.name
        next

    end if
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

    ' add the special header row
    if headerRow <> invalid and headerRow.count() > 0 then 
        header_row = CreateObject("roAssociativeArray")
        header_row.content = headerRow
        header_row.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
        header_row.key = "_subsec_"
        header_row.name = firstof(item.title,"Sub Sections")
        header_row.pendingRequests = 0
        header_row.countLoaded = 0
    
        loader.contentArray.Unshift(header_row)
        keys.Unshift(header_row.key)
        loader.names.Unshift(header_row.name)
        loader.focusrow = 1 ' we want to hide this row by default
    end if

    ' clean keys that should be "invalid"
    for index = 0 to loader.contentArray.Count() - 1
        status = loader.contentArray[index]
        loader.names[index] = status.name
        if status.key = "_search_"  or status.key = "_subsec_" then
            status.key = invalid
        end if
    next

    return loader
End Function


    ' find the full grid screen - backtrack

function fromFullGrid(parentOnly=false) as boolean

    screens = GetViewController().screens
    if type(screens) = "roArray" and screens.count() > 1 then 
        ' only true if the parent is a full grid screen
        if parentOnly then 
            pscreen = screens[screens.count()-2]
            if pscreen <> invalid and pscreen.screen <> invalid and type(pscreen.screen) = "roGridScreen" and pscreen.isfullgrid = true then
                return true
            else 
               Debug("parent screen is NOT a full grid")
               return false
            end if
        end if

        ' just verifying if we are from a full grid - doesn't have to be the exact parent
        for sindex = screens.count()-1 to 1 step -1
            'print "checking if screen #" + tostr(sindex) + "is the fullGrid"
            if type(screens[sindex].screen) = "roGridScreen" and screens[sindex].isfullgrid = true then
                return true
                exit for 
            end if
        next
    end if

    return false
end function

sub GetContextFromFullGrid(this,curindex = invalid) 
        ' stop realoding the full context ( but we still might need to reset the CurIndex )
        if this.FullContext = true then 
           ' if we are still in the full grid, we will have to caculate the index again ( rows are only 5 items -- curIndex is always 0-5 )
           if this.isFullGrid = true then this.CurIndex = getFullGridCurIndex(CurIndex) ' when we load the full context, we need to fix the curindex
           return
        end if

        Debug("------context from full grid")

        if this.metadata.sourceurl = invalid then return

        if curindex = invalid then curindex = this.curindex

        ' strip any limits - we need it all ( now start or container size)
        newurl = rfStripAPILimits(this.metadata.sourceurl)

        'r  = CreateObject("roRegex", "[?&]X-Plex-Container-Start=\d+\&X-Plex-Container-Size\=.*", "")
        'newurl = this.metadata.sourceurl
        'Debug("--------------------------- OLD " + tostr(newurl))
        'if r.IsMatch(newurl) then  newurl = r.replace(newurl,"")

        ' man I really created a nightmare adding the new unwatched rows for movies.. 
        ' the source URL may have ?type=etc.. to filter
        ' the hack I have in PlexMediaServer.brs FullUrl() requires 'filter' to be prepended to the key
        ' TODO(ljunkie) clean this up -- find out were "filter" is used and instead ONLY use the key 
        ' field of createPlexContainerForUrl()
        key = ""
        rkey  = CreateObject("roRegex", "(.*)(\?.*)","")
        new_key = rkey.match(newurl)
        if new_key.count() > 2 and new_key[1] <> invalid and new_key[2] <> invalid then 
          newurl = new_key[1]
          key = "filter" + new_key[2]
        end if
        ' end Hack for special filtered calls

        Debug("--------------------------- NEW " + tostr(newurl) + " key " + tostr(key))
        obj = createPlexContainerForUrl(this.metadata.server, newurl, key)

        dialog = invalid
        ' only show wait dialog when the container size is a bit large (300 or more?)
        size = obj.xml@size
        if size <> invalid and size.toInt() > 300 then 
            dialog=ShowPleaseWait("Loading " + tostr(size) + " items. Please wait...","")
        end if 

        obj.getmetadata()
        obj.context = obj.metadata
        this.context = obj.context
        this.CurIndex = getFullGridCurIndex(CurIndex) ' when we load the full context, we need to fix the curindex
        this.FullContext = true
        if dialog <> invalid then dialog.Close()
end sub

' this function backtracks through the screen stack to find the first
' full grid and return the curIndex based on the selected row/row item count
' I.E. the hacky full grid, a selected item is 0-5 in every row, so row 4
' curIndex might be 4 when in reality it's (row*item_in_row)+curindex 
function getFullGridCurIndex(index) as object
    screen = invalid
    screens = GetViewController().screens

    ' find the full grid screen - backtrack
    if type(screens) = "roArray" and screens.count() > 1 then 
        for index = screens.count()-1 to 1 step -1
            'print "checking if screen #" + tostr(index) + "is the fullGrid"
            if type(screens[index].screen) = "roGridScreen" and screens[index].isfullgrid = true then
                'print "screen #" + tostr(index) + "is the fullGrid"
                screen = screens[index]
                exit for 
            end if
        end for
    end if

    if screen <> invalid and type(screen.screen) = "roGridScreen" then
        selRow = int(screen.selectedrow)        
        if screen.loader.hasHeaderRow = true then selRow = selRow-1
        Debug("selected row:" + tostr(selRow) + " focusedindex:" + tostr(screen.focusedindex) + " rowsize:" + tostr(screen.gridRowSize))
        index = (selRow*screen.gridRowSize)+screen.focusedindex
    end if
    Debug(" ------------------  new grid index = " + tostr(index))
    return index
end function

