'*
'* A grid screen backed by XML from a PMS.
'*

Function createGridScreen(viewController, style="flat-movie") As Object
    Debug("######## Creating Grid Screen ########")

    setGridTheme(style)

    screen = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")

    grid.SetMessagePort(port)

    ' If we don't know exactly what we're displaying, scale-to-fit looks the
    ' best. Anything else makes something look horrible when the grid has
    ' some combination of posters and video frames.
    grid.SetDisplayMode("scale-to-fit")
    grid.SetGridStyle(style)
    grid.SetUpBehaviorAtTopRow("exit")

    ' Standard properties for all our Screen types
    screen.Item = invalid
    screen.Screen = grid
    screen.Port = port
    screen.ViewController = viewController
    screen.MessageHandler = invalid
    screen.MsgTimeout = 0
    screen.DestroyAndRecreate = gridDestroyAndRecreate

    screen.Show = showGridScreen
    screen.SetUpBehaviorAtTopRow = setUpBehavior

    screen.timer = createPerformanceTimer()
    screen.selectedRow = 0
    screen.focusedIndex = 0
    screen.contentArray = []
    screen.lastUpdatedSize = []
    screen.gridStyle = style
    screen.upBehavior = "exit"
    screen.hasData = false
    screen.hasBeenFocused = false
    screen.ignoreNextFocus = false

    screen.OnDataLoaded = gridOnDataLoaded

    return screen
End Function

'* Convenience method to create a grid screen with a loader for the specified item
Function createGridScreenForItem(item, viewController, style) As Object
    obj = createGridScreen(viewController, style)

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
        Debug("Nothing to load for grid")
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

    m.Screen.Show()
    facade.Close()

    ' Only two rows and five items per row are visible on the screen, so
    ' don't load much more than we need to before initially showing the
    ' grid. Once we start the event loop we can load the rest of the
    ' content.

    maxRow = names.Count() - 1
    if maxRow > 1 then maxRow = 1

    for row = 0 to names.Count() - 1
        m.contentArray[row] = []
        m.lastUpdatedSize[row] = 0
    end for

    for row = 0 to maxRow
        Debug("Loading beginning of row " + tostr(row) + ", " + tostr(names[row]))
        m.Loader.LoadMoreContent(row, 0)
    end for

    totalTimer.PrintElapsedTime("Total initial grid load")

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

                facade = CreateObject("roGridScreen")
                facade.Show()

                m.ViewController.CreateScreenForItem(context, index, breadcrumbs)

                ' If our screen was destroyed by some child screen, recreate it now
                if m.Screen = invalid then
                    Debug("Recreating grid...")
                    setGridTheme(m.gridStyle)
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
                        if m.contentArray[row].Count() = 0 AND m.Loader.GetLoadStatus(row) = 2 then
                            m.Screen.SetListVisible(row, false)
                        end if
                    end for
                    m.Screen.SetFocusedListItem(m.selectedRow, m.focusedIndex)

                    m.Screen.Show()
                else
                    ' Regardless, reset the current row in case the currently
                    ' selected item had metadata changed that would affect its
                    ' display in the grid.
                    m.Screen.SetContentList(m.selectedRow, m.contentArray[m.selectedRow])
                end if

                m.HasData = false
                m.Refreshing = true
                m.Loader.RefreshData()

                facade.Close()
            else if msg.isListItemFocused() then
                ' If the user is getting close to the limit of what we've
                ' preloaded, make sure we kick off another update.

                m.selectedRow = msg.GetIndex()
                m.focusedIndex = msg.GetData()

                if m.ignoreNextFocus then
                    m.ignoreNextFocus = false
                else
                    m.hasBeenFocused = true
                end if

                if m.selectedRow < 0 OR m.selectedRow >= names.Count() then
                    Debug("Ignoring grid ListItemFocused event for bogus row: " + tostr(msg.GetIndex()))
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

Sub gridOnDataLoaded(row As Integer, data As Object, startItem As Integer, count As Integer, finished As Boolean)
    Debug("Loaded " + tostr(count) + " elements in row " + tostr(row) + ", now have " + tostr(data.Count()))

    m.contentArray[row] = data

    ' Don't bother showing empty rows
    if data.Count() = 0 then
        m.Screen.SetListVisible(row, false)
        m.Screen.SetContentList(row, data)

        if NOT m.hasData then
            if m.Loader.PendingRequests <> invalid then
                m.Loader.PendingRequests.Reset()
                pendingRows = m.Loader.PendingRequests.IsNext()
            else
                pendingRows = false
            end if

            if NOT pendingRows then
                for i = 0 to m.contentArray.Count() - 1
                    if m.Loader.GetLoadStatus(i) < 2 then
                        pendingRows = true
                        exit for
                    end if
                next
            end if

            if NOT pendingRows then
                Debug("Nothing in any grid rows")

                ' If there's no data, show a helpful dialog. But if there's no
                ' data on a refresh, it's a bit of a mess. The dialog is only
                ' marginally helpful, and there's some sort of race condition
                ' with the fact that we reset the content list for the current
                ' row when the screen came back. That can hang the app for
                ' non-obvious reasons. Even without showing the dialog, closing
                ' the screen has a bit of an ugly flash.

                if m.Refreshing <> true then
                    dialog = createBaseDialog()
                    dialog.Title = "Section Empty"
                    dialog.Text = "This section doesn't contain any items."
                    dialog.Show()
                end if
                m.Screen.Close()
            end if
        end if

        ' Load the next row though. This is particularly important if all of
        ' the initial rows are empty, we need to keep loading until we find a
        ' row with data.
        if row < m.contentArray.Count() - 1 then
            m.Loader.LoadMoreContent(row + 1, 0)
        end if

        return
    else if count > 0
        m.Screen.SetListVisible(row, true)
    end if

    m.hasData = true

    ' It seems like you should be able to do this, but you have to pass in
    ' the full content list, not some other array you want to use to update
    ' the content list.
    ' m.Screen.SetContentListSubset(rowIndex, content, startItem, content.Count())

    lastUpdatedSize = m.lastUpdatedSize[row]

    if finished then
        m.Screen.SetContentList(row, data)
        m.lastUpdatedSize[row] = data.Count()
    else if startItem < lastUpdatedSize then
        m.Screen.SetContentListSubset(row, data, startItem, count)
        m.lastUpdatedSize[row] = data.Count()
    else if startItem = 0 OR (m.selectedRow = row AND m.focusedIndex + 10 > lastUpdatedSize) then
        m.Screen.SetContentListSubset(row, data, lastUpdatedSize, data.Count() - lastUpdatedSize)
        m.lastUpdatedSize[row] = data.Count()
    end if

    ' Continue loading this row
    extraRows = 2 - (m.selectedRow - row)
    if extraRows >= 0 AND extraRows <= 2 then
        m.Loader.LoadMoreContent(row, extraRows)
    end if
End Sub

Sub setGridTheme(style as String)
    ' This has to be done before the CreateObject call. Once the grid has
    ' been created you can change its style, but you can't change its theme.

    app = CreateObject("roAppManager")
    if style = "flat-square" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", "pkg:/images/border-square-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", "pkg:/images/border-square-sd.png")
    else if style = "flat-16X9" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", "pkg:/images/border-episode-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", "pkg:/images/border-episode-sd.png")
    else if style = "flat-movie" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", "pkg:/images/border-movie-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", "pkg:/images/border-movie-sd.png")
    end if
End Sub

Sub setUpBehavior(behavior as String)
    m.upBehavior = behavior
    m.Screen.SetUpBehaviorAtTopRow(behavior)
End Sub

Sub gridDestroyAndRecreate()
    ' Close our current grid and recreate it once we get back.
    ' Works around a weird glitch when certain screens (maybe just
    ' an audio player) are shown on top of grids.
    if m.Screen <> invalid then
        Debug("Destroying grid...")
        m.Screen.Close()
        m.Screen = invalid
    end if
End Sub

