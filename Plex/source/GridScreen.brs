'*
'* A grid screen backed by XML from a PMS.
'*

Function createGridScreen(viewController) As Object
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
    screen.Item = invalid
    screen.Screen = grid
    screen.Port = port
    screen.ViewController = viewController
    screen.MessageHandler = invalid
    screen.MsgTimeout = 0

    screen.Show = showGridScreen
    screen.SetStyle = setGridStyle
    screen.SetUpBehaviorAtTopRow = setUpBehavior

    screen.timer = createPerformanceTimer()
    screen.selectedRow = 0
    screen.focusedIndex = 0
    screen.contentArray = []
    screen.lastUpdatedSize = []
    screen.gridStyle = "Flat-Movie"
    screen.upBehavior = "exit"

    screen.OnDataLoaded = gridOnDataLoaded

    return screen
End Function

'* Convenience method to create a grid screen with a loader for the specified item
Function createGridScreenForItem(item, viewController) As Object
    obj = createGridScreen(viewController)

    obj.Item = item

    container = createPlexContainerForUrl(item.server, item.sourceUrl, item.key)
    container.SeparateSearchItems = true
    obj.Loader = createPaginatedLoader(container, 8, 75)
    obj.Loader.Listener = obj
    obj.Loader.Port = obj.Port
    obj.MessageHandler = obj.Loader

    return obj
End Function

Function showGridScreen() As Integer
    facade = CreateObject("roGridScreen")
    facade.Show()

    totalTimer = createPerformanceTimer()

    names = m.Loader.GetNames()

    if names.Count() = 0 then
        print "Nothing to load for grid"
        dialog = createBaseDialog()
        dialog.Facade = facade
        dialog.Title = "Content Unavailable"
        dialog.Text = "An error occurred while trying to load this content, make sure the server is running."
        dialog.Show()

        m.Loader.Listener = invalid
        m.Loader = invalid
        m.MessageHandler = invalid
        m.ViewController.PopScreen(m)
        return -1
    end if

    m.Screen.SetupLists(names.Count()) 
    m.Screen.SetListNames(names)

    ' Only two rows and five items per row are visible on the screen, so
    ' don't load much more than we need to before initially showing the
    ' grid. Once we start the event loop we can load the rest of the
    ' content.

    maxRow = names.Count() - 1
    if maxRow > 1 then maxRow = 1

    for row = 0 to names.Count() - 1
        m.contentArray[row] = []
        m.lastUpdatedSize[row] = 0

        if row <= maxRow then
            Print "Loading beginning of row "; row; ", "; names[row]
            m.Loader.LoadMoreContent(row, 0)
        end if
    end for

    totalTimer.PrintElapsedTime("Total initial grid load")

    m.Screen.Show()
    facade.Close()

    ignoreClose = false

    while true
        msg = wait(m.MsgTimeout, m.port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roGridScreenEvent" then
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
                else if item.ContentType = "section" then
                    breadcrumbs = [item.server.name, item.Title]
                else
                    breadcrumbs = [names[msg.GetIndex()], item.Title]
                end if

                ' Close our current grid and recreate it once we get back.
                ' Works around a weird glitch when certain screens (maybe just
                ' an audio player) are shown on top of grids.
                ignoreClose = true
                facade = CreateObject("roGridScreen")
                facade.Show()
                m.Screen.Close()

                m.ViewController.CreateScreenForItem(context, index, breadcrumbs)

                m.Screen = CreateObject("roGridScreen")
                m.Screen.SetMessagePort(m.Port)
                m.Screen.SetDisplayMode("scale-to-fit")
                m.Screen.SetGridStyle(m.gridStyle)
                m.Screen.SetUpBehaviorAtTopRow(m.upBehavior)

                m.Screen.SetupLists(names.Count())
                m.Screen.SetListNames(names)

                m.ViewController.UpdateScreenProperties(m)

                for row = 0 to names.Count() - 1
                    m.Screen.SetContentList(row, m.contentArray[row])
                    if m.contentArray[row].Count() = 0 then
                        m.Screen.SetListVisible(row, false)
                    end if
                end for
                m.Screen.SetFocusedListItem(m.selectedRow, m.focusedIndex)

                m.Screen.Show()
                facade.Close()
            else if msg.isListItemFocused() then
                ' If the user is getting close to the limit of what we've
                ' preloaded, make sure we kick off another update.

                m.selectedRow = msg.GetIndex()
                m.focusedIndex = msg.GetData()

                if m.selectedRow < 0 OR m.selectedRow >= names.Count() then
                    print "Igoring grid ListItemFocused event for bogus row:"; msg.GetIndex()
                else
                    lastUpdatedSize = m.lastUpdatedSize[m.selectedRow]
                    if m.focusedIndex + 10 > lastUpdatedSize AND m.contentArray[m.selectedRow].Count() > lastUpdatedSize then
                        data = m.contentArray[m.selectedRow]
                        m.Screen.SetContentListSubset(m.selectedRow, data, lastUpdatedSize, data.Count() - lastUpdatedSize)
                        m.lastUpdatedSize[m.selectedRow] = data.Count()
                    end if

                    m.Loader.LoadMoreContent(m.selectedRow, 2)
                end if
            else if msg.isScreenClosed() then
                if ignoreClose then
                    ignoreClose = false
                else
                    ' Make sure we don't hang onto circular references
                    m.Loader.Listener = invalid
                    m.Loader = invalid
                    m.MessageHandler = invalid

                    m.ViewController.PopScreen(m)
                    return -1
                end if
            end if
        end if
    end while

    return 0
End Function

Sub gridOnDataLoaded(row As Integer, data As Object, startItem As Integer, count As Integer, finished As Boolean)
    print "Loaded"; count; " elements in row"; row; ", now have"; data.Count()

    m.contentArray[row] = data

    ' Don't bother showing empty rows
    if data.Count() = 0 then
        m.Screen.SetListVisible(row, false)
        return
    else if count > 0
        m.Screen.SetListVisible(row, true)
    end if

    ' It seems like you should be able to do this, but you have to pass in
    ' the full content list, not some other array you want to use to update
    ' the content list.
    ' m.Screen.SetContentListSubset(rowIndex, content, startItem, content.Count())

    lastUpdatedSize = m.lastUpdatedSize[row]

    if startItem < lastUpdatedSize then
        m.Screen.SetContentListSubset(row, data, startItem, count)
        m.lastUpdatedSize[row] = data.Count()
    else if finished OR startItem = 0 OR (m.selectedRow = row AND m.focusedIndex + 10 > lastUpdatedSize) then
        m.Screen.SetContentListSubset(row, data, lastUpdatedSize, data.Count() - lastUpdatedSize)
        m.lastUpdatedSize[row] = data.Count()
    end if

    ' Continue loading this row
    extraRows = 2 - (m.selectedRow - row)
    if extraRows >= 0 AND extraRows <= 2 then
        m.Loader.LoadMoreContent(row, extraRows)
    end if
End Sub

Sub setGridStyle(style as String)
    m.gridStyle = style
    m.Screen.SetGridStyle(style)
End Sub

Sub setUpBehavior(behavior as String)
    m.upBehavior = behavior
    m.Screen.SetUpBehaviorAtTopRow(behavior)
End Sub

