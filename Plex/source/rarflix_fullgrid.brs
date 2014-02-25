Function createFULLGridScreen(item, viewController, style = "flat-movie", SetDisplayMode = "scale-to-fit") As Object
    dialog=ShowPleaseWait("Please wait","")

    ' hide header text of each row ( set color to BGcolor )
    hideHeaderText = false
    if RegRead("rf_fullgrid_hidetext", "preferences", "disabled") = "enabled" then hideHeaderText = true

    if style = "Invalid" then style = RegRead("rf_grid_style", "preferences", "flat-movie")

    Debug("---- Creating FULL grid with style" + tostr(style) + " SetDisplayMode:" + tostr(SetDisplayMode))

    obj = createGridScreen(viewController, style, RegRead("rf_up_behavior", "preferences", "exit"), SetDisplayMode, hideHeaderText)
    obj.Item = item
    obj.isFullGrid = true
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
    container = createPlexContainerForUrlSizeOnly(item.server, item.sourceUrl ,detailKey)    

    ' grid posters per row ( this should cover all of them as of 2013-03-04)
    grid_size = 5 ' default HD/SD=5
    if style = "flat-square" then 
        ' HD=7, SD=6
        grid_size = 7
        if NOT GetGlobal("IsHD") = true then grid_size = 6
    else if style = "flat-landscape" or style = "flat-16x9" or style = "mixed-aspect-ratio" then 
        ' HD=5, SD=4
        grid_size = 5
        if NOT GetGlobal("IsHD") = true then grid_size = 4
    else if style = "two-row-flat-landscape-custom" or style = "four-column-flat-landscape" then 
        ' HD/SD = 4
        grid_size = 4
    end if

    obj.Loader = createFULLgridPaginatedLoader(container, grid_size, grid_size, item)
    obj.Loader.Listener = obj
    ' Don't play theme music on top of grid screens on the older Roku models.
    ' It's not worth the DestroyAndRecreate headache.
    if item.theme <> invalid AND GetGlobal("rokuVersionArr", [0])[0] >= 4 AND NOT AudioPlayer().IsPlaying AND RegRead("theme_music", "preferences", "loop") <> "disabled" then
        AudioPlayer().PlayThemeMusic(item)
    end if
    obj.hasWaitdialog = dialog
    return obj
End Function

function createPlexContainerForUrlSizeOnly(server, sourceUrl, detailKey) 
    Debug("createPlexContainerForUrlSizeOnly:: determine size of xml results -- X-Plex-Container-Size=0")
    httpRequest = server.CreateRequest(sourceurl, detailKey)
    remyplex = CreateObject("roRegex", "my.plexapp.com|plex.tv", "i")        
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

    keys = []
    loader.names = []
    increment=pagesize

    ' should we keep adding the sub sections? I think not - btw this code was only to test
    '    pscreen = m.viewcontroller.screens.peek().parentscreen
    '    if pscreen <> invalid then 
    '         subsections = pscreen.loader.contentarray
    '         subsec_sourceurl = pscreen.loader.sourceurl
    '         keys.Push(subsec_sourceurl)
    '         loader.names.Push("Sub Sections")
    '    end if
    ' end testing
    'stop
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
           if this.isFullGrid = true then this.CurIndex = getFullGridCurIndex(this,CurIndex,1) ' when we load the full context, we need to fix the curindex
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
        this.CurIndex = getFullGridCurIndex(this,CurIndex,1) ' when we load the full context, we need to fix the curindex
        this.FullContext = true
        if dialog <> invalid then dialog.Close()
end sub

function getFullGridCurIndex(vc,index,default = 2) as object
    'print " ------------------ full grid index = " + tostr(index)

    screen = invalid
    screens = GetViewController().screens

    ' find the full grid screen - backtrack
    if type(screens) = "roArray" and screens.count() > 1 then 
        for sindex = screens.count()-1 to 1 step -1
            'print "checking if screen #" + tostr(sindex) + "is the fullGrid"
            if type(screens[sindex].screen) = "roGridScreen" and screens[sindex].isfullgrid <> invalid and screens[sindex].isfullgrid then
                'print "screen #" + tostr(sindex) + "is the fullGrid"
                screen = screens[sindex]
                exit for 
            end if
        next
    end if

    if screen <> invalid and type(screen.screen) = "roGridScreen" then
        srow = screen.selectedrow
        sitem = screen.focusedindex+1
        rsize = screen.contentarray[0].count()
        Debug("selected row:" + tostr(srow) + " focusedindex:" + tostr(sitem) + " rowsize:" + tostr(rsize))
        index = (srow*rsize)+sitem-1 ' index is zero based (minus 1)
    end if
    Debug(" ------------------  new grid index = " + tostr(index))
    return index
end function

