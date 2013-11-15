'*
'* A simple wrapper around a keyboard screen.
'*

Function createKeyboardScreen(viewController As Object, item=invalid, heading=invalid, initialValue="", secure=false) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roKeyboardScreen")
    screen.SetMessagePort(obj.Port)

    screen.AddButton(1, "done")
    screen.AddButton(2, "back")

    if heading <> invalid then
        screen.SetDisplayText(heading)
    end if
    screen.SetText(initialValue)
    screen.SetSecureText(secure)

    ' Standard properties for all our screen types
    obj.Screen = screen
    obj.Item = item

    obj.Show = showKeyboardScreen
    obj.HandleMessage = kbHandleMessage
    obj.ValidateText = invalid

    ' If the user enters this text, as opposed to just exiting the screen,
    ' this will be set.
    obj.Text = invalid

    obj.SetText = kbSetText

    ' TODO(schuyler): It'd be nice to use a friendly field name here. The
    ' heading is potentially long and a poor fit though.
    NowPlayingManager().SetFocusedTextField(firstOf(heading, "Field"), initialValue, secure)

    return obj
End Function

Sub showKeyboardScreen()
    if m.Text <> invalid then
        m.Screen.SetText(m.Text)
    end if

    m.Screen.Show()
End Sub

Function kbHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roKeyboardScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Debug("Exiting keyboard screen")
            m.ViewController.PopScreen(m)
            NowPlayingManager().SetFocusedTextField(invalid, invalid, false)
        else if msg.isButtonPressed() then
            if msg.GetIndex() = 1 then
                if m.ValidateText = invalid OR m.ValidateText(m.Screen.GetText()) then
                    m.Text = m.Screen.GetText()
                    if m.Listener <> invalid then
                        m.Listener.OnUserInput(m.Text, m)
                    else if m.Item <> invalid then
                        callback = CreateObject("roAssociativeArray")
                        callback.Heading = m.Text
                        callback.Item = CreateObject("roAssociativeArray")
                        callback.Item.server = m.Item.server
                        callback.Item.Title = m.Text
                        callback.Item.sourceUrl = m.Item.sourceUrl
                        callback.Item.viewGroup = m.Item.viewGroup

                        if instr(1, m.Item.Key, "?") > 0 then
                            callback.Item.Key = m.Item.Key + "&query=" + HttpEncode(m.Text)
                        else
                            callback.Item.Key = m.Item.Key + "?query=" + HttpEncode(m.Text)
                        end if

                        callback.OnAfterClose = createScreenForItemCallback
                        m.ViewController.afterCloseCallback = callback
                    end if
                    m.Screen.Close()
                end if
            else if msg.GetIndex() = 2 then
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

Sub kbSetText(text)
    m.Screen.SetText(text)
End Sub
