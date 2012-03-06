'* Displays the content in a poster screen. Can be any content type.

Function createPosterScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)

    ' Standard properties for all our screen types
    obj.Item = item
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showPosterScreen
    obj.ShowList = posterShowContentList
    obj.SetListStyle = posterSetListStyle

    obj.UseDefaultStyles = true
    obj.ListStyle = invalid
    obj.ListDisplayMode = invalid
    obj.FilterMode = invalid

    obj.OnDataLoaded = posterOnDataLoaded

    obj.contentArray = []
    obj.focusedList = 0

    return obj
End Function

Function showPosterScreen() As Integer
    ' Show a facade immediately to get the background 'retrieving' instead of
    ' using a one line dialog.
    facade = CreateObject("roPosterScreen")
    facade.Show()

    content = m.Item
    server = content.server

    container = createPlexContainerForUrl(server, content.sourceUrl, content.key)

    if m.FilterMode = invalid then m.FilterMode = container.ViewGroup = "secondary"
    if m.FilterMode then
        names = container.GetNames()
        keys = container.GetKeys()
    else
        names = []
        keys = []
    end if

    m.FilterMode = names.Count() > 0

    if m.FilterMode then
        m.Screen.SetListNames(names)
        m.Screen.SetFocusedList(0)
        m.Loader = createPaginatedLoader(container, 25, 25)
        m.Loader.Listener = m
        m.Loader.Port = m.Port
        m.MessageHandler = m.Loader

        for index = 0 to keys.Count() - 1
            status = CreateObject("roAssociativeArray")
            status.listStyle = invalid
            status.listDisplayMode = invalid
            status.focusedIndex = 0
            status.content = []
            status.lastUpdatedSize = 0
            m.contentArray[index] = status
        next

        m.Loader.LoadMoreContent(0, 0)
    else
        ' We already grabbed the full list, no need to bother with loading
        ' in chunks.

        status = CreateObject("roAssociativeArray")
        status.content = container.GetMetadata()

        m.Loader = createDummyLoader(status.content)

        if container.Count() > 0 then
            contentType = container.GetMetadata()[0].ContentType
        else
            contentType = invalid
        end if

        if m.UseDefaultStyles then
            aa = getDefaultListStyle(container.ViewGroup, contentType)
            status.listStyle = aa.style
            status.listDisplayMode = aa.display
        else
            status.listStyle = m.ListStyle
            status.listDisplayMode = m.ListDisplayMode
        end if

        status.focusedIndex = 0
        status.lastUpdatedSize = status.content.Count()

        m.contentArray[0] = status
    end if

    m.focusedList = 0
    m.ShowList(0)
    facade.Close()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roPosterScreenEvent" then
            '* Focus change on the filter bar causes content change
            if msg.isListFocused() then
                m.focusedList = msg.GetIndex()
                m.ShowList(m.focusedList)
                m.Loader.LoadMoreContent(m.focusedList, 0)
            else if msg.isListItemSelected() then
                index = msg.GetIndex()
                content = m.contentArray[m.focusedList].content
                selected = content[index]
                contentType = selected.ContentType

                print "Content type in poster screen:";contentType

                if contentType = "series" OR NOT m.FilterMode then
                    breadcrumbs = [selected.Title]
                else
                    breadcrumbs = [names[m.focusedList], selected.Title]
                end if

                m.ViewController.CreateScreenForItem(content, index, breadcrumbs)
            else if msg.isScreenClosed() then
                ' Make sure we don't have hang onto circular references
                m.Loader.Listener = invalid
                m.Loader = invalid
                m.MessageHandler = invalid

                m.ViewController.PopScreen(m)
                return -1
            else if msg.isListItemFocused() then
                ' We don't immediately update the screen's content list when
                ' we get more data because the poster screen doesn't perform
                ' as well as the grid screen (which has an actual method for
                ' refreshing part of the list). Instead, if the user has
                ' focused toward the end of the list, update the content.

                status = m.contentArray[m.focusedList]
                status.focusedIndex = msg.GetIndex()
                if status.focusedIndex + 10 > status.lastUpdatedSize AND status.content.Count() > status.lastUpdatedSize then
                    m.Screen.SetContentList(status.content)
                    status.lastUpdatedSize = status.content.Count()
                end if
            end if
        end If
    end while
    return 0
End Function

Sub posterOnDataLoaded(row As Integer, data As Object, startItem as Integer, count As Integer)
    status = m.contentArray[row]
    status.content = data

    ' If this was the first content we loaded, set up the styles
    if startItem = 0 AND count > 0 then
        if m.UseDefaultStyles then
            if data.Count() > 0 then
                aa = getDefaultListStyle(data[0].ViewGroup, data[0].contentType)
                status.listStyle = aa.style
                status.listDisplayMode = aa.display
            end if
        else
            status.listStyle = m.ListStyle
            status.listDisplayMode = m.ListDisplayMode
        end if
    end if

    if startItem = 0 OR status.focusedIndex + 10 > status.lastUpdatedSize then
        m.ShowList(row)
        status.lastUpdatedSize = status.content.Count()
    end if

    ' Continue loading this row
    m.Loader.LoadMoreContent(row, 0)
End Sub

Sub posterShowContentList(index)
    status = m.contentArray[index]
    m.Screen.SetContentList(status.content)

    if status.listStyle <> invalid then
        m.Screen.SetListStyle(status.listStyle)
    end if
    if status.listDisplayMode <> invalid then
        m.Screen.SetListDisplayMode(status.listDisplayMode)
    end if

    Print "Showing screen with "; status.content.Count(); " elements"
    Print "List style is "; status.listStyle; ", "; status.listDisplayMode

    m.Screen.Show()
    m.Screen.SetFocusedListItem(status.focusedIndex)
End Sub

Function getDefaultListStyle(viewGroup, contentType) As Object
    aa = CreateObject("roAssociativeArray")
    aa.style = "arced-square"
    aa.display = "scale-to-fit"

    if viewGroup = "episode" AND contentType = "episode" then
        aa.style = "flat-episodic"
        aa.display = "zoom-to-fill"
    else if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" then
        aa.style = "arced-portrait"
    end if

    return aa
End Function

Sub posterSetListStyle(style, displayMode)
    m.ListStyle = style
    m.ListDisplayMode = displayMode
    m.UseDefaultStyles = false
End Sub

