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
    controller.PopScreen = vcPopScreen

    controller.ShowHomeScreen = vcShowHomeScreen
    controller.RefreshHomeScreen = vcRefreshHomeScreen

    controller.facade = CreateObject("roPosterScreen")
    controller.facade.Show()

    controller.nextId = 1

    return controller
End Function

Function vcCreateScreenForItem(context, contextIndex, breadcrumbs, show=true) As Object
    if type(context) = "roArray" then
        item = context[contextIndex]
    else
        item = context
    end if

    'print "Item = ";item

    contentType = item.ContentType
    viewGroup = item.viewGroup
    if viewGroup = invalid then viewGroup = ""

    screen = CreateObject("roAssociativeArray")

    ' NOTE: We don't support switching between them as a preference, but
    ' the poster screen can be used anywhere the grid is used below. By
    ' default the poster screen will try to decide whether or not to
    ' include the filter bar that makes it more grid like, but it can
    ' be forced by setting screen.FilterMode = true.

    ' TODO(schuyler): Fill all this in
    if contentType = "movie" OR contentType = "episode" then
        screen = createVideoSpringboardScreen(context, contextIndex, m)
    else if contentType = "clip" then
        ' playPluginVideo(item.server, item)
    else if contentType = "series" then
        screen = createGridScreenForItem(item, m)
    else if contentType = "artist" then
        ' TODO: Poster, poster with filters, or grid?
        screen = createPosterScreen(item, m)
    else if contentType = "album" then
        screen = createPosterScreen(item, m)
        ' TODO: What style looks best here, episodic?
        screen.SetListStyle("flat-episodic", "zoom-to-fill")
    else if contentType = "audio" then
        screen = createAudioSpringboardScreen(context, contextIndex, m)
    else if contentType = "section" then
        ' Need to actually set the content type to section somewhere, based on title2?
        screen = createGridScreenForItem(item, m)
    else if contentType = "photo" then
        if right(item.key, 8) = "children" then
            screen = createPosterScreen(item, m)
        else 
            screen = createPhotoSpringboardScreen(context, contextIndex, m)
        end if
    else if viewGroup = "Store:Info" then
        ' ChannelInfo(item)
    else if viewGroup = "secondary" then
        screen = createPosterScreen(item, m)
    else
        ' Where do we capture channel directory?
        Print "Creating a default view for contentType=";contentType;", viewGroup=";viewGroup
        screen = createPosterScreen(item, m)
    end if

    ' Add the breadcrumbs to our list and set them for the current screen.
    ' If the current screen specified invalid for the breadcrubms then it
    ' doesn't want any breadcrumbs to be shown. If it specified an empty
    ' array, then the current breadcrumbs will be shown again.
    if breadcrumbs = invalid then
        screen.Screen.SetBreadcrumbEnabled(false)
        screen.NumBreadcrumbs = 0
    else
        ' Special case for springboard screens, don't show the current title
        ' in the breadcrumbs.
        if type(screen.Screen) = "roSpringboardScreen" AND breadcrumbs.Count() > 0 then breadcrumbs.Pop()

        for each b in breadcrumbs
            m.breadcrumbs.Push(tostr(b))
        next
        screen.NumBreadcrumbs = breadcrumbs.Count()

        count = m.breadcrumbs.Count()
        if count >= 2 then
            screen.Screen.SetBreadcrumbEnabled(true)
            screen.Screen.SetBreadcrumbText(m.breadcrumbs[count-2], m.breadcrumbs[count-1])
        else if count = 1 then
            screen.Screen.SetBreadcrumbEnabled(true)
            screen.Screen.SetBreadcrumbText("", m.breadcrumbs[0])
        else
            screen.Screen.SetBreadcrumbEnabled(false)
        end if
    end if

    ' Set an ID on the screen so we can sanity check before popping
    screen.ScreenID = m.nextId
    m.nextId = m.nextId + 1

    Print "Pushing screen"; screen.ScreenID; " onto view controller stack"
    m.screens.Push(screen)

    if show then screen.Show()

    return screen
End Function

Sub vcPopScreen(screen)
    if screen.ScreenID = invalid OR m.screens.Peek().ScreenID = invalid OR screen.ScreenID <> m.screens.Peek().ScreenID then
        Print "Trying to pop screen that doesn't match the top of our stack!"
        Return
    end if

    Print "Popping screen"; screen.ScreenID; " and cleaning up"; screen.NumBreadcrumbs; " breadcrumbs"
    m.screens.Pop()
    for i = 0 to screen.NumBreadcrumbs - 1
        m.breadcrumbs.Pop()
    next
End Sub

Sub vcShowHomeScreen()
    m.Home = createHomeScreen(m)
    m.Home.Show()
End Sub

Sub vcRefreshHomeScreen()
    while m.screens.Count() > 0
        m.PopScreen(m.screens.Peek())
    end while

    m.Home.Refresh()
End Sub

