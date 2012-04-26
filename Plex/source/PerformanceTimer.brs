REM ********************************************************************** 
REM Performance Timer
REM
REM A simple object that can be used to print debug information about how
REM long operations take to complete. Really, just a very simple wrapper
REM around an roTimespan.
REM ********************************************************************** 

Function createPerformanceTimer() As Object
    timer = CreateObject("roAssociativeArray")
    timer.timer = CreateObject("roTimespan")
    timer.PrintElapsedTime = timerPrintElapsedTime
    timer.GetElapsedMillis = timerGetElapsedMillis
    timer.Mark = timerMark
    timer.timer.Mark()
    return timer
End Function

Function timerPrintElapsedTime(msg As String, mark=True As Boolean)
    Debug(msg + " took: " + itostr(m.timer.TotalMilliseconds()) + "ms")
    if mark then m.timer.Mark()
End Function

Function timerGetElapsedMillis() As Integer
    return m.timer.TotalMilliseconds()
End Function

Function timerMark()
    m.timer.Mark()
End Function

