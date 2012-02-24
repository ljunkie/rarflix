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
            if IsServerValid(address) then
                list.AddTail(newPlexMediaServer(address, name))
            end if
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

Function AddUnnamedServer(address)
    print "Adding unnamed server to saved list:";address
    strReplace(address, "http://", "")
    strReplace(address, ":32400", "")
    sock = CreateObject("roSocketAddress")
    sock.setAddress(address+":32400")
    ipaddr = sock.getAddress()
    print "Host:"+address", IP Address:"+ipaddr
    AddServer(address, "http://"+ipaddr)
End Function

Function DiscoverPlexMediaServers()
    retrieving = CreateObject("roOneLineDialog")
    retrieving.SetTitle("Finding Plex Media Servers ...")
    retrieving.ShowBusyAnimation()
    retrieving.Show()
    found = GDMDiscover()
    for each server in found
        AddServer(server[0], server[1])
    end for
    retrieving.Close()
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

Function GDMDiscover()
    print "IN GDMFind"
    msgPort = createobject("roMessagePort")  
    timeout = 1 * 5 * 1000 ' 2 seconds in milliseconds 
    message = "M-SEARCH * HTTP/1.1"+chr(13)+chr(10)+chr(13)+chr(10) 

    continue = false
    count = 0 
    while count < 10     
        udp = createobject("roDatagramSocket") 
        udp.setMessagePort(msgPort) 'notifications for udp come to msgPort  
        print "broadcast"
        print udp.setBroadcast(true)
        addr = createobject("roSocketAddress") 
        print addr.SetHostName("239.0.0.250")  
        print addr.setPort(32414)  
        print udp.setSendToAddress(addr) ' peer IP and port 
        udp.notifyReadable(true)
        print udp.sendStr(message) 
        continue = udp.eOK()                                                   

        if continue 
            count = 11
        else
            count = count + 1
            sleep(500)
            print "retrying"
        end if
    end while
    
    list = CreateObject("roList") 

    while continue 
        print "4"
        event = wait(timeout, msgPort)
        print "5"
        if type(event)="roSocketEvent"
            if event.getSocketID()=udp.getID() 
                if udp.isReadable()
                    message = udp.receiveStr(4096) ' max 4096 characters  
                    caddr = udp.getReceivedFromAddress()
                    h_address = caddr.getHostName()
                    
                    print "Received message: '"; message; "'"
                    timeout = 2000 ' Now that we got first response lets not wait as long 
                    
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
                    
                    serverDetails = CreateObject("roArray", 2 , true)
                    serverDetails.Push(h_name)
                    serverDetails.Push("http://" + h_address + ":"+ h_port)
                    list.AddTail(serverDetails)
                end if
            end if 
        else if event=invalid
            print "Timeout"
            continue = false
        end if
    end while
    udp.close() ' would happen automatically as udp goes out of scope End Function  
    return list
End Function

