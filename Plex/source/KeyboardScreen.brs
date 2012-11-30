'*
'* A simple wrapper around a keyboard screen.
'*

Function createKeyboardScreen(viewController As Object) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roKeyboardScreen")
    screen.SetMessagePort(m.Port)

    screen.AddButton(1, "done")
    screen.AddButton(2, "back")

    ' Standard properties for all our screen types
    obj.Screen = screen

    obj.Show = showKeyboardScreen
    obj.HandleMessage = kbHandleMessage
    obj.ValidateText = invalid

    ' If the user enters this text, as opposed to just exiting the screen,
    ' this will be set.
    obj.Text = invalid

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
        else if msg.isButtonPressed() then
            if msg.GetIndex() = 1 then
                if m.ValidateText = invalid OR m.ValidateText(m.Screen.GetText()) then
                    m.Text = m.Screen.GetText()
                    if m.Listener <> invalid then
                        m.Listener.OnUserInput(m.Text)
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
