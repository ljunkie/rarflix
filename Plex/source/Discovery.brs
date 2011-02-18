'*
'* Responsible for the discovery of PM Servers on the local network
'* 

'* Returns a list of all media servers found on the local network
'*
'* Mock hardcode implementation currently
'* 
Function DiscoverPlexMediaServers() As Object
  
  di = CreateObject("roDeviceInfo")
  ipArray = di.GetIPAddrs()
  ip = ipArray.Lookup("eth1")
  baseip = ""
  While instr(0, ip, ".") > 0
    baseip = baseip + left(ip, instr(0, ip, "."))
    ip = right(ip,len(ip)-instr(0, ip, "."))
    print baseip
    print ip
  End While
  
  dim xferArray[254]
  mp = CreateObject("roMessagePort")
  For x = 0 to 254
    url = "http://" + baseip + right(Str(x), len(Str(x))-1) + ":32400/servers"
    print url
    xferArray[x] = CreateObject("roUrlTransfer")
    xferArray[x].SetUrl(url)
    xferArray[x].SetPort(mp)
    xferArray[x].AsyncGetToString()
  End For
  
  while true
    event = wait(1, mp)
    if type(event) = "roUrlEvent"
       respCode = event.GetResponseCode()
       if respCode = 200 then
          serversResponse = event.GetString()
          print serversResponse
          if inStr(0, serversResponse, "address=")
            exit while
          endif
       endif
    endif
  end while
  
  list = CreateObject("roList")
  
  xml=CreateObject("roXMLElement")
  xml.Parse(serversResponse)
  for each server in xml.Server
    list.AddTail(newPlexMediaServer("http://" + server@address + ":32400", server@name))
	end for
  'list.AddTail(newPlexMediaServer("http://dn-1.com:32400", "dn-1"))
	return list
End Function
