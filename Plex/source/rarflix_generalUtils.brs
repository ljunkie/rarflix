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
    pending = false

    if context = invalid then return pending
    if context.server = invalid or context.key = invalid then return pending

    pendingRequests = GetViewController().pendingrequests
    if pendingRequests <> invalid then
        for each id in pendingRequests
            if pendingRequests[id] <> invalid and tostr(pendingRequests[id].key) = context.key then 
                if pendingRequests[id].server.machineidentifier = context.server.machinentifier then 
                      Debug("we already have a request pending for key: " + tostr(context.key) + " on server " + tostr(context.server.name) )
                      ' it's possible we used a different connectionUrl.. verify that is the same too!
                      ' it's ok if connectionurl is invalid -- either different or still the same
                      if pendingRequests[id].connectionurl <> context.connectionurl
                          Debug("different connectionUrl specified -- continue")
                      else 
                          pending = true
                      end if
                end if
            end if 
        end for 
    end if

    return pending
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
            sort = getSortingOption(server,newurl)
            ' exclude the default
            if sort <> invalid and sort.item <> invalid and sort.item.key <> "titleSort:asc" then 
                newurl = newurl + f + "sort=" + sort.item.key
                Debug(" new SORT URL: " + tostr(newurl))
            end if
        end if

        return newurl
    end if

    ' 1. get the base library section key
    sectionKey = getBaseSectionKey(url)
    if sectionKey = invalid then return invalid

    ' 2-3. obtain the valid filter keys from the cache (or create the cache)
    validFilters = getValidFilters(server,url)

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
            ' exclude the default
            sort = getSortingOption(server,newurl)
            if sort <> invalid and sort.item <> invalid and sort.item.key <> "titleSort:asc" then 
                newurl = newurl + f + "sort=" + sort.item.key
                Debug(" new SORT URL: " + tostr(newurl))
            end if
        end if

    end if

    return newurl

end function

function getBaseSectionKey(sourceUrl = invalid)
    if sourceUrl = invalid then return invalid

    sectionKey = invalid
    r = CreateObject("roRegex", "(/library/sections/\d+)", "")
    wanted = r.Match(sourceUrl)
    if wanted[0] <> invalid then sectionKey = wanted[1]

    return sectionKey
end function

function getNextEpisodes(item,details=false) 
    ' get all shows episodes as an object from an existing show item
    ' obj.context   : all context
    ' obj.item      : current item
    ' obj.curIndex  : current item index
    ' obj.nextIndex : next item index
    ' results: always return invalid unless item has been found
    if item = invalid or item.server = invalid then return invalid

    Debug("getNextEpisode:: for: " + tostr(item.title))
    episodesKey = item.parentkey + "/children"
    'TODO(ljunkie) we should never use parentKey. It's a fallback now, but using parent key only yields
    ' a specific seasons episodes. 
    if item.grandparentkey <> invalid then episodesKey = item.grandparentkey + "/allLeaves"
    if episodesKey = invalid then return invalid

    obj = {}
    container = createPlexContainerForUrl(item.server, "", episodesKey)
    if container <> invalid and container.xml <> invalid and container.xml.Video <> invalid then 
        obj.context = container.GetMetaData()
        for index = 0 to obj.context.count()-1
            if obj.context[index].ratingKey = item.ratingKey then 
                obj.curindex = index                    
                nextIndex = index+1
                if obj.context[nextIndex] <> invalid then 
                    obj.item = obj.context[nextIndex]
                    obj.Nextindex = nextIndex                    
                    Debug("getNextEpisode:: found: " + tostr(obj.item.title))
                    return obj
                end if
                Debug("getNextEpisode:: this is the last episode available")
                return invalid
           end if
        end for
    end if 

    Debug("getNextEpisode:: not found")
    return invalid
end function

function defaultTypes(key=invalid,typeKey=invalid)
    '    key : movie|show|artist
    ' tmpKey : numericID of key
    ' 
    ' if key <> movie|show|artist this will return invalid
    ' exception: if key = specific key (episode|album|etc) and typeKey is set
    '  this will utilize the allTypes array for results
    types = {}

    ' shot object
    types.show = {}
    types.show.title = "show"
    types.show.key = 2
    types.show.values = [
        {title: "show" , key: 2},
        {title: "episode" , key: 4 }
    ]

    ' artist object
    types.artist = {}
    types.artist.title = "artist"
    types.artist.key = 8
    types.artist.values = [
        {title: "artist" , key: 8},
        {title: "album" , key: 9 }
    ]
    '{title: "track" , key: 10 }

    ' all valid types ( more to come if needed )
    allTypes = [
        {title: "show" , key: 2, main: "show"},
        {title: "episode" , key: 4, main: "show"},
        {title: "artist" , key: 8, main: "artist"},
        {title: "album" , key: 9, main: "artist"},
    ]

    ' track is not available by filters yet
    ' TODO(ljunkie) this causes a bad crash when allowed. Should be able to handle this better
    '{title: "track" , key: 10, main: "artist"},

    if key <> invalid then 
        ' reset the default if typeKey specified
        if typeKey <> invalid and types[key] <> invalid then 
            for each item in types[key].values
                if item.key = typeKey then 
                    types[key].key = item.key
                    types[key].title = item.title
                    return types[key]
                    exit for
                end if
            end for 
        end if

        ' reset the default if typeKey specified and key more specific 
        if typeKey <> invalid then 
            for each item in alltypes
                if item.key = typeKey then 
                    types[item.main].key = item.key
                    types[item.main].title = item.title
                    return types[item.main]
                    exit for
                end if
            end for 
        end if

        ' return defaults for key - invalid result if not set is expected
        return types[key]
    end if

    return invalid
end function

' used to get/set the cachekeys used for globalAA records
'  if typeKey is sepcifided, it will set the server/section type
function getFilterSortCacheKeys(server=invalid,sourceUrl=invalid,typeKey=invalid)
    if server = invalid or sourceUrl = invalid then return invalid
    ' get base section from url
    sectionKey = getBaseSectionKey(sourceUrl)
    if sectionKey = invalid then return invalid

    obj = {}

    obj.sectionKey = sectionKey    
    obj.typeValCacheKey = "section_typekey_"+tostr(server.machineid)+tostr(sectionKey)

    ' set the cuttent type if sent
    if typeKey <> invalid then 
        GetGlobalAA().AddReplace(obj.typeValCacheKey, typeKey)
    end if

    ' value keys ( single values: type & sort)
    obj.typeKey = GetGlobal(obj.typeValCacheKey)

    ' Global Cache keys for values ( after verifyting typeKey )
    obj.filterValuesCacheKey = "section_filters_"+tostr(server.machineid)+tostr(sectionKey)+"_"+tostr(obj.typeKey)
    obj.sortValCacheKey = "section_sort_"+tostr(server.machineid)+tostr(sectionKey)+"_"+tostr(obj.typeKey)

    ' available filter and sorts for section (with typeKey if set)
    obj.filterCacheKey = "filters_"+tostr(server.machineid)+tostr(sectionKey)+"_"+tostr(obj.typeKey)
    obj.sortCacheKey = "sorts_"+tostr(server.machineid)+tostr(sectionKey)+"_"+tostr(obj.typeKey)

    return obj
end function

