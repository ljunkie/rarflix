Function createFULLGridScreen(item, viewController, style = "flat-movie") As Object
    if style = "Invalid" then style = RegRead("rf_grid_style", "preferences", "flat-movie")

    obj = createGridScreen(viewController, style)
    obj.Item = item

    ' depending on the row we have, we might alrady have filters in place. Lets remove the bad ones (X-Plex-Container-Start and X-Plex-Container-Size)
    re=CreateObject("roRegex", "[&\?]X-Plex-Container-Start=\d+|[&\?]X-Plex-Container-Size=\d+|now_playing", "i")
    if item.key = invalid then return invalid

    item.key = re.ReplaceAll(item.key, "")    

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
    for index = 0 to size.toInt() - 1 step increment
        num_to = index+increment
        if num_to > (container.xml@size).toInt() then num_to = (container.xml@size).toInt()
        name = tostr(index+1) + "-" + tostr(num_to) + " of " + container.xml@size
        f = "?"
	if instr(1, loader.sourceurl, "?") > 0 then f = "&"
        keys.Push(loader.sourceurl + f + "X-Plex-Container-Start="+tostr(index)+"&X-Plex-Container-Size="+tostr(increment))
        loader.names.Push(name)
    next

    print keys[0]
    print keys[0]

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
