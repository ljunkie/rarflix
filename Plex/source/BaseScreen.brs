'*
'* BrightScript doesn't really have inheritance per se, but we'd like all of
'* our screen types to use a certain set of properties and function names. So
'* define some helper methods for initializing those base properties.
'*

Sub initBaseScreen(screen, viewController)
    ' These should be set by the subclass when appropriate
    screen.Item = invalid
    screen.Screen = invalid

    screen.Port = viewController.GlobalMessagePort
    screen.ViewController = viewController
    screen.Loader = invalid
    screen.Listener = invalid

    screen.Activate = baseActivate
    screen.Show = baseShow
    screen.HandleMessage = baseHandleMessage
    screen.DestroyAndRecreate = invalid
End Sub

Sub baseActivate()
    ' Called when the screen becomes active again, after whatever was opened
    ' after it has been popped. Nothing to do here in most cases.
End Sub

Sub baseShow()
    ' In the simplest case, we'll assume we just need to show the underlying
    ' screen and allow the global message loop to run.
    m.Screen.Show()
End Sub

Function baseHandleMessage(msg) As Boolean
    ' This should almost always be overridden, but in the base case we'll check
    ' for close events and pop ourselves.
    if msg.isScreenClosed() then
        m.ViewController.PopScreen(m)
        return true
    end if

    return false
End Function