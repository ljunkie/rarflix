'*
'* A controller for managing the stack of screens that have been displayed.
'* By centralizing this we can better support things like destroying and
'* recreating views and breadcrumbs. It also provides a single place that
'* can take an item and figure out which type of screen should be shown
'* so that logic doesn't have to be in each individual screen type.
'*

Function createViewController() As Object
    controller = CreateObject("roAssociativeArray")

    controller.breadcrumbs = CreateObject("roArray", 10, true)
    controller.screens = CreateObject("roArray", 10, true)

    controller.CreateScreenForItem = vcCreateScreenForItem
    controller.CreateTextInputScreen = vcCreateTextInputScreen
    controller.CreateEnumInputScreen = vcCreateEnumInputScreen
    controller.InitializeOtherScreen = vcInitializeOtherScreen
    controller.PushScreen = vcPushScreen
    controller.PopScreen = vcPopScreen

    controller.ShowHomeScreen = vcShowHomeScreen
    controller.RefreshHomeScreen = vcRefreshHomeScreen
    controller.UpdateScreenProperties = vcUpdateScreenProperties
    controller.AddBreadcrumbs = vcAddBreadcrumbs

    controller.DestroyGlitchyScreens = vcDestroyGlitchyScreens

    controller.facade = CreateObject("roGridScreen")
    controller.facade.Show()

    controller.nextId = 1

    controller.InitThemes = vcInitThemes
    controller.PushTheme = vcPushTheme
    controller.PopTheme = vcPopTheme
    controller.ApplyThemeAttrs = vcApplyThemeAttrs

    controller.InitThemes()

    return controller
End Function

Function vcCreateScreenForItem(context, contextIndex, breadcrumbs, show=true) As Dynamic
    if type(context) = "roArray" then
        item = context[contextIndex]
    else
        item = context
    end if

    contentType = item.ContentType
    viewGroup = item.viewGroup
    if viewGroup = invalid then viewGroup = ""

    screen = CreateObject("roAssociativeArray")

    ' NOTE: We don't support switching between them as a preference, but
    ' the poster screen can be used anywhere the grid is used below. By
    ' default the poster screen will try to decide whether or not to
    ' include the filter bar that makes it more grid like, but it can
    ' be forced by setting screen.FilterMode = true.

    if contentType = "movie" OR contentType = "episode" then
        screen = createVideoSpringboardScreen(context, contextIndex, m)
    else if contentType = "clip" then
        screen = createVideoSpringboardScreen(context, contextIndex, m)
    else if contentType = "series" then
        screen = createGridScreenForItem(item, m, "flat-16X9")
    else if contentType = "artist" then
        ' TODO: Poster, poster with filters, or grid?
        screen = createPosterScreen(item, m)
    else if contentType = "album" then
        screen = createPosterScreen(item, m)
        ' TODO: What style looks best here, episodic?
        screen.SetListStyle("flat-episodic", "zoom-to-fill")
    else if contentType = "audio" then
        screen = createAudioSpringboardScreen(context, contextIndex, m)
        if screen = invalid then return invalid
    else if contentType = "section" then
        RegWrite("lastMachineID", item.server.machineID)
        RegWrite("lastSectionKey", item.key)
        screen = createGridScreenForItem(item, m, "flat-movie")
    else if contentType = "photo" then
        if right(item.key, 8) = "children" then
            screen = createPosterScreen(item, m)
        else 
            screen = createPhotoSpringboardScreen(context, contextIndex, m)
        end if
    else if contentType = "search" then
        screen = createSearchScreen(item, m)
    else if item.key = "/system/appstore" then
        screen = createGridScreenForItem(item, m, "flat-square")
    else if viewGroup = "Store:Info" then
        dialog = createPopupMenu(item)
        dialog.Show()
        return invalid
    else if viewGroup = "secondary" then
        screen = createPosterScreen(item, m)
    else if item.key = "globalprefs" then
        screen = createPreferencesScreen(m)
    else if item.key = "/channels/all" then
        ' Special case for all channels to force it into a special grid view
        screen = createGridScreen(m, "flat-square")
        names = ["Video Channels", "Music Channels", "Photo Channels"]
        keys = ["/video", "/music", "/photos"]
        fakeContainer = createFakePlexContainer(item.server, names, keys)
        screen.Loader = createPaginatedLoader(fakeContainer, 8, 25)
        screen.Loader.Listener = screen
        screen.Loader.Port = screen.Port
        screen.MessageHandler = screen.Loader
    else if item.searchTerm <> invalid AND item.server = invalid then
        screen = createGridScreen(m, "flat-square")
        screen.Loader = createSearchLoader(item.searchTerm)
        screen.Loader.Listener = screen
        screen.MessageHandler = screen.Loader
    else if item.settings = "1"
        screen = createSettingsScreen(item, m)
    else
        ' Where do we capture channel directory?
        Debug("Creating a default view for contentType=" + tostr(contentType) + ", viewGroup=" + tostr(viewGroup))
        screen = createPosterScreen(item, m)
    end if

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateTextInputScreen(heading, breadcrumbs, show=true) As Dynamic
    screen = createKeyboardScreen(m)

    if heading <> invalid then
        screen.Screen.SetDisplayText(heading)
    end if

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Function vcCreateEnumInputScreen(options, selected, heading, breadcrumbs, show=true) As Dynamic
    screen = createEnumScreen(options, selected, m)

    if heading <> invalid then
        screen.Screen.SetHeader(heading)
    end if

    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)

    if show then screen.Show()

    return screen
End Function

Sub vcInitializeOtherScreen(screen, breadcrumbs)
    m.AddBreadcrumbs(screen, breadcrumbs)
    m.UpdateScreenProperties(screen)
    m.PushScreen(screen)
End Sub

Sub vcPushScreen(screen)
    ' Set an ID on the screen so we can sanity check before popping
    screen.ScreenID = m.nextId
    m.nextId = m.nextId + 1

    Debug("Pushing screen " + tostr(screen.ScreenID) + " onto view controller stack")
    m.screens.Push(screen)
End Sub

Sub vcPopScreen(screen)
    if screen.ScreenID = -1 then
        Debug("Popping home screen, cleaning up")

        while m.screens.Count() > 1
            m.PopScreen(m.screens.Peek())
        end while
        m.screens.Pop()

        m.Home = invalid
        return
    end if

    screen.MessageHandler = invalid

    if screen.ScreenID = invalid OR m.screens.Peek().ScreenID = invalid OR screen.ScreenID <> m.screens.Peek().ScreenID then
        Debug("Trying to pop screen that doesn't match the top of our stack!")
        Return
    end if

    Debug("Popping screen " + tostr(screen.ScreenID) + " and cleaning up " + tostr(screen.NumBreadcrumbs) + " breadcrumbs")
    m.screens.Pop()
    for i = 0 to screen.NumBreadcrumbs - 1
        m.breadcrumbs.Pop()
    next

    if m.screens.Count() = 0 then
        m.Home.CreateQueueRequests(true)
    end if
End Sub

Sub vcShowHomeScreen()
    m.Home = createHomeScreen(m)
    m.Home.Screen.ScreenID = -1
    m.screens.Push(m.Home.Screen)
    m.Home.Show()
End Sub

Sub vcRefreshHomeScreen()
    while m.screens.Count() > 1
        m.PopScreen(m.screens.Peek())
    end while

    m.Home.Refresh()
End Sub

Sub vcAddBreadcrumbs(screen, breadcrumbs)
    ' Add the breadcrumbs to our list and set them for the current screen.
    ' If the current screen specified invalid for the breadcrubms then it
    ' doesn't want any breadcrumbs to be shown. If it specified an empty
    ' array, then the current breadcrumbs will be shown again.
    screenType = type(screen.Screen)
    if breadcrumbs = invalid then
        screen.NumBreadcrumbs = 0
        return
    end if

    ' Special case for springboard screens, don't show the current title
    ' in the breadcrumbs.
    if screenType = "roSpringboardScreen" AND breadcrumbs.Count() > 0 then
        breadcrumbs.Pop()
    end if

    if breadcrumbs.Count() = 0 AND m.breadcrumbs.Count() > 0 then
        count = m.breadcrumbs.Count()
        if count >= 2 then
            breadcrumbs = [m.breadcrumbs[count-2], m.breadcrumbs[count-1]]
        else
            breadcrumbs = m.breadcrumbs[0]
        end if

        m.breadcrumbs.Append(breadcrumbs)
        screen.NumBreadcrumbs = breadcrumbs.Count()
    else
        for each b in breadcrumbs
            m.breadcrumbs.Push(tostr(b))
        next
        screen.NumBreadcrumbs = breadcrumbs.Count()
    end if
End Sub

Sub vcUpdateScreenProperties(screen)
    ' Make sure that metadata requests from the screen carry an auth token.
    if GetInterface(screen.Screen, "ifHttpAgent") <> invalid AND screen.Item <> invalid AND screen.Item.server <> invalid AND screen.Item.server.AccessToken <> invalid then
        screen.Screen.AddHeader("X-Plex-Token", screen.Item.server.AccessToken)
    end if

    if screen.NumBreadcrumbs <> 0 then
        count = m.breadcrumbs.Count()
        if count >= 2 then
            enableBreadcrumbs = true
            bread1 = m.breadcrumbs[count-2]
            bread2 = m.breadcrumbs[count-1]
        else if count = 1 then
            enableBreadcrumbs = true
            bread1 = ""
            bread2 = m.breadcrumbs[0]
        else
            enableBreadcrumbs = false
        end if
    else
        enableBreadcrumbs = false
    end if

    screenType = type(screen.Screen)
    ' Sigh, different screen types don't support breadcrumbs with the same functions
    if screenType = "roGridScreen" OR screenType = "roPosterScreen" OR screenType = "roSpringboardScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetBreadcrumbEnabled(true)
            screen.Screen.SetBreadcrumbText(bread1, bread2)
        else
            screen.Screen.SetBreadcrumbEnabled(false)
        end if
    else if screenType = "roSearchScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetBreadcrumbText(bread1, bread2)
        end if
    else if screenType = "roListScreen" OR screenType = "roKeyboardScreen" OR screenType = "roParagraphScreen" then
        if enableBreadcrumbs then
            screen.Screen.SetTitle(bread2)
        end if
    else
        Debug("Not sure what to do with breadcrumbs on screen type: " + tostr(screenType))
    end if
End Sub

Sub vcInitThemes()
    m.ThemeStack = CreateObject("roList")
    m.ThemeApplyParams = CreateObject("roAssociativeArray")
    m.ThemeRevertParams = CreateObject("roAssociativeArray")
End Sub

Sub vcPushTheme(name)
    if NOT m.ThemeApplyParams.DoesExist(name) then return

    if name <> m.ThemeStack.GetTail() then
        m.ApplyThemeAttrs(m.ThemeApplyParams[name])
    end if

    m.ThemeStack.AddTail(name)
End Sub

Sub vcPopTheme()
    name = m.ThemeStack.RemoveTail()

    if name <> m.ThemeStack.GetTail() then
        m.ApplyThemeAttrs(m.ThemeRevertParams[name])
        m.ApplyThemeAttrs(m.ThemeApplyParams[m.ThemeStack.GetTail()])
    end if
End Sub

Sub vcApplyThemeAttrs(attrs)
    app = CreateObject("roAppManager")
    for each attr in attrs
        if attrs[attr] <> invalid then
            app.SetThemeAttribute(attr, attrs[attr])
        else
            app.ClearThemeAttribute(attr)
        end if
    next
End Sub

Sub vcDestroyGlitchyScreens()
    for each screen in m.screens
        if screen.DestroyAndRecreate <> invalid then
            Debug("Destroying screen " + tostr(screen.ScreenID) + " to work around glitch")
            screen.DestroyAndRecreate()
        end if
    next
End Sub

