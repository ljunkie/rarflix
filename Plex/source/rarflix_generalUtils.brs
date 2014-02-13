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

' quick hack to convert a slow API call into a fast one 
' using the new corresponding filter call ( logic needs testing )
function convertToFilter(server,url)
    ' no server, no service
    if server = invalid then return url

    ' return original if not a library section call
    if instr(1, url, "/library/sections/") = 0 then return url

    ' exclude calls to the filters and sorts url
    if instr(1, url, "/filters") > 0 then return url
    if instr(1, url, "/sorts"  ) > 0 then return url

    newurl = url

    ' these already support paging and or filters correctly
    re = CreateObject("roRegex", "/all|/firstCharacter", "i")
    if re.IsMatch(newurl) then 
        ' see if we need to set the default sort option (or override)
        ' TODO(ljunkie) wrap this into a sub/function
        if instr(1, newurl, "sort=") = 0 then 
            f = "?"
            if instr(1, newurl, "?") > 0 then f = "&"
            sort = getSortingOption()
            newurl = newurl + f + "sort=" + sort.item.key
            Debug(" new SORT URL: " + tostr(newurl))
        end if

        return newurl
    end if


    ' determine the valid filters we can use -- not all older calls have an exact filtered call

    ' 1. get the determine the section key we are in ( used later )
    sectionKey = invalid
    r = CreateObject("roRegex", "(/library/sections/\d+)", "")
    wanted = r.Match(url)
    if wanted[0] <> invalid then sectionKey = wanted[1]
    if sectionKey = invalid then return url

    ' 2. obtain the valid filter keys from the cache (or create the cache)
    filterCacheKey = "filters_"+tostr(server.machineid)+tostr(sectionKey)
    validFilters = GetGlobal(filterCacheKey)

    ' 3. known valid filter cache doesn't exist yet -- create it
    if validFilters = invalid then 
        Debug("caching Valid filters for this section")
        ' set cache to empty ( not invalid -- so we don't keep retrying )
        GetGlobalAA().AddReplace(filterCacheKey, {})        
        obj = createPlexContainerForUrl(server, "", sectionKey + "/filters")
        if obj <> invalid then 
            ' using an assoc array ( we might want more key/values later )
            GetGlobalAA().AddReplace(filterCacheKey, obj.getmetadata())        
            validFilters = GetGlobal(filterCacheKey)
        end if
    end if

    ' 4. we have checked the cache or made an api call -- return orig url if still invalid
    if validFilters = invalid or validFilters.count() = 0 then
        Debug("no valid filters found for this section? " + tostr(sectionKey) + "/filters")
        return url
    end if   

    found = false
    for each filter in validFilters

        ' special caveats
        ' * TV Show : /library/sections/#/unwatchedLeaves should be /library/sections/#/unwatched
        if filter.filter = "unwatchedLeaves" then filter.key = sectionKey + "/unwatched"

        ' integer and string filters
        ' Example:
        '     expecting: [server:port]/library/sections/2/make/538
        '     resetting: [server:port]/library/sections/2/all?make=538
        if filter.filtertype = "integer" or filter.filtertype = "string" then 
            if instr(1, url, filter.key ) > 0 then
                r = CreateObject("roRegex", filter.key + "/([^\/]+)", "")
                parts = r.Match(url)
                if parts[0] <> invalid then newurl = server.serverurl + sectionKey + "/all?" + filter.filter + "=" + parts[1]
                found = true
                exit for
            end if
        end if

        ' boolean filters (for now we will assume the boolean=1)
        ' Example: TODO(ljunkie) old TV key doesn't match Filtered key
        '     expecting: [server:port]/library/sections/5/watched
        '     resetting: [server:port]/library/sections/5/all?watched=1
        if filter.filtertype = "boolean" then
            if instr(1, url, filter.key ) > 0 then
                newurl = server.serverurl + sectionKey + "/all?" + filter.filter + "=1"
                found = true
                exit for
            end if
        end if

    end for

    ' Debugging: will be useful to debug slowdowns
    if found = false then
        Debug("This endpoint does not have a valid filter call: " + tostr(newurl))
        Debug("    valid filters:")
        for each filter in validFilters
            Debug("        " + tostr(filter.key))
        end for 
    end if

    ' Debugging: show original and new url
    if newurl <> url then 
        Debug("converted older API request to New API filter")
        Debug(" orig URL: " + tostr(url))
        Debug(" new  URL: " + tostr(newurl))

        ' see if we need to set the default sort option (or override)
        if instr(1, newurl, "sort=") = 0 then 
            f = "?"
            if instr(1, newurl, "?") > 0 then f = "&"
            sort = getSortingOption()
            newurl = newurl + f + "sort=" + sort.item.key
            Debug(" new SORT URL: " + tostr(newurl))
        end if

    end if

    return newurl

end function

function getSortingOption(GetNext = invalid,sourceUrl=invalid)
    ' TODO(ljunkie) customer based on section ( different sorting options )

    ' try to determine the current sort if already in the url
    sortKey = invalid
    if sourceUrl <> invalid then 
        re = CreateObject("roRegex", "sort=([^\&\?]+)", "i")
        match = re.Match(sourceurl)
        if match[0] <> invalid then sortKey = match[1]
    end if

    obj = {}
    options = []
    options.Push({ title: "Title", key: "titleSort:asc"})
    options.Push({ title: "Date Added", key: "addedAt:desc"})
    options.Push({ title: "Date Released", key: "originallyAvailableAt:desc"})
    options.Push({ title: "Rating", key: "rating:desc"})
    obj.contentArray = options
    obj.curIndex = 0

    defaultSort = RegRead("section_sort", "preferences","titleSort:asc")

    if sortKey = invalid then sortKey = GetGlobalAA().lookup("section_sort")
    if sortkey = invalid then sortKey = defaultSort

    for index = 0 to options.count()-1
        if options[index].key = sortKey then 
            obj.curIndex = index
        end if
    end for

    if GetNext <> invalid
        obj.curIndex = obj.curIndex+1
        if obj.curIndex > options.count()-1 then obj.curIndex = 0

        GetGlobalAA().AddReplace("section_sort",options[obj.curIndex].key)
    end if

    obj.item = obj.contentArray[obj.curIndex]

    ' return the default sort option if the required critera hasn't been matched
    return obj
end function