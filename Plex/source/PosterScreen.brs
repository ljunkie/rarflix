'* Displays the content in a poster screen. Can be any content type.

Function createPosterScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)

    ' Standard properties for all our screen types
    obj.Item = item
    obj.Screen = screen
    obj.ViewController = viewController

    obj.Show = showPosterScreen
    obj.ShowList = posterShowContentList
    obj.SetListStyle = posterSetListStyle

    obj.UseDefaultStyles = true
    obj.ListStyle = invalid
    obj.ListDisplayMode = invalid
    obj.FilterMode = invalid

    obj.styles = []

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
        m.Loader = createPaginatedLoader(server, container.sourceUrl, keys, 25, 25)

        for index = 0 to keys.Count() - 1
            style = CreateObject("roAssociativeArray")
            style.listStyle = invalid
            style.listDisplayMode = invalid
            m.styles[index] = style
        next
    else
        ' We already grabbed the full list, no need to bother with loading
        ' in chunks.

        m.Loader = createDummyLoader([container.GetMetadata()])

        style = CreateObject("roAssociativeArray")

        if container.Count() > 0 then
            contentType = container.GetMetadata()[0].ContentType
        else
            contentType = invalid
        end if

        if m.UseDefaultStyles then
            aa = getDefaultListStyle(container.ViewGroup, contentType)
            style.listStyle = aa.style
            style.listDisplayMode = aa.display
        else
            style.listStyle = m.ListStyle
            style.listDisplayMode = m.ListDisplayMode
        end if

        m.styles[0] = style
    end if

    focusedListItem = 0
    m.ShowList(focusedListItem)
    facade.Close()

    ' We don't start loading a filter section until the user selects it,
    ' and once we start loading it, we do it in chunks. While we're
    ' loading any particular section, use a small timeout so we can
    ' continue loading chunks.
    if m.Loader.GetLoadStatus(0) < 2 then
        timeout = 5
    else
        timeout = 0
    end if

    while true
        msg = wait(timeout, m.Screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            '* Focus change on the filter bar causes content change
            if msg.isListFocused() then
                focusedListItem = msg.GetIndex()
                m.ShowList(focusedListItem)
                if m.Loader.GetLoadStatus(focusedListItem) < 2 then
                    timeout = 5
                end if
            else if msg.isListItemSelected() then
                index = msg.GetIndex()
                content = m.Loader.GetContent(focusedListItem)
                selected = content[index]
                contentType = selected.ContentType

                print "Content type in poster screen:";contentType

                if contentType = "series" OR NOT m.FilterMode then
                    breadcrumbs = [selected.Title]
                else
                    breadcrumbs = [names[index], selected.Title]
                end if

                m.ViewController.CreateScreenForItem(content, index, breadcrumbs)
            else if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                return -1
            end if
        else if msg = invalid then
            ' An invalid event is our timeout, load some more data.

            initialStatus = m.Loader.GetLoadStatus(focusedListItem)
            if m.Loader.LoadMoreContent(focusedListItem, 0) then
                timeout = 0
            end if

            ' If this was the first content we loaded, set up the styles
            if initialStatus = 0 then
                style = m.styles[focusedListItem]
                if m.UseDefaultStyles then
                    content = m.Loader.GetContent(focusedListItem)
                    if content.Count() > 0 then
                        aa = getDefaultListStyle(content[0].ViewGroup, content[0].contentType)
                        style.listStyle = aa.style
                        style.listDisplayMode = aa.display
                    end if
                else
                    style.listStyle = m.ListStyle
                    style.listDisplayMode = m.ListDisplayMode
                end if
            end if

            m.ShowList(focusedListItem, initialStatus = 0)
        end If
    end while
    return 0
End Function

Function ChannelInfo(channel) 

    print "Store info for:";channel
    port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(true)
	dialog.SetTitle(channel.title) 
	dialog.SetText(channel.description) 
	queryResponse = channel.server.GetQueryResponse(channel.sourceUrl, channel.key)
        ' TODO(schuyler): Fix this to use a PlexContainer, it's broken in the meantime
	content = channel.server.GetContent(queryResponse)
	buttonCommands = CreateObject("roAssociativeArray")
	buttonCount = 0
	for each item in content
		buttonTitle = item.title
		dialog.AddButton(buttonCount, buttonTitle)
		buttonCommands[str(buttonCount)+"_key"] = item.key
		buttonCount = buttonCount + 1
	next
	dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
				print "Button pressed:";msg.getIndex()
				commandKey = buttonCommands[str(msg.getIndex())+"_key"]
				print "Command Key:"+commandKey
				dialog.close()
				retrieving = CreateObject("roOneLineDialog")
				retrieving.SetTitle("Please wait ...")
				retrieving.ShowBusyAnimation()
				retrieving.Show()
				commandResponse = channel.server.GetQueryResponse(channel.sourceUrl, commandKey)
				retrieving.Close()
			end if 
		end if
	end while
End Function

Sub posterShowContentList(index, focusFirstItem=true)
    content = m.Loader.GetContent(index)
    m.Screen.SetContentList(content)

    style = m.styles[index]
    if style.listStyle <> invalid then
        m.Screen.SetListStyle(style.listStyle)
    end if
    if style.listDisplayMode <> invalid then
        m.Screen.SetListDisplayMode(style.listDisplayMode)
    end if

    Print "Showing screen with "; content.Count(); " elements"
    Print "List style is "; style.listStyle; ", "; style.listDisplayMode

    m.Screen.Show()
    if focusFirstItem then m.Screen.SetFocusedListItem(0)
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

