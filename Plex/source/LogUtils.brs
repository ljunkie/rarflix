
Sub Debug(msg as String, server=invalid)

    if m.Logger = invalid then m.Logger = createLogger()

    ' override logging setting if this is the DEV channel
    ' otherwise one will have to enable logging to see the logs
    if type(isRFdev) = "roFunction" and NOT isRFdev() then m.Logger.isDev = false
    m.Logger.isDev = false ' force logger off for this DEV - we are releasing it public

    ' hopefully save some CPU cycles
    if m.logger.isDev or m.logger.Enabled then 
        logDate = getLogDate()
        print logDate + " : " + msg
        if server <> invalid then server.Log(msg) 'remote logging
        m.Logger.Log(logDate + " : " + msg) ' log file for download
    end if
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
    logger.isDev = true ' start a true. We will always log startup.

    logger.EnablePapertrail = loggerEnablePapertrail
    logger.LogToPapertrail = loggerLogToPapertrail

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
        m.Flush()
    end if

    ' Check on papertrail logging. If it's enabled, we need to make sure
    ' time hasn't elapsed yet, and then log the message.

    if m.RemoteLoggingTimer <> invalid then
        if m.RemoteLoggingTimer.TotalSeconds() > m.RemoteLoggingSeconds then
            m.SyslogSocket.Close()
            m.SyslogSocket = invalid
            m.SyslogPackets = invalid
            m.RemoteLoggingTimer = invalid
        else
            m.LogToPapertrail(msg)
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
    header = "Download Logs"
    paragraphs = []

    ' If we ask the server's socket what address it's listening on, it'll
    ' tell us 0.0.0.0, so just grab the first IP from the device info.
    ip = GetFirstIPAddress()

    paragraphs.Push("To download logs, on your computer, visit:")
    paragraphs.Push(" ")
    paragraphs.Push("http://" + ip + ":" + tostr(viewController.WebServer.port) + "/logs")

    screen = createParagraphScreen(header, paragraphs, viewController)
    viewController.InitializeOtherScreen(screen, ["Logging"])

    return screen
End Function

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

Sub loggerEnablePapertrail(minutes=20, pms=invalid)
    myPlex = GetGlobalAA().Lookup("myplex")
    aa = GetGlobalAA()
    if myPlex = invalid OR NOT myPlex.IsSignedIn then return

    ' Create the remote syslog socket

    port = CreateObject("roMessagePort")
    addr = CreateObject("roSocketAddress")
    udp = CreateObject("roDatagramSocket")

    ' We're never going to wait on this message port, but we still need to
    ' set it to make the socket async.
    udp.setMessagePort(port)

    addr.setHostname("logs.papertrailapp.com")
    addr.setPort(26634)
    udp.setSendToAddress(addr)

    m.SyslogSocket = udp
    m.SyslogPackets = CreateObject("roList")

    m.RemoteLoggingSeconds = minutes * 60
    m.RemoteLoggingTimer = CreateObject("roTimespan")

    ' We always need to send a myPlex username, so cache the username now. If
    ' the user happens to disconnect the myPlex account while remote logging is
    ' enabled, the logs will continue to be associated with the original
    ' account.

    tag = aa.appName + "_" + aa.appVersionStr + "_" + aa.rokuUniqueID

    m.SyslogHeader = "<135> " + tag + ": [" + myPlex.Username + "] "

    ' Enable papertrail logging for the PMS, too.
    if pms <> invalid then
        pms.ExecuteCommand("/log/networked?minutes=" + tostr(minutes))
    end if
End Sub

Sub loggerLogToPapertrail(msg)
    ' Just about the simplest syslog packet possible without being empty.
    ' We're using the local0 facility and logging everything as debug, so
    ' <135>. We simply skip the timestamp and hostname, the receiving
    ' timestamp will be used and is good enough to avoid writing strftime
    ' in brightscript. Then we hardcode PlexForRoku as the TAG field and
    ' include the myPlex username in the CONTENT. Finally, we make sure
    ' the whole thing isn't too long.

    bytesLeft = 1024 - Len(m.SyslogHeader)
    if bytesLeft > Len(msg) then
        packet = m.SyslogHeader + msg
    else
        packet = m.SyslogHeader + Left(msg, bytesLeft)
    end if

    m.SyslogPackets.AddTail(packet)

    ' If we have anything backed up, try to send it now.
    while m.SyslogSocket.isWritable() AND m.SyslogPackets.Count() > 0
        m.SyslogSocket.sendStr(m.SyslogPackets.RemoveHead())
    end while
End Sub

