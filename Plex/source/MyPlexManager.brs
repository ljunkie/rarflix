'*
'* Utilities related to signing in to myPlex and making myPlex requests
'*

Function createMyPlexManager(viewController) As Object
    obj = CreateObject("roAssociativeArray")

    obj.CreateRequest = mpCreateRequest
    obj.ShowPinScreen = mpShowPinScreen
    obj.ValidateToken = mpValidateToken
    obj.Disconnect = mpDisconnect

    device = CreateObject("roDeviceInfo")
    obj.ClientIdentifier = "Roku-" + device.GetDeviceUniqueId()

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
            print "Polling for myPlex PIN update at "; pollUrl
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
                    print "Request for new PIN failed:"; msg.GetResponseCode(); " - "; msg.GetFailureReason()
                    dialog = createBaseDialog()
                    dialog.Title = "Server unavailable"
                    dialog.Text = "The myPlex server couldn't be reached, please try again later."
                    dialog.Show()
                else
                    pollUrl = msg.GetResponseHeaders().Location
                    xml = CreateObject("roXMLElement")
                    xml.Parse(msg.GetString())
                    screen.SetRegistrationCode(xml.code.GetText())

                    print "Got a PIN ("; xml.code.GetText(); ") that expires at "; xml.GetNamedElements("expires-at").GetText()
                end if

                codeRequest = invalid
            else if pollRequest <> invalid AND pollRequest.GetIdentity() = msg.GetSourceIdentity() then
                if msg.GetResponseCode() = 200 then
                    xml = CreateObject("roXMLElement")
                    xml.Parse(msg.GetString())
                    token = xml.auth_token.GetText()
                    if len(token) > 0 then
                        print "Got a myPlex token"
                        if m.ValidateToken(token) then
                            RegWrite("AuthToken", token, "myplex")
                        end if
                        exit while
                    end if
                else
                    ' 404 is expected for expired pins, but treat all errors as expired
                    print "Expiring PIN, server response was"; msg.GetResponseCode()
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
        m.EmailAddress = xml.email.GetText()
        m.IsSignedIn = true
        m.AuthToken = token

        print "Validated myPlex token, corresponds to "; m.EmailAddress
    else
        print "Failed to validate myPlex token"
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
    req.AddHeader("X-Plex-Client-Identifier", m.ClientIdentifier)
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
            dlg.Text = "Your Roku needs a bit of help to play this. This video is in a format that your Roku doesn't understand. To play it, you need to connect to your Plex Media Server, which can convert it in real time to a more friendly format."
            dlg.Show()
        end if
        print "myPlex operation failed due to lack of primary server"
        return false
    end if

    return true
End Function

Function mpTranscodingVideoUrl(videoUrl As String, item As Object, httpCookies As String, userAgent As String)
    if NOT m.CheckTranscodeServer(true) then return invalid

    return m.TranscodeServer.TranscodingVideoUrl(videoUrl, item, httpCookies, userAgent)
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
        print "Don't know how to transcode image: "; queryUrl; ", "; imagePath
        return ""
    end if
End Function

Sub mpDelete(id)
    if id <> invalid then
        commandUrl = m.serverUrl + "/pms/playlists/queue/items/" + id
        print "Executing delete command: "; commandUrl
        request = m.CreateRequest("", commandUrl)
        request.PostFromString("_method=DELETE")
    end if
End Sub

Function mpExecuteCommand(commandPath)
    commandUrl = m.serverUrl + "/pms" + commandPath
    print "Executing command with full command URL: "; commandUrl
    request = m.CreateRequest("", commandUrl)
    request.AsyncGetToString()

    GetGlobalAA().AddReplace("async_command", request)
End Function

Function mpExecutePostCommand(commandPath)
    commandUrl = m.serverUrl + "/pms" + commandPath
    print "Executing POST command with full command URL: "; commandUrl
    request = m.CreateRequest("", commandUrl)
    request.AsyncPostFromString("")

    GetGlobalAA().AddReplace("async_command", request)
End Function

Function mpGetQueryResponse(sourceUrl, key) As Object
    xmlResult = CreateObject("roAssociativeArray")
    xmlResult.server = m
    if left(key, 4) = "http" then
        xml=CreateObject("roXMLElement")
        xml.Parse("<MediaContainer viewgroup='apps'/>")
        xmlResult.xml = xml
        xmlResult.sourceUrl = invalid
    else
        httpRequest = m.CreateRequest(sourceUrl, key)
        print "Fetching content from server at query URL:"; httpRequest.GetUrl()
        response = GetToStringWithTimeout(httpRequest, 60)
        xml=CreateObject("roXMLElement")
        if not xml.Parse(response) then
            print "Can't parse feed:";response
        endif

        xmlResult.xml = xml
        xmlResult.sourceUrl = httpRequest.GetUrl()
    end if
    return xmlResult
End Function

