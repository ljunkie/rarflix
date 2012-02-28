'*
'* Utilities for creating dialogs
'*

Function createBaseDialog(dlgType="roMessageDialog") As Object
    obj = CreateObject("roAssociativeArray")

    dialog = CreateObject(dlgType)
    port = CreateObject("roMessagePort")
    dialog.SetMessagePort(port)

    dialog.SetMenuTopLeft(true)
    dialog.EnableBackButton(true)

    obj.Dialog = dialog
    obj.Port = port

    obj.Show = dialogShow

    ' Properties that can be set by the caller/subclass
    obj.Facade = invalid
    obj.Buttons = {ok: "Ok"}
    obj.HandleButton = invalid
    obj.Title = invalid
    obj.Text = invalid

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

    dlg.Buttons = CreateObject("roAssociativeArray")
    container = createPlexContainerForUrl(item.server, item.sourceUrl, item.key)
    for each option in container.GetMetadata()
        dlg.Buttons[option.Key] = option.Title
    next

    return dlg
End Function

Function dialogShow()
    m.Dialog.SetTitle(m.Title)
    m.Dialog.SetText(m.Text)

    dlg = m.Dialog
    port = m.Port

    buttonCommands = []
    buttonCount = 0
    for each cmd in m.Buttons
        m.Dialog.AddButton(buttonCount, m.Buttons[cmd])

        buttonCommands[buttonCount] = cmd
        buttonCount = buttonCount + 1
    next

    dlg.Show()

    while true
        msg = wait(0, port)
        if type(msg) = "roMessageDialogEvent" then
            if msg.isScreenClosed() then
                exit while
            else if msg.isButtonPressed() then
                command = buttonCommands[msg.getIndex()]
                print "Button pressed: "; command
                if m.HandleButton <> invalid then m.HandleButton(command)
                exit while
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
    if m.Facade <> invalid then m.Facade.Close()
    dlg.Close()
End Function

Function popupHandleButton(key)
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
End Function

