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

    screen.timer = createPerformanceTimer()
    screen.selectedRow = 0
    screen.contentArray = []
    screen.gridStyle = "Flat-Movie"

    screen.OnDataLoaded = gridOnDataLoaded

    return screen
End Function

'* Convenience method to create a grid screen with a loader for the specified item
Function createGridScreenForItem(item, viewController) As Object
    obj = createGridScreen(viewController)

    obj.Item = item

    container = createPlexContainerForUrl(item.server, item.sourceUrl, item.key)
    obj.Loader = createPaginatedLoader(container, 8, 50)
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

        if row <= maxRow then
            Print "Loading beginning of row "; row; ", "; names[row]
            m.Loader.LoadMoreContent(row, 0)
        end if
    end for

    totalTimer.PrintElapsedTime("Total initial grid load")

    m.Screen.Show()
    facade.Close()

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
                else
                    breadcrumbs = [names[msg.GetIndex()], item.Title]
                end if

                m.ViewController.CreateScreenForItem(context, index, breadcrumbs)
            else if msg.isListItemFocused() then
                ' If the user is getting close to the limit of what we've
                ' preloaded, make sure we kick off another update.

                m.selectedRow = msg.GetIndex()
                m.Loader.LoadMoreContent(m.selectedRow, 2)
            else if msg.isScreenClosed() then
                ' Make sure we don't hang onto circular references
                m.Loader.Listener = invalid
                m.Loader = invalid
                m.MessageHandler = invalid

                m.ViewController.PopScreen(m)
                return -1
            end if
        end if
    end while

    return 0
End Function

Sub gridOnDataLoaded(row As Integer, data As Object, startItem As Integer, count As Integer)
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

    m.Screen.SetContentListSubset(row, data, startItem, count)

    ' Continue loading this row
    extraRows = 2 - (m.selectedRow - row)
    if extraRows >= 0 AND extraRows <= 2 then
        m.Loader.LoadMoreContent(row, extraRows)
    end if
End Sub

Function setGridStyle(style as String)
    m.gridStyle = style
    m.Screen.SetGridStyle(style)
End Function

