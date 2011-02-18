'*
'* Responsible for the discovery of PM Servers on the local network
'* 

'* Returns a list of all media servers found on the local network
'*
'* Mock hardcode implementation currently
'* 
Function DiscoverPlexMediaServers() As Object
	list = CreateObject("roList")
	list.AddTail(newPlexMediaServer("http://192.168.1.3:32400", "iMac"))
	'list.AddTail(newPlexMediaServer("http://192.168.1.1:32400", "Mini"))
	return list
End Function
