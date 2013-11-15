'*
'* A default search screen for searching PMS containers.
'*

Function createSearchScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roSearchScreen")
    history = CreateObject("roSearchHistory")

    screen.SetMessagePort(obj.Port)

    ' Always start with recent searches, even if we end up doing suggestions
    screen.SetSearchTerms(history.GetAsArray())
    screen.SetSearchTermHeaderText("Recent Searches:")

    screen.SetSearchButtonText("search")
    screen.SetClearButtonEnabled(true)
    screen.SetClearButtonText("clear history")

    ' Standard properties for all our Screen types
    obj.Item = item
    obj.Screen = screen

    obj.HandleMessage = ssHandleMessage
    obj.OnUrlEvent = ssOnUrlEvent
    obj.OnTimerExpired = ssOnTimerExpired

    obj.Progressive = true
    obj.History = history

    obj.SetText = ssSetText

    NowPlayingManager().SetFocusedTextField("Search", "", false)

    return obj
End Function

Function ssHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roSearchScreenEvent" then
        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
            NowPlayingManager().SetFocusedTextField(invalid, invalid, false)
        else if msg.isCleared() then
            m.History.Clear()
            m.Screen.ClearSearchTerms()
        else if msg.isPartialResult() then
            ' We got some additional characters, if the user pauses for a
            ' bit then kick off a search suggestion request.
            if m.Progressive then
                if m.ProgressiveTimer = invalid then
                    m.ProgressiveTimer = createTimer()
                    m.ProgressiveTimer.SetDuration(250)
                end if
                m.ProgressiveTimer.Mark()
                m.ProgressiveTimer.Active = true
                m.ViewController.AddTimer(m.ProgressiveTimer, m)
                m.SearchTerm = msg.GetMessage()
                NowPlayingManager().SetFocusedTextField("Search", m.SearchTerm, false)
            end if
        else if msg.isFullResult() then
            term = msg.GetMessage()
            m.History.Push(term)

            Debug("Searching for " + term)

            ' Create a dummy item with the key set to the search URL
            item = CreateObject("roAssociativeArray")
            item.server = m.Item.Server
            item.Title = "Search for '" + term + "'"
            item.sourceUrl = m.Item.sourceUrl
            item.viewGroup = m.Item.viewGroup
            item.searchTerm = term
            if instr(1, m.Item.Key, "?") > 0 then
                item.Key = m.Item.Key + "&query=" + HttpEncode(term)
            else
                item.Key = m.Item.Key + "?query=" + HttpEncode(term)
            end if

            m.ViewController.CreateScreenForItem(item, invalid, [item.Title])
        end if
    end if

    return handled
End Function

Sub ssOnTimerExpired(timer)
    ' TODO(schuyler): How should we actually handle progressive
    ' search when we're not searching a particular server? Should we
    ' do it at all? Right now we arbitrarily pick a server and use it
    ' for generating suggestions. If we had a primary server, that
    ' would work...

    if m.Item.server <> invalid then
        server = m.Item.server
        sourceUrl = m.Item.sourceUrl
        if instr(1, m.Item.Key, "?") > 0 then
            url = m.Item.Key + "&query=" + HttpEncode(m.SearchTerm)
        else
            url = m.Item.Key + "?query=" + HttpEncode(m.SearchTerm)
        end if
    else
        server = GetPrimaryServer()
        url = "/search?local=1&query=" + HttpEncode(m.SearchTerm)
        sourceUrl = ""
    end if

    if server <> invalid then
        httpRequest = server.CreateRequest(sourceUrl, url)
        httpRequest.AddHeader("X-Plex-Container-Start", "0")
        httpRequest.AddHeader("X-Plex-Container-Size", "10")
        context = CreateObject("roAssociativeArray")
        context.requestType = "progressive"
        m.ViewController.StartRequest(httpRequest, m, context)
    end if
End Sub

Sub ssOnUrlEvent(msg, requestContext)
    suggestions = []
    xml = CreateObject("roXMLElement")
    xml.Parse(msg.GetString())

    for each elem in xml.GetChildElements()
        if elem.GetName() <> "Provider" then
            title = firstOf(elem@title, elem@name)
            if title <> invalid then suggestions.Push(title)
        end if
    next

    if suggestions.Count() > 0 then
        m.Screen.SetSearchTermHeaderText("Search Suggestions:")
        m.Screen.SetClearButtonEnabled(false)
        m.Screen.SetSearchTerms(suggestions)
    end if
End Sub

Sub ssSetText(text)
    m.Screen.SetSearchText(text)
End Sub
