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
            ' The server should have been validated when it was added, so
            ' don't make a blocking validation call here. The home screen
            ' should be able to handle servers that don't respond.
            list.AddTail(newPlexMediaServer(address, name))
        end for
    end if
    'list.AddTail(newPlexMediaServer("http://dn-1.com:32400", "dn-1"))
    return list
End Function

Function RemoveAllServers()
    RegDelete("serverList", "servers")
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
            if counter <> index then
                AddServer(name, address)
            else
                print "Not adding server back to list:";name
            end if
            counter = counter + 1
        end for
    end if
End Function

' * Adds a server to the list used by the application. Not validated at this 
' * time which allows off-line servers to be specified.
' 
' * TODO: Check for duplicates?
Function AddServer(name, address)
    print "Adding server to saved list:";name
    print "With address:";address
    existing = RegRead("serverList", "servers")
    if existing <> invalid
        dupe = 0
        for each server in PlexMediaServers()
            print "Checking existing server "+server.name + " for duplicates... ("+server.serverUrl+")"
            if name = server.name then
                dupe = 1
            endif
            if address = server.serverUrl then
                dupe = 1
            endif
        next
        if dupe = 0 then
            print "No dupes found, adding server..."
            allServers = existing + "{" + address+"\"+name
        else
            print "Dupe found, not adding server..."
            allServers = existing
        endif
    else
        allServers = address+"\"+name
    end if
    RegWrite("serverList", allServers, "servers")
End Function

Function AddUnnamedServer(address) As Boolean
    print "Adding unnamed server to saved list:";address

    validating = CreateObject("roOneLineDialog")
    validating.SetTitle("Validating Plex Media Servers ...")
    validating.ShowBusyAnimation()
    validating.Show()

    strReplace(address, "http://", "")
    strReplace(address, ":32400", "")
    sock = CreateObject("roSocketAddress")
    sock.setAddress(address+":32400")
    ipaddr = sock.getAddress()
    hostname = sock.getHostName()

    print "Host:"+hostname", IP Address:"+ipaddr

    if (IsServerValid("http://"+ipaddr)) then
        AddServer(address, "http://"+ipaddr)
        return true
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
            server = gdm.HandleMessage(msg)
            if server <> invalid then
                AddServer(server.Name, server.Url)
                found = found + 1
            end if
            timeout = 2000
        end if
    end while

    retrieving.Close()
    return found
End Function

Function IsServerValid(address) As Boolean
    print "Validating server ";address
    
    Dim minVersion[4]
    minVersion.Push(0)
    minVersion.Push(9)
    minVersion.Push(2)
    minVersion.Push(7)
    httpRequest = NewHttp(address)
    response = httpRequest.GetToStringWithTimeout(60000)
    xml=CreateObject("roXMLElement")
    if xml.Parse(response) then
        versionStr = xml@version
        print "Version str:";versionStr
        versionHighEnough = ServerVersionCompare(versionStr, minVersion)
        return versionHighEnough
    end if
    return false
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

        server = {Name: h_name, Url: "http://" + h_address + ":" + h_port}
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

Sub ClearPlexMediaServers()
    GetGlobalAA().Delete("validated_servers")
End Sub

