'*
'* A simple wrapper around a list screen that can be used to ask the user
'* to choose from a list of option (including boolean options).
'*

Function createEnumScreen(options, selected, viewController) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roListScreen")
    screen.SetMessagePort(obj.Port)

    ' Standard properties for all our screen types
    obj.Screen = screen
    obj.HandleMessage = enumHandleMessage

    if type(selected) = "Integer" then
        focusedIndex = selected
    else
        focusedIndex = 0
    end if

    lsInitBaseListScreen(obj)

    for each option in options
        if type(option) = "roAssociativeArray" then
            if option.title = invalid then
                option.title = ""
            end if
            if option.EnumValue = invalid then
                option.EnumValue = option.title
            end if
            if GetInterface(selected, "ifString") <> invalid AND selected = option.EnumValue then
                focusedIndex = obj.contentArray.Count()
            end if

            obj.AddItem(option)
        else
            o = {title: option, EnumValue: option}
            if GetInterface(selected, "ifString") <> invalid AND selected = option then
                focusedIndex = obj.contentArray.Count()
            end if

            obj.AddItem(o)
        end if
    next

    screen.SetFocusedListItem(focusedIndex)

    ' If the user selects something, these will be set.
    obj.SelectedIndex = invalid
    obj.SelectedValue = invalid
    obj.SelectedLabel = invalid

    return obj
End Function

Function enumHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Exiting list screen")
            m.ViewController.PopScreen(m)
        else if msg.isListItemSelected() then
            option = m.contentArray[msg.GetIndex()]
            if option <> invalid then
                m.SelectedIndex = msg.GetIndex()
                m.SelectedValue = option.EnumValue
                m.SelectedLabel = option.title
                if m.Listener <> invalid then
                    m.Listener.OnUserInput(m.SelectedValue, m)
                end if
            end if
            m.Screen.Close()
        end if
    end if

    return handled
End Function
