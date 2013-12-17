'*
'* A very simple wrapper around a text screen.
'*

Function createTextScreen(header, title, lines, viewController, noButton) as Object
  obj = CreateObject("roAssociativeArray")
  initBaseScreen(obj, viewController)

  screen = CreateObject("roTextScreen")
  screen.SetMessagePort(obj.Port)

  screen.SetHeaderText(header)
  if title <> invalid then screen.Settitle(title)

  for each line in lines
    screen.AddText(line)
  next

  if noButton = invalid then screen.AddButton(1, "close")

  obj.Screen = screen
  obj.HandleMessage = textHandleMessage

  return obj
End Function

Function textHandleMessage(msg) As Boolean
  handled = false

  if type(msg) = "roTextScreenEvent" then
    handled = true

    if msg.isScreenClosed() then
      m.ViewController.PopScreen(m)
    else if msg.isButtonPressed() then
      m.Screen.Close()
    end if
  end if

  return handled
End Function
