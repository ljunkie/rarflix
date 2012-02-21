'*
'* A grid screen backed by XML from a PMS.
'*

Function createGridScreen() As Object
    Print "######## Creating Grid Screen ########"

    screen = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")

    grid.SetMessagePort(port)
    grid.SetDisplayMode("photo-fit")
    grid.SetGridStyle("Flat-Movie")
    grid.SetUpBehaviorAtTopRow("exit")

    screen.Grid = grid
    screen.Show = showGridScreen
    screen.LoadContent = loadGridContent
    screen.SetStyle = setGridStyle
    screen.timer = createPerformanceTimer()
    screen.port = port
    screen.selectedRow = 0
    screen.maxLoadedRow = -1
    screen.contentArray = []
    screen.gridStyle = "Flat-Movie"

    screen.extraRowsToLoad = 2
    screen.initialLoadSize = 8
    screen.pageSize = 50

    return screen
End Function

Function showGridScreen(section) As Integer
    print "Showing grid for section: "; section.key

    totalTimer = createPerformanceTimer()

    server = section.server
    queryResponse = server.GetQueryResponse(section.sourceUrl, section.key)
    m.timer.PrintElapsedTime("Initial server query")
    names = server.GetListNames(queryResponse)
    m.timer.PrintElapsedTime("Server GetListNames")
    keys = server.GetListKeys(queryResponse)
    m.timer.PrintElapsedTime("Server GetListKeys")
	
    m.Grid.SetupLists(names.Count()) 
    m.timer.PrintElapsedTime("Grid SetupLists")
    m.Grid.SetListNames(names)
    m.timer.PrintElapsedTime("Grid SetListNames")

    ' Show the grid now. It'll automatically show some Retrieving... text so
    ' we don't have to show a one line dialog.
    m.Grid.Show()

    ' Only two rows and five items per row are visible on the screen, so
    ' don't load much more than we need to before initially showing the
    ' grid. Once we start the event loop we can load the rest of the
    ' content.

    maxRow = keys.Count() - 1
    if maxRow > 1 then maxRow = 1

    rowIndex = 0
    for row = 0 to keys.Count() - 1
        m.contentArray[row] = []

        if row <= maxRow then
            Print "Loading beginning of row "; row; ", "; keys[row]
            m.LoadContent(server, queryResponse.sourceUrl, keys[row], row, 0, m.initialLoadSize)
        end if

        rowIndex = rowIndex + 1
    end for

    totalTimer.PrintElapsedTime("Total initial grid load")

    ' We'll use a small timeout to continue loading data as needed. Once we've
    ' finished loading data, reset the timeout to 0 so that we don't continue
    ' to get notified.
    timeout = 5

    while true
        msg = wait(timeout, m.port)
        if type(msg) = "roGridScreenEvent" then
            if msg.isListItemSelected() then
                row = msg.GetIndex()
                col = msg.GetData()
                item = m.contentArray[row][col]
                contentType = item.ContentType
                if contentType = "movie" OR contentType = "episode" then
                    displaySpringboardScreen(item.title, m.contentArray[row], col)
                else if contentType = "clip" then
                    playPluginVideo(server, item)
                else if item.viewGroup <> invalid AND item.viewGroup = "Store:Info" then
                    ChannelInfo(item)
                else 'if contentType = "series" then
                    ' TODO(schuyler): Can we show another grid here instead of a poster?
                    showNextPosterScreen(item.title, item)
                endif
            else if msg.isListItemFocused() then
                ' If the user is getting close to the limit of what we've
                ' preloaded, make sure we set the timeout and kick off another
                ' update.

                m.selectedRow = msg.GetIndex()
                if m.selectedRow + m.extraRowsToLoad > m.maxLoadedRow then timeout = 5
            else if msg.isScreenClosed() then
                return -1
            end if
        else if msg = invalid then
            ' An invalid event is our timeout, load some more data.
            row = m.maxLoadedRow + 1
            if row >= keys.Count() then
                timeout = 0
            else if m.LoadContent(server, queryResponse.sourceUrl, keys[row], row, m.contentArray[row].Count(), m.pageSize) then
                m.maxLoadedRow = row
                maxNeededRow = m.selectedRow + m.extraRowsToLoad
                if maxNeededRow >= keys.Count() then maxNeededRow = keys.Count() - 1
                if row >= maxNeededRow then timeout = 0
            end if
        end if
    end while

    return 0
End Function

Function loadGridContent(server, sourceUrl, key, rowIndex, startItem, count) As Boolean
    Print "Loading row "; rowIndex; ", "; key
    m.timer.Mark()
    response = server.GetPaginatedQueryResponse(sourceUrl, key, startItem, count)
    m.timer.PrintElapsedTime("Getting row XML")
    content = server.GetContent(response)
    m.timer.PrintElapsedTime("Parsing row XML")

    ' If the container doesn't play nice with pagination requests then
    ' whatever we got is the total size.
    if response.xml@totalSize <> invalid then
        totalSize = strtoi(response.xml@totalSize)
    else
        Print "Request to "; key; " didn't support pagination, returned size "; response.xml@size
        totalSize = content.Count()
        m.maxLoadedRow = rowIndex
    end if

    ' Don't bother showing empty rows
    if totalSize <= 0 then
        m.Grid.SetListVisible(rowIndex, false)
        return true
    end if

    ' Copy the items to our array
    itemCount = startItem
    for each item in content
        m.contentArray[rowIndex][itemCount] = item
        itemCount = itemCount + 1
    next

    ' It seems like you should be able to do this, but you have to pass in
    ' the full content list, not some other array you want to use to update
    ' the content list.
    ' m.Grid.SetContentListSubset(rowIndex, content, startItem, content.Count())

    m.Grid.SetContentListSubset(rowIndex, m.contentArray[rowIndex], startItem, content.Count())

    return m.contentArray[rowIndex].Count() >= totalSize
End Function

Function setGridStyle(style as String)
    m.gridStyle = style
    m.Grid.SetGridStyle(style)
End Function

