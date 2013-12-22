'*
'* Objects and functions related to GDM.
'*

'*** GDM Discovery ***

Function createGDMDiscovery(port, listener=invalid)
    Debug("IN GDMFind")

    message = "M-SEARCH * HTTP/1.1"+chr(13)+chr(10)+chr(13)+chr(10)
    success = false
    try = 0

    ' Broadcasting to 255.255.255.255 only works on some Rokus, but we
    ' can't reliably determine the broadcast address for our current
    ' interface. Try assuming a /24 network, and then fall back to the
    ' multicast address if that doesn't work.

    multicast = "239.0.0.250"
    ip = multicast
    subnetRegex = CreateObject("roRegex", "((\d+)\.(\d+)\.(\d+)\.)(\d+)", "")
    addr = GetFirstIPAddress()
    if addr <> invalid then
        match = subnetRegex.Match(addr)
        if match.Count() > 0 then
            ip = match[1] + "255"
            Debug("Using broadcast address " + ip)
        end if
    end if

    while try < 10
        udp = CreateObject("roDatagramSocket")
        udp.setMessagePort(port)
        Debug("broadcast")
        Debug(tostr(udp.setBroadcast(true)))

        ' Make sure the send to address actually takes. It doesn't always,
        ' and that seems to be a big part of our discovery problem.
        for i = 0 to 5
            addr = CreateObject("roSocketAddress")
            addr.setHostName(ip)
            addr.setPort(32414)
            udp.setSendToAddress(addr)

            sendTo = udp.getSendToAddress()
            if sendTo <> invalid then
                sendToStr = tostr(sendTo.getAddress())
                addrStr = tostr(addr.getAddress())
                Debug("GDM sendto address: " + sendToStr + " / " + addrStr)
                if sendToStr = addrStr then
                    exit for
                end if
            end if

            Debug("Failed to set GDM sendto address")
        next

        udp.notifyReadable(true)
        bytesSent = udp.sendStr(message)
        Debug("Sent " + tostr(bytesSent) + " bytes")
        if bytesSent > 0 then
            success = udp.eOK()
        else
            success = false
            if bytesSent = 0 then
                Debug("Falling back to multicast address")
                ip = multicast
                try = 0
            end if
        end if

        if success then
            exit while
        else if try = 9 AND ip <> multicast then
            Debug("Falling back to multicast address")
            ip = multicast
            try = 0
        else
            sleep(500)
            Debug("retrying, errno " + tostr(udp.status()))
            try = try + 1
        end if
    end while

    if success then
        gdm = CreateObject("roAssociativeArray")
        gdm.udp = udp
        gdm.HandleMessage = gdmHandleMessage
        gdm.Stop = gdmStop
        if listener <> invalid then
            gdm.Listener = listener
            gdm.OnSocketEvent = gdmOnSocketEvent
            GetViewController().AddSocketListener(udp, gdm)
        end if
        return gdm
    else
        return invalid
    end if
End Function

Function gdmHandleMessage(msg)
    if type(msg) = "roSocketEvent" AND msg.getSocketID() = m.udp.getID() AND m.udp.isReadable() then
        message = m.udp.receiveStr(4096) ' max 4096 characters
        caddr = m.udp.getReceivedFromAddress()
        h_address = caddr.getHostName()

        Debug("Received message: '" + tostr(message) + "'")

        x = instr(1,message, "Name: ")
        if x <= 0 then
            return invalid
        end if
        x = x + 6
        y = instr(x, message, chr(13))
        h_name = Mid(message, x, y-x)
        Debug(h_name)

        x = instr(1, message, "Port: ")
        x = x + 6
        y = instr(x, message, chr(13))
        h_port = Mid(message, x, y-x)
        Debug(h_port)

        x = instr(1, message, "Resource-Identifier: ")
        x = x + 21
        y = instr(x, message, chr(13))
        h_machineID = Mid(message, x, y-x)
        Debug(h_machineID)

        server = {Name: h_name,
            Url: "http://" + h_address + ":" + h_port,
            MachineID: h_machineID}
        return server
    end if

    return invalid
End Function

Sub gdmOnSocketEvent(msg)
    serverInfo = m.HandleMessage(msg)
    if serverInfo <> invalid then
        m.Listener.OnServerDiscovered(serverInfo)
    end if
End Sub

Sub gdmStop()
    m.udp.Close()
End Sub

'*** GDM Player Advertiser ***

Function GDMAdvertiser()
    if m.GDMAdvertiser = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.OnSocketEvent = gdmAdvertiserOnSocketEvent

        obj.responseString = invalid
        obj.GetResponseString = gdmAdvertiserGetResponseString

        obj.CreateSocket = gdmAdvertiserCreateSocket
        obj.Close = gdmAdvertiserClose
        obj.Refresh = gdmAdvertiserRefresh
        obj.Cleanup = gdmAdvertiserCleanup

        obj.Refresh()

        ' Singleton
        m.GDMAdvertiser = obj
    end if

    return m.GDMAdvertiser
End Function

Sub gdmAdvertiserCreateSocket()
    listenAddr = CreateObject("roSocketAddress")
    listenAddr.setPort(32412)
    listenAddr.setAddress("0.0.0.0")

    udp = CreateObject("roDatagramSocket")

    if not udp.setAddress(listenAddr) then
        Debug("Failed to set address on GDM advertiser socket")
        return
    end if

    ' Try with the correct address and then with the reversed address
    addresses = ["239.0.0.250", "239.0.0.250", "250.0.0.239", "250.0.0.239"]
    success = false
    for each addr in addresses
        groupAddr = CreateObject("roSocketAddress")
        groupAddr.setHostName(addr)
        groupAddr.setPort(32412)

        if udp.joinGroup(groupAddr) then
            Debug("Successfully joined multicast group: " + addr)
            success = true
            exit for
        end if
    next

    if not success then
        Debug("Failed to join multicast group on GDM advertiser socket")
        return
    end if

    udp.setMulticastLoop(false)
    udp.notifyReadable(true)
    udp.setMessagePort(GetViewController().GlobalMessagePort)

    m.socket = udp

    GetViewController().AddSocketListener(udp, m)

    Debug("Created GDM player advertiser")
End Sub

Sub gdmAdvertiserClose()
    if m.socket <> invalid then
        m.socket.Close()
        m.socket = invalid
    end if
End Sub

Sub gdmAdvertiserRefresh()
    ' Always regenerate our response, even if it might not have changed, it's
    ' just not that expensive.
    m.responseString = invalid

    enabled = (RegRead("remotecontrol", "preferences", "1") = "1")
    if enabled AND m.socket = invalid then
        m.CreateSocket()
    else if not enabled AND m.socket <> invalid then
        m.Close()
    end if
End Sub

Sub gdmAdvertiserCleanup()
    m.Close()
    fn = function() :m.GDMAdvertiser = invalid :end function
    fn()
End Sub

Sub gdmAdvertiserOnSocketEvent(msg)
    ' PMS polls every five seconds, so this is chatty when not debugging.
    'Debug("Got a GDM advertiser socket event, is readable: " + tostr(m.socket.isReadable()))

    if m.socket.isReadable() then
        message = m.socket.receiveStr(4096)
        endIndex = instr(1, message, chr(13)) - 1
        if endIndex <= 0 then endIndex = message.Len()
        line = Mid(message, 1, endIndex)

        if line = "M-SEARCH * HTTP/1.1" then
            response = m.GetResponseString()

            ' Respond directly to whoever sent the search message.
            sock = CreateObject("roDatagramSocket")
            sock.setSendToAddress(m.socket.getReceivedFromAddress())
            bytesSent = sock.sendStr(response)
            sock.Close()
            if bytesSent <> Len(response) then
                Debug("GDM player response only sent " + tostr(bytesSent) + " bytes out of " + tostr(Len(response)))
            end if
        else
            Debug("Received unexpected message on GDM advertiser socket: " + tostr(line) + ";")
        end if
    end if
End Sub

Function gdmAdvertiserGetResponseString() As String
    if m.responseString = invalid then
        buf = box("HELLO * HTTP/1.0" + Chr(10))

        appendNameValue(buf, "Name", RegRead("player_name", "preferences", GetGlobalAA().Lookup("rokuModel")))
        appendNameValue(buf, "Port", GetViewController().WebServer.port.tostr())
        appendNameValue(buf, "Product", "Plex for Roku")
        appendNameValue(buf, "Content-Type", "plex/media-player")
        appendNameValue(buf, "Protocol", "plex")
        appendNameValue(buf, "Protocol-Version", "1")
        appendNameValue(buf, "Protocol-Capabilities", "timeline,playback,navigation")
        appendNameValue(buf, "Version", GetGlobalAA().Lookup("appVersionStr"))
        appendNameValue(buf, "Resource-Identifier", GetGlobalAA().Lookup("rokuUniqueID"))
        appendNameValue(buf, "Device-Class", "stb")

        m.responseString = buf

        Debug("Built GDM player response:" + m.responseString)
    end if

    return m.responseString
End Function

Sub appendNameValue(buf, name, value)
    line = name + ": " + value + Chr(10)
    buf.AppendString(line, Len(line))
End Sub
