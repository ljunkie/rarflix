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
    obj.LoadContent = posterLoadMoreContent
    obj.SetListStyle = posterSetListStyle

    obj.UseDefaultStyles = true
    obj.ListStyle = invalid
    obj.ListDisplayMode = invalid
    obj.FilterMode = invalid

    obj.contentArray = []

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

        for index = 0 to keys.Count() - 1
            status = CreateObject("roAssociativeArray")
            status.content = []
            status.viewGroup = invalid
            status.contentType = invalid
            status.listStyle = invalid
            status.listDisplayMode = invalid
            status.loadStatus = 0 ' 0:Not loaded, 1:Partially loaded, 2:Fully loaded
            m.contentArray[index] = status
        next
    else
        ' We already grabbed the full list, no need to bother with loading
        ' in chunks.

        status = CreateObject("roAssociativeArray")

        status.viewGroup = container.ViewGroup
        if container.Count() > 0 then
            status.contentType = container.GetMetadata()[0].ContentType
        else
            status.contentType = invalid
        end if

        status.content = container.GetMetadata()
        status.loadStatus = 2 ' Fully loaded

        if m.UseDefaultStyles then
            aa = getDefaultListStyle(status.viewGroup, status.contentType)
            status.listStyle = aa.style
            status.listDisplayMode = aa.display
        else
            status.listStyle = m.ListStyle
            status.listDisplayMode = m.ListDisplayMode
        end if

        m.contentArray[0] = status
    end if

    focusedListItem = 0
    m.ShowList(focusedListItem)
    facade.Close()

    ' We don't start loading a filter section until the user selects it,
    ' and once we start loading it, we do it in chunks. While we're
    ' loading any particular section, use a small timeout so we can
    ' continue loading chunks.
    if m.contentArray[0].loadStatus < 2 then
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
                if m.contentArray[focusedListItem].loadStatus < 2 then
                    timeout = 5
                end if
            else if msg.isListItemSelected() then
                status = m.contentArray[focusedListItem]
                index = msg.GetIndex()
                selected = status.content[index]
                contentType = selected.ContentType

                print "Content type in poster screen:";contentType

                if contentType = "series" OR NOT m.FilterMode then
                    breadcrumbs = [selected.Title]
                else
                    breadcrumbs = [names[index], selected.Title]
                end if

                m.ViewController.CreateScreenForItem(status.content, index, breadcrumbs)
            else if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                return -1
            end if
        else if msg = invalid then
            ' An invalid event is our timeout, load some more data.
            if m.LoadContent(server, container.sourceUrl, keys[focusedListItem], focusedListItem, 25) then
                timeout = 0
            end if
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
    if focusFirstItem then m.Screen.SetFocusedListItem(0)
End Sub

Function posterLoadMoreContent(server, sourceUrl, key, index, count) As Boolean
    status = m.contentArray[index]

    if status.loadStatus = 2 then return true

    startItem = status.content.Count()

    response = server.GetPaginatedQueryResponse(sourceUrl, key, startItem, count)
    container = createPlexContainerForXml(response)

    ' If the container doesn't play nice with pagination requests then
    ' whatever we got is the total size.
    if response.xml@totalSize <> invalid then
        totalSize = strtoi(response.xml@totalSize)
    else
        totalSize = container.Count()
    end if

    if totalSize <= 0 then
        status.loadStatus = 2
        return true
    end if

    ' If this was the first content we loaded, set up the styles
    if status.loadStatus = 0 then
        if m.UseDefaultStyles then
            status.viewGroup = container.ViewGroup
            if container.Count() > 0 then
                status.contentType = container.GetMetadata()[0].ContentType
            end if

            aa = getDefaultListStyle(status.viewGroup, status.contentType)
            status.listStyle = aa.style
            status.listDisplayMode = aa.display
        else
            status.listStyle = m.ListStyle
            status.listDisplayMode = m.ListDisplayMode
        end if
    end if

    status.content.Append(container.GetMetadata())

    m.ShowList(index, status.loadStatus = 0)

    if status.content.Count() < totalSize then
        status.loadStatus = 1
        return false
    else
        status.loadStatus = 2
        return true
    end if
End Function

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

