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

    obj.Progressive = false
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
                ' TODO(schuyler): Progressive search goes here...
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
                if instr(1, m.Item.Key, "?") > 0 then
                    item.Key = m.Item.Key + "&query=" + HttpEncode(term)
                else
                    item.Key = m.Item.Key + "?query=" + HttpEncode(term)
                end if

                m.ViewController.CreateScreenForItem(item, invalid, [item.Title])
            end if
        end if
    end while

    return 0
End Function
