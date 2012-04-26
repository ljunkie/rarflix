'*
'* Utilities for creating dialogs
'*

Function createBaseDialog() As Object
    obj = CreateObject("roAssociativeArray")

    obj.Port = CreateObject("roMessagePort")

    obj.Show = dialogShow
    obj.Refresh = dialogRefresh
    obj.SetButton = dialogSetButton

    ' Properties that can be set by the caller/subclass
    obj.Facade = invalid
    obj.Buttons = []
    obj.HandleButton = invalid
    obj.Title = invalid
    obj.Text = invalid
    obj.Item = invalid

    obj.ScreensToClose = []

    return obj
End Function

Function createPopupMenu(item) As Object
    ' We have to fetch the buttons, so show a little spinner
    facade = CreateObject("roOneLineDialog")
    facade.SetTitle("Retrieving...")
    facade.ShowBusyAnimation()
    facade.Show()

    dlg = createBaseDialog()

    dlg.Item = item
    dlg.Facade = facade

    dlg.Title = item.Title
    dlg.Text = firstOf(item.FullDescription, item.Description)

    dlg.HandleButton = popupHandleButton

    container = createPlexContainerForUrl(item.server, item.sourceUrl, item.key)

    if container.xml@header <> invalid AND container.xml@replaceParent = "1" then
        dlg.Title = container.xml@header
        dlg.Text = container.xml@message
    else
        for each option in container.GetMetadata()
            dlg.SetButton(option.Key, option.Title)
        next
    end if

    return dlg
End Function

Sub dialogSetButton(command, text)
    for each button in m.Buttons
        button.Reset()
        if button.Next() = command then
            button[command] = text
            return
        end if
    next

    button = {}
    button[command] = text
    m.Buttons.Push(button)
End Sub

Sub dialogRefresh()
    ' There's no way to change (or clear) buttons once the dialog has been
    ' shown, so create a brand new dialog.

    if m.Dialog <> invalid then
        overlay = true
        m.ScreensToClose.Unshift(m.Dialog)
    else
        overlay = false
    end if

    m.Dialog = CreateObject("roMessageDialog")
    m.Dialog.SetMessagePort(m.Port)
    m.Dialog.SetMenuTopLeft(true)
    m.Dialog.EnableBackButton(true)
    m.Dialog.EnableOverlay(overlay)
    if m.Title <> invalid then m.Dialog.SetTitle(m.Title)
    if m.Text <> invalid then m.Dialog.SetText(m.Text)

    if m.Buttons.Count() = 0 then
        m.Buttons.Push({ok: "Ok"})
    end if

    buttonCount = 0
    m.ButtonCommands = []
    for each button in m.Buttons
        button.Reset()
        cmd = button.Next()
        m.ButtonCommands[buttonCount] = cmd
        if button[cmd] = "_rate_" then
            m.Dialog.AddRatingButton(buttonCount, m.Item.UserRating, m.Item.StarRating, "")
        else
            m.Dialog.AddButton(buttonCount, button[cmd])
        end if
        buttonCount = buttonCount + 1
    next

    m.Dialog.Show()
End Sub

Function dialogShow()
    if m.Facade <> invalid then
        m.ScreensToClose.Unshift(m.Facade)
    end if

    m.Refresh()

    while true
        msg = wait(0, m.Port)
        if type(msg) = "roMessageDialogEvent" then
            if msg.isScreenClosed() then
                exit while
            else if msg.isButtonPressed() then
                command = m.ButtonCommands[msg.getIndex()]
                Debug("Button pressed: " + tostr(command))
                done = true
                if m.HandleButton <> invalid then
                    done = m.HandleButton(command, msg.getData())
                end if
                if done then exit while
            end if
        else if msg = invalid then
            ' I don't understand this, but we seem to get this and no close
            ' event depending on how the dialog is closed. Since we should
            ' never get this normally, just treat it as a close.
            exit while
        end if
    end while

    ' Fun fact, if we close the facade before the event loop, the
    ' EnableBackButton call loses its effect and pressing back exits the
    ' parent screen instead of just the dialog.
    for each screen in m.ScreensToClose
        screen.Close()
    next
    m.Dialog.Close()

    m.ScreensToClose.Clear()
End Function

Function popupHandleButton(key, data) As Boolean
    facade = CreateObject("roOneLineDialog")
    facade.SetTitle("Please wait...")
    facade.ShowBusyAnimation()
    facade.Show()

    response = m.Item.server.GetQueryResponse(m.Item.sourceUrl, key)

    if response.xml@message <> invalid then
        dialog = createBaseDialog()
        dialog.Facade = facade
        dialog.Title = response.xml@header
        dialog.Text = response.xml@message
        dialog.Show()
    else
        facade.Close()
    end if

    return true
End Function

