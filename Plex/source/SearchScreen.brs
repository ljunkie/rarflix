'*
'* A default search screen for searching PMS containers.
'*

Function createSearchScreen(item, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSearchScreen")
    history = CreateObject("roSearchHistory")

    screen.SetMessagePort(port)

    ' Always start with recent searches, even if we end up doing suggestions
    screen.SetSearchTerms(history.GetAsArray())
    screen.SetSearchTermHeaderText("Recent Searches:")

    screen.SetSearchButtonText("search")
    screen.SetClearButtonEnabled(true)
    screen.SetClearButtonText("clear history")

    ' Standard properties for all our Screen types
    obj.Item = item
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showSearchScreen

    obj.Progressive = (item.server <> invalid)
    obj.History = history

    return obj
End Function

Function showSearchScreen() As Integer
    m.Screen.Show()

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roSearchScreenEvent" then
            if msg.isScreenClosed() then
                m.MessageHandler = invalid
                m.ViewController.PopScreen(m)
                return -1
            else if msg.isCleared() then
                m.History.Clear()
                m.Screen.ClearSearchTerms()
            else if msg.isPartialResult() then
                ' We got some additional characters, if the user pauses for a
                ' bit then kick off a search suggestion request.
                if m.Progressive then
                    m.MsgTimeout = 250
                    m.SearchTerm = msg.GetMessage()
                end if
            else if msg.isFullResult() then
                term = msg.GetMessage()
                m.History.Push(term)

                print "Searching for "; term

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
        else if msg = invalid then
            m.MsgTimeout = 0

            if instr(1, m.Item.Key, "?") > 0 then
                url = m.Item.Key + "&query=" + HttpEncode(m.SearchTerm)
            else
                url = m.Item.Key + "?query=" + HttpEncode(m.SearchTerm)
            end if
            progressiveRequest = m.Item.server.CreateRequest(m.Item.sourceUrl, url)
            progressiveRequest.SetPort(m.Port)
            progressiveRequest.AddHeader("X-Plex-Container-Start", "0")
            progressiveRequest.AddHeader("X-Plex-Container-Size", "10")
            progressiveRequest.AsyncGetToString()
        else if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
            suggestions = []
            xml = CreateObject("roXMLElement")
            xml.Parse(msg.GetString())

            for each elem in xml.GetChildElements()
                title = firstOf(elem@title, elem@name)
                if title <> invalid then suggestions.Push(title)
            next

            if suggestions.Count() > 0 then
                m.Screen.SetSearchTermHeaderText("Search Suggestions:")
                m.Screen.SetClearButtonEnabled(false)
                m.Screen.SetSearchTerms(suggestions)
            end if
        end if
    end while

    return 0
End Function
