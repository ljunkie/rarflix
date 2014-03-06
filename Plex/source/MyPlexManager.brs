'*
'* Utilities related to signing in to myPlex and making myPlex requests
'*

Function MyPlexManager(reinit = false) As Object
    if reinit = true then 
        AppManager().ClearInitializer("myplex")
        m.MyPlexManager = invalid
     end if

    if m.MyPlexManager = invalid then
        ' Start by creating a PlexMediaServer since we can't otherwise inherit
        ' anything. Then tweak as appropriate.
        obj = newPlexMediaServer("https://plex.tv", "myPlex", "myplex", false)

        AppManager().AddInitializer("myplex")

        obj.CreateRequest = mpCreateRequest
        obj.ValidateToken = mpValidateToken
        obj.Disconnect = mpDisconnect

        obj.ExtraHeaders = {}
        obj.ExtraHeaders["X-Plex-Provides"] = "player"

        ' Masquerade as a basic Plex Media Server
        obj.owned = false
        obj.online = true
        obj.StopVideo = mpStopVideo
        obj.StartTranscode = mpStartTranscode
        obj.PingTranscode = mpPingTranscode
        obj.TranscodedImage = mpTranscodedImage
        obj.TranscodingVideoUrl = mpTranscodingVideoUrl
        obj.GetQueryResponse = mpGetQueryResponse
        obj.Log = mpLog
        obj.AllowsMediaDeletion = false
        obj.SupportsMultiuser = false
        obj.SupportsVideoTranscoding = true

        ' Commands, mostly use the PMS functions
        obj.Delete = mpDelete
        obj.ExecuteCommand = mpExecuteCommand
        obj.ExecutePostCommand = mpExecutePostCommand

        obj.IsSignedIn = false
        obj.IsPlexPass = false
        obj.Username = invalid
        obj.EmailAddress = invalid
        obj.CheckAuthentication = mpCheckAuthentication

        obj.TranscodeServer = invalid
        obj.CheckTranscodeServer = mpCheckTranscodeServer

        obj.ProcessAccountResponse = mpProcessAccountResponse

        ' For using the view controller for HTTP requests
        obj.ScreenID = -5
        obj.OnUrlEvent = mpOnUrlEvent

        ' Singleton
        m.MyPlexManager = obj

        ' Kick off initialization
        token = RegRead("AuthToken", "myplex")
        if token <> invalid then
            obj.ValidateToken(token, not(reinit))
        else
            AppManager().ClearInitializer("myplex")
        end if
    end if

    return m.MyPlexManager
End Function

Sub mpCheckAuthentication()
    if m.IsSignedIn then return
    token = RegRead("AuthToken", "myplex")
    if token <> invalid then
        m.ValidateToken(token)
    end if
End Sub

Function mpValidateToken(token, async) As Boolean
    req = m.CreateRequest("", "/users/sign_in.xml", false)

    if async then
        context = CreateObject("roAssociativeArray")
        context.requestType = "account"
        GetViewController().StartRequest(req, m, context, "auth_token=" + token)
    else
        port = CreateObject("roMessagePort")
        req.SetPort(port)
        req.AsyncPostFromString("auth_token=" + token)

        event = wait(10000, port)
        m.ProcessAccountResponse(event)
    end if

    return m.IsSignedIn
End Function

Sub mpOnUrlEvent(msg, requestContext)
    if requestContext.requestType = "account" then
        m.ProcessAccountResponse(msg)
        AppManager().ClearInitializer("myplex")
    end if
End Sub

Sub mpProcessAccountResponse(event)
    if type(event) = "roUrlEvent" AND event.GetInt() = 1 AND event.GetResponseCode() = 201 then
        xml = CreateObject("roXMLElement")
        xml.Parse(event.GetString())
        m.Username = xml@username
        m.EmailAddress = xml@email
        m.IsSignedIn = true
        m.AuthToken = xml@authenticationToken
        m.IsPlexPass = (xml.subscription <> invalid AND xml.subscription@active = "1")

        Debug("Validated myPlex token, corresponds to " + tostr(m.Username))
        Debug("PlexPass: " + tostr(m.IsPlexPass))

        mgr = AppManager()
        mgr.IsPlexPass = m.IsPlexPass
        mgr.ResetState()
    else
        Debug("Failed to validate myPlex token")
        m.IsSignedIn = false
    end if
End Sub

Function mpCreateRequest(sourceUrl As String, path As String, appendToken=true As Boolean, connectionUrl=invalid) As Object
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
            dlg.Title = tr("Unsupported Content")
            dlg.Text = tr("Your Roku needs a bit of help to play this. This video is in a format that your Roku doesn't understand. To play it, you need to connect to your Plex Media Server, which can convert it in real time to a more friendly format. To learn more and install Plex Media Server, visit http://plexapp.com/getplex/")
            dlg.Show(true)
        end if
        Debug("myPlex operation failed due to lack of primary server")
        return false
    else
        m.SupportsVideoTranscoding = m.TranscodeServer.SupportsVideoTranscoding
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
        ' token is now part of TranscodedImage
        'if m.TranscodeServer.AccessToken <> invalid then
        '    url = url + "&X-Plex-Token=" + m.TranscodeServer.AccessToken
        'end if
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
