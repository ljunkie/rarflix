'*
'* Utilities related to signing in to myPlex and making myPlex requests
'*

Function createMyPlexManager(viewController) As Object
    obj = CreateObject("roAssociativeArray")

    obj.CreateRequest = mpCreateRequest
    obj.ValidateToken = mpValidateToken
    obj.Disconnect = mpDisconnect

    obj.ExtraHeaders = {}
    obj.ExtraHeaders["X-Plex-Platform"] = "Roku"
    obj.ExtraHeaders["X-Plex-Platform-Version"] = GetGlobal("rokuVersionStr", "unknown")
    obj.ExtraHeaders["X-Plex-Provides"] = "player"
    obj.ExtraHeaders["X-Plex-Product"] = "Plex for Roku"
    obj.ExtraHeaders["X-Plex-Device"] = GetGlobal("rokuModel")
    obj.ExtraHeaders["X-Plex-Client-Identifier"] = GetGlobal("rokuUniqueID")

    Debug("myPlex headers")
    for each name in obj.ExtraHeaders
        Debug(name + ": " + obj.ExtraHeaders[name])
    next

    obj.ViewController = viewController

    ' Masquerade as a basic Plex Media Server
    obj.serverUrl = "https://my.plexapp.com"
    obj.name = "myPlex"
    obj.owned = false
    obj.online = true
    obj.StopVideo = mpStopVideo
    obj.StartTranscode = mpStartTranscode
    obj.PingTranscode = mpPingTranscode
    obj.TranscodedImage = mpTranscodedImage
    obj.TranscodingVideoUrl = mpTranscodingVideoUrl
    obj.ConstructVideoItem = pmsConstructVideoItem
    obj.GetQueryResponse = mpGetQueryResponse
    obj.AddDirectPlayInfo = pmsAddDirectPlayInfo
    obj.IsRequestToServer = pmsIsRequestToServer
    obj.Log = mpLog
    obj.AllowsMediaDeletion = false

    ' Commands, mostly use the PMS functions
    obj.SetProgress = progress
    obj.Scrobble = scrobble
    obj.Unscrobble = unscrobble
    obj.Rate = rate
    obj.Delete = mpDelete
    obj.ExecuteCommand = mpExecuteCommand
    obj.ExecutePostCommand = mpExecutePostCommand

    obj.IsSignedIn = false
    obj.CheckAuthentication = mpCheckAuthentication

    obj.TranscodeServer = invalid
    obj.CheckTranscodeServer = mpCheckTranscodeServer

    ' Stash a copy in the global AA
    GetGlobalAA().AddReplace("myplex", obj)

    return obj
End Function

Sub mpCheckAuthentication()
    if m.IsSignedIn then return
    token = RegRead("AuthToken", "myplex")
    if token <> invalid then
        m.ValidateToken(token)
    end if
End Sub

Function mpValidateToken(token) As Boolean
    req = m.CreateRequest("", "/users/sign_in.xml", false)
    port = CreateObject("roMessagePort")
    req.SetPort(port)
    req.AsyncPostFromString("auth_token=" + token)

    event = wait(10000, port)
    if type(event) = "roUrlEvent" AND event.GetInt() = 1 AND event.GetResponseCode() = 201 then
        xml = CreateObject("roXMLElement")
        xml.Parse(event.GetString())
        m.Username = xml.username.GetText()
        m.EmailAddress = xml.email.GetText()
        m.IsSignedIn = true
        m.AuthToken = token

        Debug("Validated myPlex token, corresponds to " + tostr(m.Username))
    else
        Debug("Failed to validate myPlex token")
        m.IsSignedIn = false
    end if

    return m.IsSignedIn
End Function

Function mpCreateRequest(sourceUrl As String, path As String, appendToken=true As Boolean) As Object
    url = FullUrl(m.serverUrl, sourceUrl, path)
    req = CreateURLTransferObject(url)
    if appendToken AND m.AuthToken <> invalid then
        if Instr(1, url, "?") > 0 then
            req.SetUrl(url + "&auth_token=" + m.AuthToken)
        else
            req.SetUrl(url + "?auth_token=" + m.AuthToken)
        end if
    end if
    for each name in m.ExtraHeaders
        req.AddHeader(name, m.ExtraHeaders[name])
    next
    req.AddHeader("Accept", "application/xml")
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    return req
End Function

Sub mpDisconnect()
    m.EmailAddress = invalid
    m.IsSignedIn = false
    m.AuthToken = invalid
    RegDelete("AuthToken", "myplex")
End Sub

Function mpCheckTranscodeServer(showError=false As Boolean) As Boolean
    if m.TranscodeServer = invalid then
        m.TranscodeServer = GetPrimaryServer()
    end if

    if m.TranscodeServer = invalid then
        if showError then
            dlg = createBaseDialog()
            dlg.Title = "Unsupported Content"
            dlg.Text = "Your Roku needs a bit of help to play this. This video is in a format that your Roku doesn't understand. To play it, you need to connect to your Plex Media Server, which can convert it in real time to a more friendly format. To learn more and install Plex Media Server, visit http://plexapp.com/getplex/"
            dlg.Show(true)
        end if
        Debug("myPlex operation failed due to lack of primary server")
        return false
    end if

    return true
End Function

Function mpTranscodingVideoUrl(videoUrl As String, item As Object, httpHeaders As Object, seekValue=0)
    if NOT m.CheckTranscodeServer(true) then return invalid

    return m.TranscodeServer.TranscodingVideoUrl(videoUrl, item, httpHeaders, seekValue)
End Function

Function mpStartTranscode(videoUrl)
    if NOT m.CheckTranscodeServer() then return ""

    return m.TranscodeServer.StartTranscode(videoUrl)
End Function

Function mpStopVideo()
    if NOT m.CheckTranscodeServer() then return invalid

    return m.TranscodeServer.StopVideo()
End Function

Function mpPingTranscode()
    if NOT m.CheckTranscodeServer() then return invalid

    return m.TranscodeServer.PingTranscode()
End Function

Function mpTranscodedImage(queryUrl, imagePath, width, height) As String
    if Left(imagePath, 5) = "https" then
        imagePath = "http" +  Mid(imagePath, 6, len(imagePath) - 5)
    end if

    if m.CheckTranscodeServer() then
        url = m.TranscodeServer.TranscodedImage(queryUrl, imagePath, width, height)
        if m.TranscodeServer.AccessToken <> invalid then
            url = url + "&X-Plex-Token=" + m.TranscodeServer.AccessToken
        end if
        return url
    else if Left(imagePath, 4) = "http" then
        return imagePath
    else
        Debug("Don't know how to transcode image: " + tostr(queryUrl) + ", " + tostr(imagePath))
        return ""
    end if
End Function

Sub mpDelete(id)
    if id <> invalid then
        commandUrl = m.serverUrl + "/pms/playlists/queue/items/" + id
        Debug("Executing delete command: " + commandUrl)
        request = m.CreateRequest("", commandUrl)
        request.PostFromString("_method=DELETE")
    end if
End Sub

Function mpExecuteCommand(commandPath)
    commandUrl = m.serverUrl + "/pms" + commandPath
    Debug("Executing command with full command URL: " + commandUrl)
    request = m.CreateRequest("", commandUrl)
    request.AsyncGetToString()

    GetGlobalAA().AddReplace("async_command", request)
End Function

Function mpExecutePostCommand(commandPath)
    commandUrl = m.serverUrl + "/pms" + commandPath
    Debug("Executing POST command with full command URL: " + commandUrl)
    request = m.CreateRequest("", commandUrl)
    request.AsyncPostFromString("")

    GetGlobalAA().AddReplace("async_command", request)
End Function

Function mpGetQueryResponse(sourceUrl, key) As Object
    xmlResult = CreateObject("roAssociativeArray")
    xmlResult.server = m
    httpRequest = m.CreateRequest(sourceUrl, key)
    Debug("Fetching content from server at query URL: " + tostr(httpRequest.GetUrl()))
    response = GetToStringWithTimeout(httpRequest, 60)
    xml=CreateObject("roXMLElement")
    if not xml.Parse(response) then
        Debug("Can't parse feed: " + tostr(response))
    endif

    xmlResult.xml = xml
    xmlResult.sourceUrl = httpRequest.GetUrl()

    return xmlResult
End Function

Sub mpLog(msg="", level=3, timeout=0)
    ' Noop, only defined to implement PlexMediaServer "interface"
End Sub

