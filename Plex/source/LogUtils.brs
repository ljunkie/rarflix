
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
    logger.Flush = loggerFlush

    GetGlobalAA().AddReplace("logger", logger)

    ' TODO(schuyler): Especially if we ever want a web server for something
    ' else (remote API?), it makes more sense to do this elsewhere. It would
    ' also be nice if it were always running, but that requires a global
    ' message port.

    ' Initialize some globals for the web server
    globals = CreateObject("roAssociativeArray")
    globals.pkgname = "Plex Debug"
    globals.maxRequestLength = 4000
    globals.idletime = 60
    globals.wwwroot = "tmp:/"
    globals.index_name = "index.html"
    globals.serverName = "Plex Debug"
    AddGlobals(globals)
    MimeType()
    HttpTitle()
    ClassReply().AddHandler("/logs", ProcessLogsRequest)

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
        m.Flush()
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

Sub loggerFlush()
    filename = "tmp:/debug_log" + tostr(m.DebugFileNum) + ".txt"
    WriteAsciiFile(filename, m.DebugBuffer)
    m.DebugFiles.AddTail(filename)
    m.DebugFileNum = m.DebugFileNum + 1
    m.DebugBuffer = box("")

    if m.DebugFiles.Count() > 10 then
        filename = m.DebugFiles.RemoveHead()
        DeleteFile(filename)
    end if
End Sub

Function createLogDownloadScreen(viewController) As Object
    obj = CreateObject("roAssociativeArray")
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")

    screen.SetMessagePort(port)

    ' Standard properties for all our Screen types
    obj.Item = invalid
    obj.Screen = screen
    obj.Port = port
    obj.ViewController = viewController
    obj.MessageHandler = invalid
    obj.MsgTimeout = 5000

    obj.Show = showLogDownloadScreen

    obj.Server = InitServer({msgPort: port, port: 8324})

    viewController.InitializeOtherScreen(obj, ["Logging"])

    return obj
End Function

Sub showLogDownloadScreen()
    ' If we ask the server's socket what address it's listening on, it'll
    ' tell us 0.0.0.0, so just grab the first IP from the device info.
    ip = GetFirstIPAddress()

    m.Screen.AddHeaderText("Download Logs")
    m.Screen.AddParagraph("To download logs, on your computer, visit:")
    m.Screen.AddParagraph(" ")
    m.Screen.AddParagraph("http://" + ip + ":" + tostr(m.Server.port) + "/logs")
    m.Screen.AddButton(1, "done")

    m.Screen.Show()

    while true
        m.Server.prewait()
        msg = wait(m.MsgTimeout, m.Port)
        if m.MessageHandler <> invalid AND m.MessageHandler.HandleMessage(msg) then
        else if type(msg) = "roParagraphScreenEvent" then
            if msg.isScreenClosed() then
                m.ViewController.PopScreen(m)
                exit while
            else if msg.isButtonPressed() then
                m.Screen.Close()
            end if
        else if type(msg) = "roSocketEvent" OR msg = invalid then
            m.Server.postwait()
        end if
    end while

    m.Server.close()
End Sub

Function ProcessLogsRequest() As Boolean
    logger = GetGlobalAA()["logger"]
    logger.Flush()

    fs = CreateObject("roFilesystem")
    m.files = CreateObject("roList")
    totalLen = 0
    for each path in logger.DebugFiles
        stat = fs.stat(path)
        if stat <> invalid then
            m.files.AddTail({path: path, length: stat.size})
            totalLen = totalLen + stat.size
        end if
    next

    m.mimetype = "text/plain"
    m.fileLength = totalLen
    m.source = m.CONCATFILES
    m.lastmod = Now()

    ' Not handling range requests...
    m.start = 0
    m.length = m.fileLength
    m.http_code = 200

    m.genHdr()
    return true
End Function

