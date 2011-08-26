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
		allServers = existing + "{" + address+"\"+name
	else
		allServers = address+"\"+name
	end if
	RegWrite("serverList", allServers, "servers")
End Function

Function AddUnnamedServer(address)
	print "Adding unnamed server to saved list:";address
	strReplace(address, "http://", "")
	strReplace(address, ":32400", "")
	AddServer(address, "http://"+address+":32400")
End Function

Function DiscoverPlexMediaServers()
	retrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Finding Plex Media Servers ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()
	found = Discover()
	for each server in found
		AddServer(server[0], server[1])
	end for
	retrieving.Close()
End Function


Function Discover() As Object
  print "Discovering Plex Media Servers"  
  list = CreateObject("roList")
  di = CreateObject("roDeviceInfo")
  
  ipArray = di.GetIPAddrs()
  for each interface in ipArray
    print "Looking on network interface ";interface
  	ip = ipArray.Lookup(interface)
  	serversResponse = ScanNetwork(ip)
  	if serversResponse <> invalid AND serversResponse[0] <> invalid then
    	xml=CreateObject("roXMLElement")
    	if xml.Parse(serversResponse[0]) then
  	    	for each server in xml.Server
  	    	    print "Found server ";server@host
  	    	    if server@address <> invalid OR server@host <> invalid then
  	    	    	address = server@address
  	    	    	if address = invalid then
						hostName = server@host
						serverAddress = serversResponse[1]
						resolveService = "http://"+serverAddress + ":32400/servers/resolve?name=" + hostName
						print "Resolve URL:";resolveService
						resolveRequest = NewHttp(resolveService)
						resolveResponse = resolveRequest.GetToStringWithRetry()
						resolveResponseXml = CreateObject("roXMLElement")
						resolveResponseXml.Parse(resolveResponse)
						if resolveResponseXml <> invalid AND resolveResponseXml.Address.Count() > 0 then
							address = resolveResponseXml.Address[0]@address
							print "Resolved address:";address
						end if
					end if
  	    	    	if address <> invalid then
							serverDetails = CreateObject("roArray", 2 , true)
							serverDetails.Push(server@name)
							serverDetails.Push("http://" + address + ":32400")
    	    				list.AddTail(serverDetails)
    	    		end if
    	    	end if
	    	end for
		endif
	endif
  next
  return list
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

Function ScanNetwork(ip) As Object
  	print "scanning:";ip
	baseip = ""
  	While instr(0, ip, ".") > 0
    	baseip = baseip + left(ip, instr(0, ip, "."))
    	ip = right(ip,len(ip)-instr(0, ip, "."))
    	print baseip
    'print ip
  	End While
  	
  dim xferArray[254]
  mp = CreateObject("roMessagePort")
  For x = 0 to 254
    url = "http://" + baseip + right(Str(x), len(Str(x))-1) + ":32400/servers"
    'print url
    xferArray[x] = CreateObject("roUrlTransfer")
    xferArray[x].SetUrl(url)
    xferArray[x].SetPort(mp)
    xferArray[x].AsyncGetToString()
  End For
  serversResponse = invalid
  serverAddress = invalid
  responseCount = 0
  while true
    event = wait(1, mp)
    if type(event) = "roUrlEvent"
       respCode = event.GetResponseCode()
       responseCount = responseCount + 1
       if respCode = 200 then
          serversResponse = event.GetString()
          serverAddress = event.GetTargetIpAddress()
          print serversResponse
          if inStr(0, serversResponse, "address=") OR inStr(0, serversResponse, "host=")
            exit while
          endif
       endif
       if responseCount >= xferArray.Count() then
       		exit while
       endif
    endif
  end while
  Dim response[2]
  response.Push(serversResponse)
  response.Push(serverAddress)
  return response
End Function
