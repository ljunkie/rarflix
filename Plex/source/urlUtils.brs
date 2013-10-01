'**********************************************************
'**  Video Player Example Application - URL Utilities
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'**********************************************************

REM ******************************************************
REM Url Query builder
REM so this is a quick and dirty name/value encoder/accumulator
REM ******************************************************

Function NewHttp(url As String) as Object
	Debug("Creating new http transfer object for " + url)
    obj = CreateObject("roAssociativeArray")
    obj.Http                        = CreateURLTransferObject(url)
    obj.FirstParam                  = true
    obj.AddParam                    = http_add_param
    obj.AddRawQuery                 = http_add_raw_query
    obj.PrepareUrlForQuery          = http_prepare_url_for_query
    obj.GetToStringWithTimeout      = http_get_to_string_with_timeout

    if Instr(1, url, "?") > 0 then obj.FirstParam = false

    return obj
End Function

Function CreateURLTransferObject(url As String) as Object
	Debug("Creating URL transfer object for " + url)
    obj = CreateObject("roUrlTransfer")
    obj.SetPort(CreateObject("roMessagePort"))
    obj.SetUrl(url)
    obj.AddHeader("Content-Type", "application/x-www-form-urlencoded")
    AddPlexHeaders(obj)
    obj.EnableEncodings(true)
    return obj
End Function

Sub AddPlexHeaders(transferObj, token=invalid)
    transferObj.AddHeader("X-Plex-Platform", "Roku")
    transferObj.AddHeader("X-Plex-Version", GetGlobal("appVersionStr"))
    transferObj.AddHeader("X-Plex-Client-Identifier", GetGlobal("rokuUniqueID"))
    transferObj.AddHeader("X-Plex-Platform-Version", GetGlobal("rokuVersionStr", "unknown"))
    transferObj.AddHeader("X-Plex-Product", "Plex for Roku")
    transferObj.AddHeader("X-Plex-Device", GetGlobal("rokuModel"))
    transferObj.AddHeader("X-Plex-Device-Name", RegRead("player_name", "preferences", GetGlobalAA().Lookup("rokuModel")))

    AddAccountHeaders(transferObj, token)
End Sub

Sub AddAccountHeaders(transferObj, token=invalid)
    if token <> invalid then
        transferObj.AddHeader("X-Plex-Token", token)
        'Debug("adding token X-Plex-Token:"+token) sometimes I just want to test and verify we are pushing the headers for shared users
    end if

    myplex = GetMyPlexManager()
    if myplex.Username <> invalid then
        transferObj.AddHeader("X-Plex-Username", myplex.Username)
    end if
End Sub


REM ******************************************************
REM HttpEncode - just encode a string
REM ******************************************************

Function HttpEncode(str As String) As String
    ' Creating and destroying a roUrlTransfer is slightly expensive, and it can
    ' add up if we're encoding a bunch of stuff (like, say, creating a bunch of
    ' image transcoder URLs when turning XML into metadata objects).
    if m.HttpEncoder = invalid then
        m.HttpEncoder = CreateObject("roUrlTransfer")
    end if
    return m.HttpEncoder.Escape(str)
End Function

REM ******************************************************
REM Prepare the current url for adding query parameters
REM Automatically add a '?' or '&' as necessary
REM ******************************************************

Function http_prepare_url_for_query() As String
    url = m.Http.GetUrl()
    if m.FirstParam then
        url = url + "?"
        m.FirstParam = false
    else
        url = url + "&"
    endif
    m.Http.SetUrl(url)
    return url
End Function

REM ******************************************************
REM Percent encode a name/value parameter pair and add the
REM the query portion of the current url
REM Automatically add a '?' or '&' as necessary
REM Prevent duplicate parameters
REM ******************************************************

Function http_add_param(name As String, val As String) as Void
    q = m.Http.Escape(name)
    q = q + "="
    url = m.Http.GetUrl()
    if Instr(1, url, q) > 0 return    'Parameter already present
    q = q + m.Http.Escape(val)
    m.AddRawQuery(q)
End Function

REM ******************************************************
REM Tack a raw query string onto the end of the current url
REM Automatically add a '?' or '&' as necessary
REM ******************************************************

Function http_add_raw_query(query As String) as Void
    url = m.PrepareUrlForQuery()
    url = url + query
    m.Http.SetUrl(url)
End Function

REM ******************************************************
REM Performs Http.AsyncGetToString() with a single timeout in seconds
REM To the outside world this appears as a synchronous API.
REM ******************************************************

Function http_get_to_string_with_timeout(seconds as Integer, headers=invalid As Object) as String
'Function http_get_to_string_with_timeout(seconds as Integer) as String
    timeout% = 1000 * seconds

    ' added for trailer/youtube support - RR
    if headers<>invalid then
        for each key in headers
            'print key,headers[key]
            m.Http.AddHeader(key, headers[key])
        end for
    end if

    str = ""
    m.Http.EnableFreshConnection(true) 'Don't reuse existing connections
    if (m.Http.AsyncGetToString())
        event = wait(timeout%, m.Http.GetPort())
        if type(event) = "roUrlEvent"
            m.ResponseCode = event.GetResponseCode()
            m.FailureReason = event.GetFailureReason()
            str = event.GetString()
        elseif event = invalid
            Debug("AsyncGetToString timeout")
            m.Http.AsyncCancel()
        else
            Debug("AsyncGetToString unknown event: " + type(event))
        endif
    endif

    return str
End Function

Function GetToStringWithTimeout(request As Object, seconds as Integer) as String
    timeout% = 1000 * seconds

    str = ""
    request.EnableFreshConnection(true) 'Don't reuse existing connections
    if (request.AsyncGetToString())
        event = wait(timeout%, request.GetPort())
        if type(event) = "roUrlEvent"
            str = event.GetString()
            if event.GetResponseCode() <> 200 then
                Debug("GET returned: " + tostr(event.GetResponseCode()) + " - " + event.GetFailureReason())
            end if
        elseif event = invalid
            Debug("AsyncGetToString timeout")
            request.AsyncCancel()
        else
            Debug("AsyncGetToString unknown event: " + type(event))
        endif
    endif

    return str
End Function
