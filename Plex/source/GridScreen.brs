'*
'* A grid screen backed by XML from a PMS.
'*

Function createGridScreen(item, viewController) As Object
    Print "######## Creating Grid Screen ########"

    screen = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")

    grid.SetMessagePort(port)

    ' If we don't know exactly what we're displaying, scale-to-fit looks the
    ' best. Anything else makes something look horrible when the grid has
    ' some combination of posters and video frames.
    grid.SetDisplayMode("scale-to-fit")
    grid.SetGridStyle("Flat-Movie")
    grid.SetUpBehaviorAtTopRow("exit")

    ' Standard properties for all our Screen types
    screen.Item = item
    screen.Screen = grid
    screen.ViewController = viewController

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

Function showGridScreen() As Integer
    facade = CreateObject("roGridScreen")
    facade.Show()

    print "Showing grid for item: "; m.Item.key

    totalTimer = createPerformanceTimer()

    server = m.Item.server

    content = createPlexContainerForUrl(server, m.Item.sourceUrl, m.Item.key)
    names = content.GetNames()
    keys = content.GetKeys()

    m.timer.PrintElapsedTime("createPlexContainerForUrl")

    m.Screen.SetupLists(names.Count()) 
    m.timer.PrintElapsedTime("Grid SetupLists")
    m.Screen.SetListNames(names)
    m.timer.PrintElapsedTime("Grid SetListNames")

    ' Only two rows and five items per row are visible on the screen, so
    ' don't load much more than we need to before initially showing the
    ' grid. Once we start the event loop we can load the rest of the
    ' content.

    maxRow = keys.Count() - 1
    if maxRow > 1 then maxRow = 1

    for row = 0 to keys.Count() - 1
        m.contentArray[row] = []

        if row <= maxRow then
            Print "Loading beginning of row "; row; ", "; keys[row]
            m.LoadContent(server, content.sourceUrl, keys[row], row, 0, m.initialLoadSize)
        end if
    end for

    totalTimer.PrintElapsedTime("Total initial grid load")

    m.Screen.Show()
    facade.Close()

    ' We'll use a small timeout to continue loading data as needed. Once we've
    ' finished loading data, reset the timeout to 0 so that we don't continue
    ' to get notified.
    timeout = 5

    while true
        msg = wait(timeout, m.port)
        if type(msg) = "roGridScreenEvent" then
            if msg.isListItemSelected() then
                context = m.contentArray[msg.GetIndex()]
                index = msg.GetData()

                ' TODO(schuyler): How many levels of breadcrumbs do we want to
                ' include here. For example, if I'm in a TV section and select
                ' a series from Recently Viewed Shows, should the breadcrumbs
                ' on the next screen be "Section - Show Name" or "Recently
                ' Viewed Shows - Show Name"?

                item = context[index]
                if item.ContentType = "series" then
                    breadcrumbs = [item.Title]
                else
                    breadcrumbs = [names[msg.GetIndex()], item.Title]
                end if

                m.ViewController.CreateScreenForItem(context, index, breadcrumbs)
            else if msg.isListItemFocused() then
                ' If the user is getting close to the limit of what we've
                ' preloaded, make sure we set the timeout and kick off another
                ' update.

                m.selectedRow = msg.GetIndex()
                if m.selectedRow + m.extraRowsToLoad > m.maxLoadedRow then timeout = 5
            else if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                return -1
            end if
        else if msg = invalid then
            ' An invalid event is our timeout, load some more data.
            row = m.maxLoadedRow + 1
            if row >= keys.Count() then
                timeout = 0
            else if m.LoadContent(server, content.sourceUrl, keys[row], row, m.contentArray[row].Count(), m.pageSize) then
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
    content = createPlexContainerForXml(response)
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
        m.Screen.SetListVisible(rowIndex, false)
        return true
    end if

    ' Copy the items to our array
    m.contentArray[rowIndex].Append(content.GetMetadata())

    ' It seems like you should be able to do this, but you have to pass in
    ' the full content list, not some other array you want to use to update
    ' the content list.
    ' m.Screen.SetContentListSubset(rowIndex, content, startItem, content.Count())

    m.Screen.SetContentListSubset(rowIndex, m.contentArray[rowIndex], startItem, content.Count())

    return m.contentArray[rowIndex].Count() >= totalSize
End Function

Function setGridStyle(style as String)
    m.gridStyle = style
    m.Screen.SetGridStyle(style)
End Function

