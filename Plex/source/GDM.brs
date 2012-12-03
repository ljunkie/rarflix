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
