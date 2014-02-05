' ljunkie - really no function for this or am I blind?
' haystack: must be an array
' needle: string or array
' *  needle array? then see if any needles exist in haystack
function inArray(haystack as dynamic,needles = dynamic) as boolean
    if type(haystack) = "roArray" and haystack.count() > 0 then

        if type(needles) = "roString" then
            new = []
            new.Push(needles)
            needles = new
        end if

        if type(needles) = "roArray" and needles.count() > 0 then 
            for each needle in needles
                for each item in haystack
                    if item = needle then return true
                next
            next
        end if
    end if
 return false
end function

Function URLEncode(str As String) As String
    if not m.DoesExist("encodeProxyUrl") then m.encodeProxyUrl = CreateObject("roUrlTransfer")
    return m.encodeProxyUrl.urlEncode(str)
End Function

Function URLDecode(str As String) As String
    strReplace(str,"+"," ") ' backward compatibility
    if not m.DoesExist("encodeProxyUrl") then m.encodeProxyUrl = CreateObject("roUrlTransfer")
    return m.encodeProxyUrl.Unescape(str)
End Function

Function Quote()
    q$ = Chr(34)
    return q$
End Function

function rfStripAPILimits(url)
    r  = CreateObject("roRegex", "[?&]X-Plex-Container-Start=\d+\&X-Plex-Container-Size\=.*", "")
    if r.IsMatch(url) then 
        Debug("--------------------------- OLD " + tostr(url))
        url = r.replace(url,"")
        Debug("--------------------------- NEW " + tostr(url))
    end if
    return url
end function

function hasPendingRequest(context=invalid) as boolean
    ' expects context to contain server/key ( ignores all others )
    ' return true if we already have a pending request for the key on a specific server
    if context = invalid then return false
    if context.server = invalid or context.key = invalid then return false

    pendingRequests = GetViewController().pendingrequests
    if pendingRequests <> invalid then
        for each id in pendingRequests
            if pendingRequests[id] <> invalid and tostr(pendingRequests[id].key) = context.key then 
                if pendingRequests[id].server.machineidentifier = context.server.machinentifier then 
                      Debug("we already have a request pending for key: " + tostr(context.key) + " on server " + tostr(context.server.name) )
                      return true
                end if
            end if 
        end for 
    end if

    return false
end function

