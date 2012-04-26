'*
'* A simple wrapper around a keyboard screen.
'*

Function createKeyboardScreen(viewController As Object) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roKeyboardScreen")

    screen.SetMessagePort(port)

    screen.AddButton(1, "done")
    screen.AddButton(2, "back")

    ' Standard properties for all our screen types
    obj.Item = invalid
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 0

    obj.Show = showKeyboardScreen
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

    while true
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roKeyboardScreenEvent" then
            if msg.isScreenClosed() then
                Debug("Exiting keyboard screen")
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isButtonPressed() then
                if msg.GetIndex() = 1 then
                    if m.ValidateText = invalid OR m.ValidateText(m.Screen.GetText()) then
                        m.Text = m.Screen.GetText()
                        m.Screen.Close()
                    end if
                else if msg.GetIndex() = 2 then
                    m.Screen.Close()
                end if
            end if
        end if
    end while
End Sub

