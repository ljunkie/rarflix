' * Responsible for managing the list of media servers used by the application
' *

' * Obtain a list of all configured servers. 
Function PlexMediaServers() As Object
    servers = RegRead("serverList", "servers")
    print "Registry Server list string: ";servers
    list = CreateObject("roList")
    if servers <> invalid
        ' { is an illegal URL character so use a deliminator
        serverTokens = strTokenize(servers, "{")
        for each token in serverTokens
            print "Server token:";token
            ' another illegal char to delim IP and name
            serverDetails = strTokenize(token, "\")
            address = serverDetails[0]
            name = serverDetails[1]
            if serverDetails.Count() > 2 then
                machineID = serverDetails[2]
            else
                machineID = invalid
            end if

            ' The server should have been validated when it was added, so
            ' don't make a blocking validation call here. The home screen
            ' should be able to handle servers that don't respond.
            server = newPlexMediaServer(address, name, machineID)
            server.IsConfigured = true
            list.AddTail(server)
        end for
    end if
    'list.AddTail(newPlexMediaServer("http://dn-1.com:32400", "dn-1"))
    return list
End Function

Function RemoveAllServers()
    RegDelete("serverList", "servers")
    ClearPlexMediaServers()
End Function

Function RemoveServer(index) 
    print "Removing server with index:";index
    servers = RegRead("serverList", "servers")
    RemoveAllServers()
    if servers <> invalid
        serverTokens = strTokenize(servers, "{")
        counter = 0
        for each token in serverTokens
            print "Server token:";token
            serverDetails = strTokenize(token, "\")
            address = serverDetails[0]
            name = serverDetails[1]
            if serverDetails.Count() > 2 then
                machineID = serverDetails[2]
                DeletePlexMediaServer(machineID)
            else
                machineID = invalid
            end if
            if counter <> index then
                AddServer(name, address, machineID)
            else
                print "Not adding server back to list:";name
            end if
            counter = counter + 1
        end for
    end if
End Function

' * Adds a server to the list used by the application. Not validated at this 
' * time which allows off-line servers to be specified. Checking for dupes,
' * usually based on machine ID, should be done by the caller.
Sub AddServer(name, address, machineID)
    print "Adding server to saved list: ";name
    print "With address: ";address
    print "With machine ID: "; machineID

    serverStr = address + "\" + name
    if machineID <> invalid then
        serverStr = serverStr + "\" + machineID
    end if

    existing = RegRead("serverList", "servers")
    if existing <> invalid
        ' The caller checked for dupes, but do a simple sanity check on
        ' machine ID.
        if machineID = invalid OR instr(1, existing, machineID) <= 0 then
            allServers = existing + "{" + serverStr
        else
            return
        end if
    else
        allServers = serverStr
    end if
    RegWrite("serverList", allServers, "servers")
End Sub

Function AddUnnamedServer(address) As Boolean
    print "Adding unnamed server to saved list:";address

    validating = CreateObject("roOneLineDialog")
    validating.SetTitle("Validating Plex Media Servers ...")
    validating.ShowBusyAnimation()
    validating.Show()

    orig = address
    if left(address, 4) <> "http" then
        address = "http://" + address
    end if

    if instr(7, address, ":") <= 0 then
        address = address + ":32400"
    end if

    print "Trying to validate server at "; address

    httpRequest = NewHttp(address)
    response = httpRequest.GetToStringWithTimeout(60)
    xml=CreateObject("roXMLElement")
    if xml.Parse(response) then
        print "Got server response, version "; xml@version

        server = GetPlexMediaServer(xml@machineIdentifier)
        if server <> invalid AND server.IsConfigured then
            print "Duplicate server machine ID, ignoring"
            dialog = createBaseDialog()
            dialog.Facade = validating
            dialog.Title = "Error"
            dialog.Text = "The Plex Media Server at " + orig + " is already configured (" + server.name + ")."
            dialog.Show()
        else if ServerVersionCompare(xml@version, [0, 9, 2, 7]) then
            AddServer(xml@friendlyName, address, xml@machineIdentifier)
            return true
        else
            print "Server version is insufficient"
            dialog = createBaseDialog()
            dialog.Facade = validating
            dialog.Title = "Error"
            dialog.Text = "The Plex Media Server at " + orig + " is running too old a version, please upgrade to the latest release."
            dialog.Show()
        end if
    else
        print "No response from server"
        dialog = createBaseDialog()
        dialog.Facade = validating
        dialog.Title = "Error"
        dialog.Text = "There was no response from " + orig + "."
        dialog.Show()
    end if

    return false
End Function

Function DiscoverPlexMediaServers()
    retrieving = CreateObject("roOneLineDialog")
    retrieving.SetTitle("Finding Plex Media Servers ...")
    retrieving.ShowBusyAnimation()
    retrieving.Show()

    port = CreateObject("roMessagePort")

    gdm = createGDMDiscovery(port)

    if gdm = invalid then
        print "Failed to create GDM Discovery object"
        return 0
    end if

    timeout = 5000
    found = 0

    while true
        msg = wait(timeout, port)
        if msg = invalid then
            print "Canceling GDM discovery after timeout, servers found:"; found
            gdm.Stop()
            exit while
        else if type(msg) = "roSocketEvent" then
            timeout = 2000
            server = gdm.HandleMessage(msg)

            if server <> invalid then
                existing = GetPlexMediaServer(server.MachineID)
                if existing <> invalid AND existing.IsConfigured then
                    print "GDM discovery ignoring already configured server"
                else
                    AddServer(server.Name, server.Url, server.MachineID)
                    found = found + 1
                end if
            end if
        end if
    end while

    retrieving.Close()
    return found
End Function

Function ServerVersionCompare(versionStr, minVersion) As Boolean
    versionStr = strReplace(versionStr,"v","")
    index = instr(1, versionStr, "-")
    tokens = strTokenize(left(versionStr, index-1), ".")
    count = 0
    for each token in tokens
        value = val(token)
        minValue = minVersion[count]
        count = count + 1
        if value < minValue then
            return false
        else if value > minValue then
            return true
        end if
    end for
    return true
End Function

Function createGDMDiscovery(port)
    print "IN GDMFind"

    message = "M-SEARCH * HTTP/1.1"+chr(13)+chr(10)+chr(13)+chr(10) 
    success = false
    try = 0

    while try < 10
        udp = CreateObject("roDatagramSocket")
        udp.setMessagePort(port)
        print "broadcast"
        print udp.setBroadcast(true)
        addr = createobject("roSocketAddress") 
        print addr.SetHostName("239.0.0.250")  
        print addr.setPort(32414)  
        print udp.setSendToAddress(addr) ' peer IP and port 
        udp.notifyReadable(true)
        print udp.sendStr(message) 
        success = udp.eOK()                                                   

        if success then
            exit while
        else
            sleep(500)
            print "retrying"
            try = try + 1
        end if
    end while

    if success then
        gdm = CreateObject("roAssociativeArray")
        gdm.udp = udp
        gdm.HandleMessage = gdmHandleMessage
        gdm.Stop = gdmStop
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

        print "Received message: '"; message; "'"

        x = instr(1,message, "Name: ")
        x = x + 6
        y = instr(x, message, chr(13))
        h_name = Mid(message, x, y-x)
        print h_name

        x = instr(1, message, "Port: ") 
        x = x + 6
        y = instr(x, message, chr(13))
        h_port = Mid(message, x, y-x)
        print h_port

        x = instr(1, message, "Resource-Identifier: ") 
        x = x + 21
        y = instr(x, message, chr(13))
        h_machineID = Mid(message, x, y-x)
        print h_machineID

        server = {Name: h_name,
            Url: "http://" + h_address + ":" + h_port,
            MachineID: h_machineID}
        return server
    end if

    return invalid
End Function

Sub gdmStop()
    m.udp.Close()
End Sub

Function GetPlexMediaServer(machineID)
    servers = GetGlobalAA().Lookup("validated_servers")
    if servers <> invalid then
        return servers[machineID]
    else
        return invalid
    end if
End Function

Sub PutPlexMediaServer(server)
    if server.machineID <> invalid then
        servers = GetGlobalAA().Lookup("validated_servers")
        if servers = invalid then
            servers = {}
            GetGlobalAA().AddReplace("validated_servers", servers)
        end if
        servers[server.machineID] = server
    end if
End Sub

Function AreMultipleValidatedServers() As Boolean
    ' Super lame...
    servers = GetGlobalAA().Lookup("validated_servers")
    if servers <> invalid then
        servers.Reset()
        servers.Next()
        return servers.IsNext()
    else
        return false
    end if
End Function

Sub DeletePlexMediaServer(machineID)
    servers = GetGlobalAA().Lookup("validated_servers")
    if servers <> invalid then
        servers.Delete(machineID)
    end if
End Sub

Sub ClearPlexMediaServers()
    GetGlobalAA().Delete("validated_servers")
End Sub

Function GetOwnedPlexMediaServers()
    owned = []
    servers = GetGlobalAA().Lookup("validated_servers")

    if servers <> invalid then
        for each id in servers
            server = servers[id]
            if server.owned then
                owned.Push(server)
            end if
        next
    end if

    return owned
End Function

Function GetPrimaryServer()
    ' TODO(schuyler): Actually define a primary server instead of using an arbitrary one
    owned = GetOwnedPlexMediaServers()
    if owned.Count() > 0 then
        print "Setting primary server to "; owned[0].name
        return owned[0]
    end if

    return invalid
End Function

