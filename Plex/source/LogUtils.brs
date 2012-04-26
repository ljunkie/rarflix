
Sub Debug(msg as String, server=invalid, level=3 As Integer, timeout=0 As Integer)
    print msg

    if server <> invalid then
        server.Log(msg, level, timeout)
    end if
End Sub
