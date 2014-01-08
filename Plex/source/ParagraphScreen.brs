'*
'* A very simple wrapper around a paragraph screen.
'*

Function createParagraphScreen(header, paragraphs, viewController)
  obj = CreateObject("roAssociativeArray")
  initBaseScreen(obj, viewController)

  obj.Show = paragraphShow

  screen = CreateObject("roParagraphScreen")
  screen.SetMessagePort(obj.Port)

  screen.AddHeaderText(header)

  for each paragraph in paragraphs
    screen.AddParagraph(paragraph)
  next

  ' Allow callers to add buttons just like on our dialogs
  obj.SetButton = dialogSetButton
  obj.Buttons = []
  obj.HandleButton = invalid

  obj.Screen = screen
  obj.HandleMessage = paragraphHandleMessage

  return obj
End Function

Function paragraphShow()
  ' If the caller didn't add any buttons, add a simple close button
  if m.Buttons.Count() = 0 then
    m.Buttons.Push({close: "close"})
  end if

  buttonCount = 0
  m.ButtonCommands = []
  for each button in m.Buttons
    button.Reset()
    cmd = button.Next()
    m.ButtonCommands[buttonCount] = cmd
    m.Screen.AddButton(buttonCount, button[cmd])
    buttonCount = buttonCount + 1
  next

  m.Screen.Show()
End Function

Function paragraphHandleMessage(msg) As Boolean
  handled = false

  if type(msg) = "roParagraphScreenEvent" then
    handled = true

    if msg.isScreenClosed() then
      m.ViewController.PopScreen(m)
    else if msg.isButtonPressed() then
      command = m.ButtonCommands[msg.GetIndex()]
      Debug("Button pressed: " + tostr(command))
      done = true
      if m.HandleButton <> invalid then
        done = m.HandleButton(command, msg.GetData())
      end if
      if done then m.Screen.Close()
    end if
  end if

  return handled
End Function
