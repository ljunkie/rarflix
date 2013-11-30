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
    vc_metadata = getSectionType(viewController)
    item.key = keyFiler(item.key,tostr(vc_metadata.type)) ' ljunkie - allow us to use the new filters for the simple keys

    container = createPlexContainerForUrl(item.server, item.sourceUrl, item.key)

    if style = "flat-square" then 
        grid_size = 7
    else 
        grid_size = 5
    end if    
    container.SeparateSearchItems = true   


    obj.Loader = createFULLgridPaginatedLoader(container, grid_size, grid_size, item)
    obj.Loader.Listener = obj
    ' Don't play theme music on top of grid screens on the older Roku models.
    ' It's not worth the DestroyAndRecreate headache.
    if item.theme <> invalid AND GetGlobal("rokuVersionArr", [0])[0] >= 4 AND NOT obj.ViewController.AudioPlayer.IsPlaying AND RegRead("theme_music", "preferences", "loop") <> "disabled" then
        obj.ViewController.AudioPlayer.PlayThemeMusic(item)
        obj.Cleanup = baseStopAudioPlayer
    end if
    obj.hasWaitdialog = dialog
    return obj
End Function


Function createFULLgridPaginatedLoader(container, initialLoadSize, pageSize, item = invalid as dynamic)

    loader = CreateObject("roAssociativeArray")
    initDataLoader(loader)

    loader.server = container.server
    loader.sourceUrl = container.sourceUrl

    loader.initialLoadSize = initialLoadSize
    loader.pageSize = pageSize

    loader.contentArray = []

    size = container.xml@size
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

    if size <> invalid then 
        for index = 0 to size.toInt() - 1 step increment
            num_to = index+increment
            if num_to > (container.xml@size).toInt() then num_to = (container.xml@size).toInt()
            name = tostr(index+1) + "-" + tostr(num_to) + " of " + container.xml@size
            f = "?"
            if instr(1, loader.sourceurl, "?") > 0 then f = "&"
            keys.Push(loader.sourceurl + f + "X-Plex-Container-Start="+tostr(index)+"&X-Plex-Container-Size="+tostr(increment))
            loader.names.Push(name)
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


function fromFullGrid(vc) as boolean
    Debug("---- checking if we came from a full grid view")
    if type(vc.screens) = "roArray" then
        screens = vc.screens
        minus = 1
    else if type(vc.viewcontroller) = "roAssociativeArray" then
        screens = vc.viewcontroller.screens
        minus = 2
    end if

    if type(screens) = "roArray" and screens.count() > 0 then
        prev_screen = screens[screens.count()-minus]
        if prev_screen.isfullgrid <> invalid then
            Debug("---- previous screen was a FULL grid")
            return true
        end if
    end if

    return false
end function


sub GetContextFromFullGrid(this,curindex = invalid) 
        if this.metadata.sourceurl = invalid then return

        if curindex = invalid then curindex = this.curindex
        'dialog=ShowPleaseWait("Please wait","")
        ' strip any limits - we need it all ( now start or container size)
        r  = CreateObject("roRegex", "[?&]X-Plex-Container-Start=\d+\&X-Plex-Container-Size\=.*", "")
        newurl = this.metadata.sourceurl
        Debug("--------------------------- OLD " + tostr(newurl))
        if r.IsMatch(newurl) then  newurl = r.replace(newurl,"")

        ' man I really created a nightmare adding the new unwatched rows for movies.. 
        ' the source URL may have ?type=etc.. to filter
        ' the hack I have in PlexMediaServer.brs FullUrl() requires 'filter' to be prepended to the key
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