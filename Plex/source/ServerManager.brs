' * Responsible for managing the list of media servers used by the application
' *

Function ParseRegistryServerList() As Object
    list = []
    servers = RegRead("serverList", "servers")
    Debug("Registry Server list string: " + tostr(servers))

    ' strTokenize has an interesting quirk where empty strings aren't
    ' returned. That's nice when separating the servers, but if a server
    ' doesn't have a name we don't want the machine ID to become the name.
    ' So tokenize first, but use a regex for the second split.
    re = CreateObject("roRegex", "\\", "")

    if servers <> invalid
        ' { is an illegal URL character so use a deliminator
        serverTokens = strTokenize(servers, "{")
        for each token in serverTokens
            Debug("Server token: " + token)
            serverDetails = re.split(token)
            serverInfo = {}
            serverInfo.Url = serverDetails[0]

            ' This should absolutely never happen, so treat it as exceptional
            ' and wipe the slate clean.
            if serverInfo.Url = invalid OR len(serverInfo.Url) = 0 then
                Debug("Bogus server string in registry, removing all servers")
                RemoveAllServers()
                return []
            end if

            ' Make sure the name is always a string.
            serverInfo.Name = firstOf(serverDetails[1], "")

            ' If the machine ID isn't specified, make sure it's invalid
            if serverDetails[2] <> "" then
                serverInfo.MachineID = serverDetails[2]
            else
                serverInfo.MachineID = invalid
            end if

            serverInfo.ToString = function(): return m.Url + "\" + m.Name + "\" + firstOf(m.MachineID, "") :end function

            list.Push(serverInfo)
        next
    end if

    return list
End Function

' * Obtain a list of all configured servers.
Function PlexMediaServers() As Object
    infoList = ParseRegistryServerList()
    list = CreateObject("roList")

    for each serverInfo in infoList
        ' The server should have been validated when it was added, so
        ' don't make a blocking validation call here. The home screen
        ' should be able to handle servers that don't respond.
        server = newPlexMediaServer(serverInfo.Url, serverInfo.Name, serverInfo.MachineID)
        server.IsConfigured = true
        server.local = true
        list.AddTail(server)
    next

    return list
End Function

Function RemoveAllServers()
    RegDelete("serverList", "servers")
End Function

Function RemoveServer(index)
    Debug("Removing server with index: " + tostr(index))
    servers = ParseRegistryServerList()
    RemoveAllServers()
    counter = 0
    for each serverInfo in servers
        if counter <> index then
            AddServer(serverInfo.Name, serverInfo.Url, serverInfo.MachineID)
        else
            Debug("Not adding server back to list: " + serverInfo.Name)
            DeletePlexMediaServer(serverInfo.MachineID)
        end if
        counter = counter + 1
    end for
End Function

' * Adds a server to the list used by the application. Not validated at this
' * time which allows off-line servers to be specified. Checking for dupes,
' * usually based on machine ID, should be done by the caller.
Sub AddServer(name, address, machineID)
    Debug("Adding server to saved list: " + tostr(name))
    Debug("With address: " + tostr(address))
    Debug("With machine ID: " + tostr(machineID))

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

Sub UpdateServerAddress(server)
    infoList = ParseRegistryServerList()
    newServerStr = ""
    delim = ""
    updated = false
    for each serverInfo in infoList
        if serverInfo.MachineID = server.MachineID then
            serverInfo.Name = server.Name
            serverInfo.Url = server.ServerUrl
            updated = true
        end if
        newServerStr = newServerStr + delim + serverInfo.ToString()
        delim = "{"
    next

    if updated then
        RegWrite("serverList", newServerStr, "servers")
    else
        AddServer(server.Name, server.ServerUrl, server.MachineID)
    end if
End Sub

Function AddUnnamedServer(address) As Boolean
    Debug("Adding unnamed server to saved list: " + address)

    validating = CreateObject("roOneLineDialog")
    validating.SetTitle("Validating Plex Media Servers ...")
    validating.ShowBusyAnimation()
    validating.Show()

    ' See if the user misunderstood and entered the Roku's IP or the public IP.
    subnetRegex = CreateObject("roRegex", "((\d+)\.(\d+)\.(\d+)\.)(\d+)", "")
    rokuSubnet = ""
    enteredSubnet = ""
    subnetMatch = false

    match = subnetRegex.Match(address)
    if match.Count() > 0 then
        enteredSubnet = match[1]
    else
        ' Must have entered a hostname, pretend like the subnet matched
        subnetMatch = true
    end if

    device = CreateObject("roDeviceInfo")
    addrs = device.GetIPAddrs()
    for each iface in addrs
        ip = addrs[iface]
        Debug("Roku IP: " + ip)
        if ip = address then
            dialog = createBaseDialog()
            dialog.Facade = validating
            dialog.Title = "Error"
            dialog.Text = address + " is the IP address of the Roku, enter the IP address of the Plex Media Server."
            dialog.Show(true)
            return false
        end if

        match = subnetRegex.Match(ip)
        if match.Count() > 0 then
            rokuSubnet = match[1]
            if rokuSubnet = enteredSubnet then
                subnetMatch = true
            end if
        end if
    next

    orig = address
    if left(address, 4) <> "http" then
        address = "http://" + address
    end if

    if instr(7, address, ":") <= 0 then
        address = address + ":32400"
    end if

    Debug("Trying to validate server at " + address)

    httpRequest = NewHttp(address)
    response = httpRequest.GetToStringWithTimeout(60)
    Debug("Validate server response: " + tostr(httpRequest.ResponseCode))
    xml=CreateObject("roXMLElement")
    if xml.Parse(response) then
        Debug("Got server response, version " + tostr(xml@version))

        server = GetPlexMediaServer(xml@machineIdentifier)
        if server <> invalid AND server.ServerUrl <> address then
            Debug("Updating URL for machine ID, new URL: " + address)
            server.ServerUrl = address
            server.Name = firstOf(xml@friendlyName, "Unknown")
            server.owned = true
            server.local = true
            server.IsConfigured = true
            server.IsAvailable = true
            server.IsUpdated = true
            UpdateServerAddress(server)
            return true
        else if server <> invalid then
            Debug("Duplicate server machine ID, ignoring")
            dialog = createBaseDialog()
            dialog.Facade = validating
            dialog.Title = "Error"
            dialog.Text = "The Plex Media Server at " + orig + " is already configured (" + server.name + ")."
            dialog.Show(true)
        else if ServerVersionCompare(xml@version, [0, 9, 2, 7]) then
            AddServer(xml@friendlyName, address, xml@machineIdentifier)
            return true
        else if xml@serverClass = "secondary" then
            ' There's not a lot to go on here, but assume it's ok.
            AddServer(xml@friendlyName, address, xml@machineIdentifier)
            return true
        else
            Debug("Server version is insufficient")
            dialog = createBaseDialog()
            dialog.Facade = validating
            dialog.Title = "Error"
            dialog.Text = "The Plex Media Server at " + orig + " is running too old a version, please upgrade to the latest release."
            dialog.Show(true)
        end if
    else
        Debug("No response from server")
        dialog = createBaseDialog()
        dialog.Facade = validating
        dialog.Title = "Error"
        dialog.Text = "There was no response from " + orig + "."

        if NOT subnetMatch then
            Debug("Subnet of entered address didn't match Roku address")
            dialog.Text = dialog.Text + " Make sure you're entering the local IP address of your Plex Media Server (" + rokuSubnet + "X)."
        end if

        dialog.Text = dialog.Text + String(2, Chr(10)) + "Error: " + tostr(httpRequest.FailureReason)

        dialog.Show(true)
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
        Debug("Failed to create GDM Discovery object")
        return 0
    end if

    timeout = 10000
    found = 0

    while true
        msg = wait(timeout, port)
        if msg = invalid then
            Debug("Canceling GDM discovery after timeout, servers found: " + tostr(found))
            gdm.Stop()
            exit while
        else if type(msg) = "roSocketEvent" then
            server = gdm.HandleMessage(msg)

            if server <> invalid then
                timeout = 2000
                existing = GetPlexMediaServer(server.MachineID)
                if existing <> invalid AND existing.ServerUrl <> server.Url then
                    Debug("Found new address for " + server.Name + ": " + existing.ServerUrl + " -> " + server.Url)
                    existing.ServerUrl = server.Url
                    existing.Name = server.Name
                    existing.owned = true
                    existing.local = true
                    existing.IsConfigured = true
                    existing.IsAvailable = true
                    existing.IsUpdated = true
                    UpdateServerAddress(existing)
                    found = found + 1
                else if existing <> invalid then
                    Debug("GDM discovery ignoring already configured server")
                else
                    AddServer(server.Name, server.Url, server.MachineID)
                    pms = newPlexMediaServer(server.Url, server.Name, server.MachineID)
                    pms.owned = true
                    pms.local = true
                    pms.IsConfigured = true
                    PutPlexMediaServer(pms)
                    found = found + 1
                end if
            end if
        end if
    end while

    retrieving.Close()
    return found
End Function

Function ServerVersionCompare(versionStr, minVersion) As Boolean
    if versionStr = invalid then return false
    versionStr = strReplace(versionStr,"v","")
    index = instr(1, versionStr, "-")
    if index > 0 then
        versionStr = left(versionStr, index - 1)
    end if
    tokens = strTokenize(versionStr, ".")
    count = 0
    for each token in tokens
        if count >= minVersion.count() then exit for
        value = int(val(token))
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

Function GetFirstIPAddress()
    device = CreateObject("roDeviceInfo")
    addrs = device.GetIPAddrs()
    addrs.Reset()
    if addrs.IsNext() then
        return addrs[addrs.Next()]
    else
        return invalid
    end if
End Function

Function GetPlexMediaServer(machineID)
    if machineID = invalid then return invalid
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
        if server.serverUrl <> invalid then SetServerForHost(server.serverUrl + "/", server)
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
    if servers <> invalid AND machineID <> invalid then
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
    if m.PrimaryServer <> invalid then return m.PrimaryServer

    m.PrimaryServer = invalid

    ' TODO(schuyler): Actually define a primary server instead of using an arbitrary one
    for each server in GetOwnedPlexMediaServers()
        if server.owned AND server.online AND NOT server.IsSecondary then
            if m.PrimaryServer = invalid OR server.machineID = RegRead("primaryServerID", "preferences", "") then
                Debug("Setting primary server to " + server.name)
                m.PrimaryServer = server
            end if
        end if
    next

    return m.PrimaryServer
End Function

Sub SetServerForHost(hostname, server)
    servers = GetGlobalAA().Lookup("servers_by_host")
    if servers = invalid then
        servers = {}
        GetGlobalAA().AddReplace("servers_by_host", servers)
        servers["https://my.plexapp.com/"] = MyPlexManager()
        servers["https://my.plexapp.com:443/"] = MyPlexManager()
        servers["http://node.plexapp.com:32400/"] = invalid
    end if

    servers[hostname] = server
End Sub

Function GetServerForUrl(url)
    servers = GetGlobalAA().Lookup("servers_by_host")
    if servers = invalid then
        servers = {}
        GetGlobalAA().AddReplace("servers_by_host", servers)
        servers["https://my.plexapp.com/"] = MyPlexManager()
        servers["https://my.plexapp.com:443/"] = MyPlexManager()
        servers["http://node.plexapp.com:32400/"] = invalid
    end if

    index = instr(10, url, "/")
    if index <= 0 then return invalid
    hostname = Left(url, index)

    if servers.DoesExist(hostname) then
        return servers[hostname]
    end if

    Debug("Looking up identity for " + tostr(hostname))

    httpRequest = NewHttp(hostname + "identity")
    response = httpRequest.GetToStringWithTimeout(60)
    xml=CreateObject("roXMLElement")
    if xml.Parse(response) then
        server = GetPlexMediaServer(xml@machineIdentifier)
        if server <> invalid then
            SetServerForHost(hostname, server)
            return server
        end if
    end if

    return invalid
End Function
