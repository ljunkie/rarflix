'*
'* Responsible for the discovery of PM Servers on the local network
'* 

'* Returns a list of all media servers found on the local network
'*
Function MockDiscoverPlexMediaServers() As Object
	list = CreateObject("roList")
    list.AddTail(newPlexMediaServer("http://192.168.1.3:32400", "iMac"))
    'list.AddTail(newPlexMediaServer("http://dn-1.com:32400", "dn-1"))
    return list
End Function

Function DiscoverPlexMediaServers() As Object
  print "Discovering Plex Media Servers"  
  list = CreateObject("roList")
  di = CreateObject("roDeviceInfo")
  
  Dim minVersion[4]
  minVersion.Push(0)
  minVersion.Push(9)
  minVersion.Push(2)
  minVersion.Push(7)
  
  ipArray = di.GetIPAddrs()
  for each interface in ipArray
    print "Looking on network interface ";interface
  	ip = ipArray.Lookup(interface)
  	serversResponse = ScanNetwork(ip)
  	if serversResponse <> invalid then
    	xml=CreateObject("roXMLElement")
    	if xml.Parse(serversResponse) then
  	    	for each server in xml.Server
  	    	    print "Found server ";server@address
  	    	    if server@address <> invalid then
  	    	    	versionStr = server@version
  	    	    	versionHighEnough = ServerVersionCompare(versionStr, minVersion)
  	    	    	if versionHighEnough then
  	    	    		print "Accepting server with version:";versionStr
    	    			list.AddTail(newPlexMediaServer("http://" + server@address + ":32400", server@name))
    	    		else
    	    			print "Rejecting server with version:";versionStr
    	    		end if
    	    	end if
	    	end for
		endif
	endif
  next
  return list
End Function

Function ServerVersionCompare(versionStr, minVersion) As Boolean
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
  responseCount = 0
  while true
    event = wait(1, mp)
    if type(event) = "roUrlEvent"
       respCode = event.GetResponseCode()
       responseCount = responseCount + 1
       if respCode = 200 then
          serversResponse = event.GetString()
          print serversResponse
          if inStr(0, serversResponse, "address=")
            exit while
          endif
       endif
       if responseCount >= xferArray.Count() then
       		exit while
       endif
    endif
  end while
  return serversResponse
End Function
