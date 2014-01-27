'*
'* A grid screen backed by XML from a PMS.
'*

Function createGridScreen(viewController, style=RegRead("rf_grid_style", "preferences", "flat-movie"), upBehavior="exit", SetDisplayMode = "scale-to-fit", hideHeaderText = false) As Object
    Debug("######## Creating Grid Screen " + tostr(style) + ":" + tostr(SetDisplayMode) + "  ########")

    if tostr(style) = "flat-portrait" and GetGlobal("IsHD") <> true then style = "flat-movie"
        
    if hideHeaderText <> invalid and hideHeaderText then 
        hideRowText(true)
    else 
        hideRowText(false)
    end if

    if upBehavior <> "stop" then ' allow us to force a stop
        upBehavior = RegRead("rf_up_behavior", "preferences", "exit")
    end if

    setGridTheme(style)

    screen = CreateObject("roAssociativeArray")

    initBaseScreen(screen, viewController)

    grid = CreateObject("roGridScreen")
    grid.SetMessagePort(screen.Port)

    di=createobject("rodeviceinfo")
    ' only use custom loading image on the black theme - conserve space
    if mid(di.getversion(),3,1).toint() > 3 and RegRead("rf_theme", "preferences", "black") = "black" then
        imageDir = GetGlobalAA().Lookup("rf_theme_dir")
        if style = "flat-16X9" or style = "flat-landscape" then
            SDPosterURL = imageDir + "sd-loading-landscape.jpg"
            HDPosterURL = imageDir + "hd-loading-landscape.jpg"
        else 
            SDPosterURL = imageDir + "sd-loading-poster.jpg"
            HDPosterURL = imageDir + "hd-loading-poster.jpg"
        end if
        SDPosterURL = imageDir + "black-loading-poster.png"
        HDPosterURL = imageDir + "black-loading-poster.png"
        grid.setloadingposter(SDPosterURL,HDPosterURL)
    end if

    ' If we don't know exactly what we're displaying, scale-to-fit looks the
    ' best. Anything else makes something look horrible when the grid has
    ' some combination of posters and video frames. 
    ' ljunkie: we will now allow this to be passed to change it
    grid.SetDisplayMode(SetDisplayMode)
    grid.SetGridStyle(style)
    grid.SetUpBehaviorAtTopRow(upBehavior)

    ' Standard properties for all our Screen types
    screen.Screen = grid
    screen.DestroyAndRecreate = gridDestroyAndRecreate
    screen.Show = showGridScreen
    screen.HandleMessage = gridHandleMessage
    screen.Activate = gridActivate
    screen.OnTimerExpired = gridOnTimerExpired

    screen.timer = createTimer()
    screen.selectedRow = 0
    screen.focusedIndex = 0
    screen.contentArray = []
    screen.lastUpdatedSize = []
    screen.gridStyle = style
    screen.upBehavior = upBehavior
    screen.hasData = false
    screen.hasBeenFocused = false
    screen.ignoreNextFocus = false
    screen.recreating = false

    screen.OnDataLoaded = gridOnDataLoaded

    return screen
End Function

'* Convenience method to create a grid screen with a loader for the specified item
Function createGridScreenForItem(item, viewController, style, SetDisplayMode = "scale-to-fit") As Object
    obj = createGridScreen(viewController, style, RegRead("rf_up_behavior", "preferences", "exit"), SetDisplayMode)

    obj.Item = item

    container = createPlexContainerForUrl(item.server, item.sourceUrl, item.key)
    container.SeparateSearchItems = true
    obj.Loader = createPaginatedLoader(container, 8, 75, item)
    obj.Loader.Listener = obj

    ' Don't play theme music on top of grid screens on the older Roku models.
    ' It's not worth the DestroyAndRecreate headache.
    if item.theme <> invalid AND GetGlobal("rokuVersionArr", [0])[0] >= 4 AND NOT AudioPlayer().IsPlaying AND RegRead("theme_music", "preferences", "loop") <> "disabled" then
        AudioPlayer().PlayThemeMusic(item)
        obj.Cleanup = baseStopAudioPlayer
    end if

    return obj
End Function

Function showGridScreen() As Integer
    'facade = CreateObject("roGridScreen")
    'facade.Show()
    ' ljunkie - not sure why an facade GridScreen is created. Maybe was neede in earlier firmware? Including it causes flashes between screens
    facade = invalid
    totalTimer = createTimer()

    names = m.Loader.GetNames()

    if names.Count() = 0 then
        Debug("Nothing to load for grid")
        dialog = createBaseDialog()
        facade = CreateObject("roGridScreen")
        facade.Show() ' ljunkie - aha, we need facade screen for zero row grids
        dialog.Facade = facade
        dialog.Title = "Content Unavailable"
        dialog.DisableBackButton = true
        dialog.Text = "An error occurred while trying to load this content, we received zero results."
        dialog.closePrevious = true ' or check to see if there is a facade?
        dialog.Show(true) ' blocking

        m.popOnActivate = true

        return -1
    end if

    m.Screen.SetupLists(names.Count())
    m.Screen.SetListNames(names)

    ' If we already "loaded" an empty row, we need to set the list visibility now
    ' that we've setup the lists.
    for row = 0 to names.Count() - 1
        if m.contentArray[row] = invalid then m.contentArray[row] = []
        m.lastUpdatedSize[row] = m.contentArray[row].Count()
        m.Screen.SetContentList(row, m.contentArray[row])
        if m.lastUpdatedSize[row] = 0 AND m.Loader.GetLoadStatus(row) = 2 then
            m.Screen.SetListVisible(row, false)
        end if
    end for

    ' ljunkie - remove description ( grid popout on bottom left ) - initial release (2013-11-09)
    ' This was asked for, however I know people are goint to complain. This will most likely need to be a bit more complicated.
    ' As in, people are not going to want this to be GLOBAL, but set per section/full grid/or even some secific type. 
    ' I.E. don't show on firstCharacter, but show of On Deck
    Debug("------------------- Description POP OUT disabled -- sec_metadata -- more info if we need to enable certain section/types --------------------------")
    vc = GetViewController()
    if tostr(m.ScreenName) = "Home" or (vc.Home <> invalid AND m.screenid = vc.Home.ScreenID) then
        isType = "home"
    else 
        sec_metadata = getSectionType()
        secTypes = ["photo","artist","movie","show"]
        isType = "other"
        Debug("curType: " + tostr(sec_metadata.type))
        for each st in secTypes
            if tostr(sec_metadata.type) = st then isType = st
        end for
    end if

    if RegRead("rf_grid_description_"+isType, "preferences", "enabled") <> "enabled" then
        m.screen.SetDescriptionVisible(false)
    end if
    Debug("isType: " + tostr(isType))
    Debug("------------------------------------------------------- END ---------------------------------------------------------------------------------------")

    m.Screen.Show()
    if facade <> invalid then facade.Close()

    ' Only two rows and five items per row are visible on the screen, so
    ' don't load much more than we need to before initially showing the
    ' grid. Once we start the event loop we can load the rest of the
    ' content.
    maxRow = names.Count() - 1

    ' ljunkie - Modify the default load count when one opens a grid screen (for FULL grid)
    ' for now, we will load 20 rows in the full grid ( only 5 items in a row.. so it seems to play nicely )
    if m.isFullGrid <> invalid and m.isFullGrid = true then 
        ' even though we load 20 rows, if one open an item from a row we will load the rest
        ' it will allow left/right buttons to work for all and gives the ability to play a slideshow from full grid
        maxRow = 20 ' in the FULL grid, loading 20 rows seems like an ok number. Might be able to raise this.
        if maxRow > names.Count() then maxRow=names.Count()
        Debug("---- Loading FULL grid - load row 0 to row " + tostr(maxRow))

        ' 10 second timer -- it will keep loading up to 20 rows every 10 seconds until complete
        timer = createTimer()
        timer.Name = "fullGridLoader"
        timer.SetDuration(1000*10, true)
        timer.active = true
        m.ViewController.AddTimer(timer, m)

    else if maxRow > 10 then 
        maxRow = 10
    end if

    for row = 0 to maxRow
        Debug("----- Loading beginning of row " + tostr(row) + ", " + tostr(names[row]))
        m.Loader.LoadMoreContent(row, 0)
    end for

    totalTimer.PrintElapsedTime("Total initial grid load")

    return 0
End Function

Function gridHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roGridScreenEvent" then
        handled = true
        if msg.isListItemSelected() then
            context = m.contentArray[msg.GetIndex()]
            index = msg.GetData()

            ' TODO(schuyler): How many levels of breadcrumbs do we want to
            ' include here. For example, if I'm in a TV section and select
            ' a series from Recently Viewed Shows, should the breadcrumbs
            ' on the next screen be "Section - Show Name" or "Recently
            ' Viewed Shows - Show Name"?

            item = context[index]
            if item <> invalid then

                ' user entered a section - remeber the last section to focus when launching the channel again
                vc = GetViewController()
                if vc.Home <> invalid AND m.screenid = vc.Home.ScreenID then
                    'item = m.contentArray[m.selectedRow][m.focusedIndex]
                    if type(item) = "roAssociativeArray" and item.contenttype <> invalid and item.contenttype = "section" then 
                        RegWrite("lastMachineID", item.server.machineID, "userinfo")
                        RegWrite("lastSectionKey", item.key, "userinfo")
                        'RegWrite("lastMachineID", item.server.machineID)
                        'RegWrite("lastSectionKey", item.key)
                        Debug("--------------- remember last focus ------------------------")
                        Debug("last section used " + item.key)
                        Debug("server " + item.server.machineID)
                        Debug("---------------------------------------")
                    end if 
                end if

                if item.ContentType = "series" then
                    breadcrumbs = [item.Title]
                else if item.ContentType = "section" then
                    breadcrumbs = [item.server.name, item.Title]
                else
                    breadcrumbs = [m.Loader.GetNames()[msg.GetIndex()], item.Title]
                end if

                'ljunkie - not sure why an facade GridScreen is created. Maybe was neede in earlier firmware? Including it causes flashes between screens
                'm.Facade = CreateObject("roGridScreen")
                'm.Facade.Show()

                m.ViewController.CreateScreenForItem(context, index, breadcrumbs)
            end if
        else if msg.isListItemFocused() then
            ' If the user is getting close to the limit of what we've
            ' preloaded, make sure we kick off another update.

            item = invalid

            m.selectedRow = msg.GetIndex()
            m.focusedIndex = msg.GetData()

            vc = GetViewController()
            if vc.Home <> invalid AND m.screenid <> vc.Home.ScreenID and m.contentArray <> invalid and type(m.contentArray[m.selectedRow]) = "roArray" then 
                item = m.contentArray[m.selectedRow][m.focusedIndex]
       
                if item <> invalid and tostr(item.type) = "photo" and tostr(item.nodename) <> "Directory" and item.ExifLoaded = invalid then 
                    description = getExifData(item,true)
                    if description <> invalid then
                        item.description = description
                        item.ExifLoaded = true
                        m.Screen.SetContentListSubset(m.selectedRow, m.contentArray[m.selectedRow], m.focusedIndex, 1)
                        'print item
                    end if
                end if
            end if
 
            ' deprecated -- we no only remember the last section when a user ENTERS the section instead of focusing the section
            'if vc.Home <> invalid AND m.screenid = vc.Home.ScreenID and m.contentArray <> invalid and type(m.contentArray[m.selectedRow]) = "roArray" then 
            '    item = m.contentArray[m.selectedRow][m.focusedIndex]
            '    if type(item) = "roAssociativeArray" and item.contenttype <> invalid and item.contenttype = "section" then 
            '        RegWrite("lastMachineID", item.server.machineID, "userinfo")
            '        RegWrite("lastSectionKey", item.key, "userinfo")
            '        'RegWrite("lastMachineID", item.server.machineID)
            '        'RegWrite("lastSectionKey", item.key)
            '        Debug("--------------- remember last focus ------------------------")
            '        Debug("last section used " + item.key)
            '        Debug("server " + item.server.machineID)
            '        Debug("---------------------------------------")
            '    end if 
            'end if

            ' ljunkie - save any focused item for the screen saver
            if item <> invalid and item.SDPosterURL <> invalid and item.HDPosterURL <> invalid then
                SaveImagesForScreenSaver(item, ImageSizes(item.ViewGroup, item.Type))
            end if

            if m.ignoreNextFocus then
                m.ignoreNextFocus = false
            else
                m.hasBeenFocused = true
            end if

            if m.selectedRow < 0 OR m.selectedRow >= m.contentArray.Count() then
                Debug("Ignoring grid ListItemFocused event for bogus row: " + tostr(msg.GetIndex()))
            else
                lastUpdatedSize = m.lastUpdatedSize[m.selectedRow]
                if m.focusedIndex + 10 > lastUpdatedSize AND m.contentArray[m.selectedRow].Count() > lastUpdatedSize then
                    data = m.contentArray[m.selectedRow]
                    m.Screen.SetContentListSubset(m.selectedRow, data, lastUpdatedSize, data.Count() - lastUpdatedSize)
                    m.lastUpdatedSize[m.selectedRow] = data.Count()
                end if

                extraRows = 2 ' standard is to load 2 rows 
                
                ' If this is a FULL Grid, then we want to change the default loading style ( we only have 5 items per row, so we can load many more)
                skipFullGrid = true
                if m.isfullgrid <> invalid and m.isfullgrid = true then
                    skipFullGrid = false
                    rfloaded = 0 ' container for total loaded rows
                    for each lrow in  m.loader.contentArray
                        if lrow.loadStatus = 2 then rfloaded = rfloaded+1
                    next

                    ' if the current row is not loaded.. maybe user held down the the button. We should force a load
                    forceLoad = (m.loader.contentArray[m.selectedRow].loadStatus <> 2) 

                    ' load the extra rows
                    if m.selectedRow > rfloaded-10 or forceLoad then 
                        skipFullGrid = true
                        Debug("----- Row selected " + tostr(m.selectedRow) + "is greater than current load count OR current row is not loaded. Load 20 up and down (from current row)")
                        m.Loader.LoadMoreContent(m.selectedRow, 0) ' load focused row right away
                        for index = 0 to 20 
                            row_up = m.selectedRow-index ' includes current row
                            row_down = index+m.selectedRow+1
                            if row_up > 0 then m.Loader.LoadMoreContent(row_up, 0)
                            if row_down > 0 then m.Loader.LoadMoreContent(row_down, 0)
                        next
                    end if
                end if

                ' ljunkie - only special for FULL grid view, since we only have 5 items in the row, it's safe to load more rows up/down
                ' always verify we have the rows for 2 up and 2 down from selected ROW..
                ' we want to load up and down. User might scroll down skipping loads, if they scroll up, they data will now be loaded. Better UX
                ' only run the Default loader if rfLoadDone is not set (we manually loaded rows above)
                if NOT skipFullGrid then
                    ' Debug("----- . Loading more content: from row " + tostr(m.selectedRow) + " PLUS  " + tostr(extraRows) + " more rows in both directions")
                    for index = 0 to extraRows-1
                        row_up = m.selectedRow-index ' includes current row
                        row_down = index+m.selectedRow+1
                        if row_up > 0 then m.Loader.LoadMoreContent(row_up, 0)
                        if row_down > 0 then m.Loader.LoadMoreContent(row_down, 0)
                    end for
                else 
                    ' ljunkie - this does't load the extra rows as I expected. It exists if a selected row ( or the first of the called extraRows are loaded )
                    ' this only really matters for the FULL grid, so we will still use the existing logic for non FULL grid
                    m.Loader.LoadMoreContent(m.selectedRow, extraRows) 
                    m.Loader.LoadMoreContent(m.selectedRow+1, extraRows) 
                    'm.Loader.LoadMoreContent(m.selectedRow+2, extraRows) 
                end if
            end if
        else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then ' ljunkie - use * for more options on focused item
                Debug("----- * button pressed")
                context = m.contentArray[m.selectedRow]
                item = context[m.focusedIndex]
                
                itype = item.contenttype
                if itype = invalid then itype = item.type

                isMovieTV = (itype = "movie"  or itype = "show" or itype = "episode" or itype = "season" or itype = "series")
                sn = m.screenname
                if tostr(itype) <> "invalid" and isMovieTV then 
                    ' need to full screen here
                    obj = m.viewcontroller.screens.peek()
                    obj.metadata = item
                    obj.Item = item
                    rfVideoMoreButtonFromGrid(obj)
                else if item <> invalid and tostr(item.contenttype) = "photo" then 
                    photoShowContextMenu(item,true)
                else if tostr(item.contenttype) <> "invalid" and m.screenid > 0 and tostr(m.screenname) <> "Home" then
                    ' show the option to see the FULL grid screen. We might want this just to do directly to it, but what if we add more options later.
                    ' might as well get people used to this.
                    rfDialogGridScreen(m)
                else if audioplayer().ContextScreenID = invalid then  ' only create this extra screen if audioPlayer doesn't have context
                    Debug("Info Button (*) not handled for content type: " +  tostr(item.type) + ":" + tostr(item.contenttype))
                    rfDefRemoteOptionButton(m)
                else
                    Debug("--- Not showing prefs on ctype:" + tostr(item.contenttype) + " itype:" + tostr(item.type) )
                end if 
        else if msg.isRemoteKeyPressed() then
            if msg.GetIndex() = 13 then
                ' Playing Photos from a grid - we need all items
                ' sometimes we don't know the item is photo ( appClips )            
                sec_metadata = getSectionType()
                ' TODO fix playing from section -- TODO
                if tostr(sec_metadata.type) = "photo" and m.item <> invalid and m.item.contenttype <> "section" then
                    Debug("Playing from GRID Screen - get context of ALL items in every row to play")
                    obj = CreateObject("roAssociativeArray")
                    obj.metadata = m.loader
                    obj.screen = m
                    GetContextFromFullGrid(obj,m.focusedIndex) 
                    Debug("photoHandleMessage:: Start slideshow with " + tostr(obj.context.count()) + " items")
                    Debug("starting at index: " + tostr(obj.curindex))
                else 
                    obj = CreateObject("roAssociativeArray")
                    obj.context = m.contentArray[m.selectedRow]
                    obj.curindex = m.focusedIndex
                end if
                Debug("Playing item directly from grid: index" + tostr(obj.curindex))
                Debug("total items: " + tostr(obj.context.count()))
                m.ViewController.CreatePlayerForItem(obj.context, obj.curindex)
            end if
        else if msg.isScreenClosed() then
            if m.recreating then
                Debug("Ignoring grid screen close, we should be recreating")
                m.recreating = false
            else
                m.ViewController.PopScreen(m)
            end if
        end if
    end if

    return handled
End Function

Sub gridOnDataLoaded(row As Integer, data As Object, startItem As Integer, count As Integer, finished As Boolean)
    Debug("Loaded " + tostr(count) + " elements in row " + tostr(row) + ", now have " + tostr(data.Count()))


    ' ljunkie - exclude photo/music from the NowPlaying row (shared users) for now
    '  -- further testing is needed to make this work ( it will be a wanted feature )
    newData = []
    if data.Count() > 0 then
        re = CreateObject("roRegex", "/status/sessions", "i")
        if tostr(data[0]) = "roAssociativeArray" and re.IsMatch(data[0].sourceurl) then 
            for index = 0 to data.Count() - 1
                if tostr(data[index].contenttype) = "audio" or tostr(data[index].contenttype) = "photo" then 
                    Debug("---- skipping audio item in now playing row ( not supported yet ) ")
                else 
                    newData.push(data[index])
                end if
            end for
            data = newData
        end if
    end if

    m.contentArray[row] = data

    ' Don't bother showing empty rows
    if data.Count() = 0 then
        if m.Screen <> invalid then
            m.Screen.SetListVisible(row, false)
            m.Screen.SetContentList(row, data)
        end if

        if NOT m.hasData then
            pendingRows = (m.Loader.GetPendingRequestCount() > 0)

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
                    m.closeOnActivate = true
                else
                    m.Screen.Close()
                end if

                return
            end if
        end if

        ' Load the next row though. This is particularly important if all of
        ' the initial rows are empty, we need to keep loading until we find a
        ' row with data.
        if row < m.contentArray.Count() - 1 then
            'Debug("----- ... Loading more content: from row " + tostr(row+1) + " with 0 more ")
            m.Loader.LoadMoreContent(row + 1, 0)
        end if

        return
    else if count > 0 AND m.Screen <> invalid then
        m.Screen.SetListVisible(row, true)
    end if

    m.hasData = true

    ' It seems like you should be able to do this, but you have to pass in
    ' the full content list, not some other array you want to use to update
    ' the content list.
    ' m.Screen.SetContentListSubset(rowIndex, content, startItem, content.Count())

    lastUpdatedSize = m.lastUpdatedSize[row]

    if finished then
        if m.Screen <> invalid then m.Screen.SetContentList(row, data)
        m.lastUpdatedSize[row] = data.Count()
        ' ljunkie - focus row when we are finished loading if we have specified a show before show()
        if  m.focusrow <> invalid and row = m.focusrow then 
            m.screen.SetFocusedListItem(m.focusrow,0) ' we will also focus the first item, this might need to be changed
            m.focusrow = invalid
        end if
    else if startItem < lastUpdatedSize then
        if m.Screen <> invalid then m.Screen.SetContentListSubset(row, data, startItem, count)
        m.lastUpdatedSize[row] = data.Count()
    else if startItem = 0 OR (m.selectedRow = row AND m.focusedIndex + 10 > lastUpdatedSize) then
        if m.Screen <> invalid then m.Screen.SetContentListSubset(row, data, lastUpdatedSize, data.Count() - lastUpdatedSize)
        m.lastUpdatedSize[row] = data.Count()
    end if

    ' ljunkie - the fact we lazy load rows, we cannot just set the focus item after we show a screen
    ' this will allow us to set the initial focus item on the first row of a full grid
    ' this might need to change if we every decide to focus on a sub row
    if row = 0 and m.firstfocusitem = invalid and m.isfullgrid <> invalid and m.isfullgrid then
        m.firstfocusitem = true
        m.screen.SetFocusedListItem(0,0)
    end if

    ' Continue loading this row
    extraRows = 2 - (m.selectedRow - row)
    'print "loadrow:" + tostr(row)
    'print " selrow:" + tostr(m.selectedRow)
    'print " result:" + tostr(extraRows)
    if extraRows >= 0 AND extraRows <= 2 then
        'Debug("------------ .. Loading more content: from row " + tostr(row) + ", " + tostr(m.loader.names[row]) + ", to (extrarows) " + tostr(extraRows))
        m.Loader.LoadMoreContent(row, extraRows)
    end if
End Sub

Sub setGridTheme(style as String)
    ' ljunkie - normally we have separate images per theme - but these, for now, are shared between the themes
    ' imageDir = GetGlobalAA().Lookup("rf_theme_dir")
    imageDir = "file://pkg:/images/"

    ' This has to be done before the CreateObject call. Once the grid has
    ' been created you can change its style, but you can't change its theme.

    ' SD version of flat-portrait is actually shorter than flat-movie ( opposite of HD ) we do not want shorter than the already short images
    if tostr(style) = "flat-portrait" and GetGlobal("IsHD") <> true then style = "flat-movie"

    SetGlobalGridStyle(style) ' set the new grid style - needed for determine image sizes

    app = CreateObject("roAppManager")
    app.ClearThemeAttribute("GridScreenDescriptionImageHD")
    if style = "flat-square" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", imageDir + "border-square-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", imageDir + "border-square-sd.png")
    else if style = "flat-16X9" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", imageDir + "border-episode-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", imageDir + "border-episode-sd.png")
    else if style = "flat-movie" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", imageDir + "border-movie-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", imageDir + "border-movie-sd.png")
    else if style = "flat-landscape" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", imageDir + "border-landscape-hd.png")
        app.SetThemeAttribute("GridScreenFocusBorderSD", imageDir + "border-landscape-sd.png")
    else if style = "flat-portrait" then
        app.SetThemeAttribute("GridScreenFocusBorderHD", imageDir + "border-portrait-hd.png")
        ' SD version of flat-portrait is actually shorter than flat-movie ( opposite of HD ) we do not want shorter than the already short images
        app.SetThemeAttribute("GridScreenFocusBorderSD", imageDir + "border-movie-sd.png")
        ' the BoB is too short for this screen.. nice going roku
        app.SetThemeAttribute("GridScreenDescriptionImageHD", "pkg:/images/grid/hd-description-background-portrait.png")
    end if
End Sub

Sub gridDestroyAndRecreate()
    ' Close our current grid and recreate it once we get back.
    ' Works around a weird glitch when certain screens (maybe just
    ' an audio player) are shown on top of grids.
    if m.Screen <> invalid then
        Debug("Destroying grid...")
        m.Screen.Close()
        m.Screen = invalid

        if m.ViewController.IsActiveScreen(m) then
            m.recreating = true

            timer = createTimer()
            timer.Name = "Reactivate"

            ' Pretty arbitrary, but too close to 0 won't work. This is obviously
            ' a hack, but we're working around an acknowledged bug that will
            ' never be fixed, so what can you do.
            timer.SetDuration(1500)

            m.ViewController.AddTimer(timer, m)
        end if
    end if
End Sub

Sub gridActivate(priorScreen)
    if m.popOnActivate then
        m.ViewController.PopScreen(m)
        return
    else if m.closeOnActivate then
        if m.Screen <> invalid then
            m.Screen.Close()
        else
            m.ViewController.PopScreen(m)
        end if
        return
    end if

    ' If our screen was destroyed by some child screen, recreate it now
    if m.Screen = invalid then
        Debug("Recreating grid...")
        setGridTheme(m.gridStyle)
        m.Screen = CreateObject("roGridScreen")
        m.Screen.SetMessagePort(m.Port)
        m.Screen.SetDisplayMode("scale-to-fit")
        m.Screen.SetGridStyle(m.gridStyle)
        m.Screen.SetUpBehaviorAtTopRow(m.upBehavior)

        names = m.Loader.GetNames()
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
    m.Loader.RefreshData() ' ljunkie - this has been modified to be a little more lazy! 
    if m.Facade <> invalid then  m.Facade.Close()
End Sub

Sub gridOnTimerExpired(timer)
    if timer.Name = "Reactivate" AND m.ViewController.IsActiveScreen(m) then
        m.Activate(invalid)
    end if

    ' keep loading fullGrid rows every timer pop until complete
    if timer.Name = "fullGridLoader" AND m.ViewController.IsActiveScreen(m) then
    
        rfloaded = 0 ' container for total loaded rows
        for each lrow in  m.loader.contentArray
            if lrow.loadStatus = 2 then rfloaded = rfloaded+1
        next

        Debug("  total rows: " + tostr(m.loader.contentArray.Count()))
        Debug("total loaded: " + tostr(rfloaded))
 
        if rfloaded > m.loader.contentArray.Count()-1 then
            Debug("All Rows Loaded -- Deactivate timer " + tostr(timer.name))
            timer.Active = false
        end if

        ' load the extra rows
        if rfloaded < m.loader.contentArray.Count() then 
            for index = 0 to 20 
                row_down = index+rfloaded
                if row_down < m.loader.contentArray.Count() then m.Loader.LoadMoreContent(row_down, 0)
            next
        end if
    end if

End Sub
