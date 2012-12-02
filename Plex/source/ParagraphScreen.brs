'*
'* A very simple wrapper around a paragraph screen.
'*

Function createParagraphScreen(header, paragraphs, viewController)
  obj = CreateObject("roAssociativeArray")
  initBaseScreen(obj, viewController)

  screen = CreateObject("roParagraphScreen")
  screen.SetMessagePort(obj.Port)

  screen.AddHeaderText(header)

  for each paragraph in paragraphs
    screen.AddParagraph(paragraph)
  next

  screen.AddButton(1, "close")

  obj.Screen = screen
  obj.HandleMessage = paragraphHandleMessage

  return obj
End Function

Function paragraphHandleMessage(msg) As Boolean
  handled = false

  if type(msg) = "roParagraphScreenEvent" then
    handled = true

    if msg.isScreenClosed() then
      m.ViewController.PopScreen(m)
    else if msg.isButtonPressed() then
      m.Screen.Close()
    end if
  end if

  return handled
End Function
