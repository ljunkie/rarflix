'*
'* Utilities related to signing in to myPlex and making myPlex requests
'*

Function createMyPlexManager(viewController) As Object
    obj = CreateObject("roAssociativeArray")

    obj.CreateRequest = mpCreateRequest
    obj.ShowPinScreen = mpShowPinScreen
    obj.ValidateToken = mpValidateToken
    obj.Disconnect = mpDisconnect

    obj.ExtraHeaders = {}
    obj.ExtraHeaders["X-Plex-Platform"] = "Roku"
    obj.ExtraHeaders["X-Plex-Platform-Version"] = GetGlobal("rokuVersionStr", "unknown")
    obj.ExtraHeaders["X-Plex-Provides"] = "player"
    obj.ExtraHeaders["X-Plex-Product"] = "Plex for Roku"
    obj.ExtraHeaders["X-Plex-Version"] = GetGlobal("appVersionStr")
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
    obj.StopVideo = mpStopVideo
    obj.StartTranscode = mpStartTranscode
    obj.PingTranscode = mpPingTranscode
    obj.TranscodedImage = mpTranscodedImage
    obj.TranscodingVideoUrl = mpTranscodingVideoUrl
    obj.ConstructVideoItem = pmsConstructVideoItem
    obj.GetQueryResponse = mpGetQueryResponse
    obj.AddDirectPlayInfo = pmsAddDirectPlayInfo
    obj.Log = mpLog

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
    if RegExists("AuthToken", "myplex") then
        m.ValidateToken(RegRead("AuthToken", "myplex"))
    end if
End Sub

Function mpShowPinScreen() As Object
    port = CreateObject("roMessagePort")
    screen = CreateObject("roCodeRegistrationScreen")
    screen.SetMessagePort(port)

    screen.SetTitle("Connect myPlex account")
    screen.AddParagraph("To access your shared sections and queue, link your Roku player to your myPlex account.")
    screen.AddParagraph(" ")
    screen.AddFocalText("From your computer,", "spacing-dense")
    screen.AddFocalText("go to my.plexapp.com/pin", "spacing-dense")
    screen.AddFocalText("and enter this code:", "spacing-dense")
    screen.SetRegistrationCode("retrieving code...")
    screen.AddParagraph(" ")
    screen.AddParagraph("This screen will automatically update once your Roku player has been linked to your myPlex account.")

    screen.AddButton(0, "get a new code")
    screen.AddButton(1, "back")

    screen.Show()

    ' Kick off a request for the real pin
    codeRequest = m.CreateRequest("", "/pins.xml")
    codeRequest.SetPort(port)
    codeRequest.AsyncPostFromString("")

    pollRequest = invalid
    pollUrl = invalid

    while true
        msg = wait(5000, port)
        if msg = invalid AND pollRequest = invalid AND pollUrl <> invalid then
            ' Our 5 second timeout, check the server
            Debug("Polling for myPlex PIN update at " + pollUrl)
            pollRequest = m.CreateRequest("", pollUrl)
            pollRequest.SetPort(port)
            pollRequest.AsyncGetToString()
        else if type(msg) = "roCodeRegistrationScreenEvent" then
            if msg.isScreenClosed()
                exit while
            else if msg.isButtonPressed()
                if msg.GetIndex() = 0 then
                    ' Get new code
                    screen.SetRegistrationCode("retrieving code...")
                    codeRequest = m.CreateRequest("", "/pins.xml")
                    codeRequest.SetPort(port)
                    codeRequest.AsyncPostFromString("")
                else
                    exit while
                end if
            end if
        else if type(msg) = "roUrlEvent" AND msg.GetInt() = 1 then
            if codeRequest <> invalid AND codeRequest.GetIdentity() = msg.GetSourceIdentity() then
                if msg.GetResponseCode() <> 201 then
                    Debug("Request for new PIN failed: " + tostr(msg.GetResponseCode()) + " - " + tostr(msg.GetFailureReason()))
                    dialog = createBaseDialog()
                    dialog.Title = "Server unavailable"
                    dialog.Text = "The myPlex server couldn't be reached, please try again later."
                    dialog.Show()
                else
                    pollUrl = msg.GetResponseHeaders().Location
                    xml = CreateObject("roXMLElement")
                    xml.Parse(msg.GetString())
                    screen.SetRegistrationCode(xml.code.GetText())

                    Debug("Got a PIN (" + tostr(xml.code.GetText()) + ") that expires at " + tostr(xml.GetNamedElements("expires-at").GetText()))
                end if

                codeRequest = invalid
            else if pollRequest <> invalid AND pollRequest.GetIdentity() = msg.GetSourceIdentity() then
                if msg.GetResponseCode() = 200 then
                    xml = CreateObject("roXMLElement")
                    xml.Parse(msg.GetString())
                    token = xml.auth_token.GetText()
                    if len(token) > 0 then
                        Debug("Got a myPlex token")
                        if m.ValidateToken(token) then
                            RegWrite("AuthToken", token, "myplex")
                        end if
                        exit while
                    end if
                else
                    ' 404 is expected for expired pins, but treat all errors as expired
                    Debug("Expiring PIN, server response was " + tostr(msg.GetResponseCode()))
                    screen.SetRegistrationCode("code expired")
                    pollUrl = invalid
                end if

                pollRequest = invalid
            end if
        end if
    end while

    if codeRequest <> invalid then codeRequest.AsyncCancel()
    if pollRequest <> invalid then pollRequest.AsyncCancel()
End Function

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
            dlg.Show()
        end if
        Debug("myPlex operation failed due to lack of primary server")
        return false
    end if

    return true
End Function

Function mpTranscodingVideoUrl(videoUrl As String, item As Object, httpHeaders As Object)
    if NOT m.CheckTranscodeServer(true) then return invalid

    return m.TranscodeServer.TranscodingVideoUrl(videoUrl, item, httpHeaders)
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

