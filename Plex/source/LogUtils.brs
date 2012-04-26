
Sub Debug(msg as String, server=invalid)
    print msg

    if server <> invalid then
        server.Log(msg)
    end if

    if m.Logger = invalid then
        m.Logger = createLogger()
    end if

    m.Logger.Log(msg)
End Sub

Function createLogger() As Object
    logger = CreateObject("roAssociativeArray")
    logger.Enabled = (RegRead("debugenabled", invalid, "0") = "1")
    logger.DebugBuffer = box("")
    logger.DebugFileNum = 0
    logger.DebugFiles = CreateObject("roList")

    logger.Log = loggerLog
    logger.Enable = loggerEnable
    logger.Disable = loggerDisable

    GetGlobalAA().AddReplace("logger", logger)

    return logger
End Function

Sub loggerLog(msg)
    if NOT m.Enabled then return

    ' It's tempting to keep debug messages in an roList, but there's no
    ' way to write to a temp file one line at a time, so we're going to
    ' end up combining into a single massive string, might as well do
    ' that now.

    m.DebugBuffer.AppendString(msg, Len(msg))
    m.DebugBuffer.AppendString(Chr(10), 1)

    ' Don't fill up memory or the tmp filesystem. Unfortunately, there
    ' doesn't ' seem to be a way to figure out how much space is
    ' available, so this is totally arbitrary.

    if m.DebugBuffer.Len() > 8192 then
        filename = "tmp:/debug_log" + tostr(m.DebugFileNum)
        WriteAsciiFile(filename, m.DebugBuffer)
        m.DebugFiles.AddTail(filename)
        m.DebugFileNum = m.DebugFileNum + 1
        m.DebugBuffer = box("")

        if m.DebugFiles.Count() > 10 then
            filename = m.DebugFiles.RemoveHead()
            DeleteFile(filename)
        end if
    end if
End Sub

Sub loggerEnable()
    m.Enabled = true
    RegWrite("debugenabled", "1")
    m.DebugBuffer = box("")
    m.DebugFileNum = 0
    m.DebugFiles = CreateObject("roList")
End Sub

Sub loggerDisable()
    m.Enabled = false
    RegWrite("debugenabled", "0")
    m.DebugBuffer = box("")
    m.DebugFileNum = 0

    for each file in m.DebugFiles
        DeleteFile(file)
    next
    m.DebugFiles.Clear()
End Sub

