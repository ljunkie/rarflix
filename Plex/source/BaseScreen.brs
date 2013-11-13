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
    screen.Cleanup = invalid

    screen.popOnActivate = false
    screen.closeOnActivate = false

    viewController.AssignScreenID(screen)
End Sub

Sub baseActivate(priorScreen)
    ' Called when the screen becomes active again, after whatever was opened
    ' after it has been popped.

    if m.popOnActivate then
        m.ViewController.PopScreen(m)
    else if m.closeOnActivate then
        if m.Screen <> invalid then
            m.Screen.Close()
        else
            m.ViewController.PopScreen(m)
        end if
    end if
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

Sub baseStopAudioPlayer()
    AudioPlayer().Stop()
End Sub
