'*
'* Utilities related to signing in to myPlex and making myPlex requests
'*

Function createMyPlexManager() As Object
    obj = CreateObject("roAssociativeArray")

    obj.CreateRequest = mpCreateRequest
    obj.ShowPinScreen = mpShowPinScreen
    obj.ValidateToken = mpValidateToken
    obj.Disconnect = mpDisconnect

    device = CreateObject("roDeviceInfo")
    obj.ClientIdentifier = "Roku-" + device.GetDeviceUniqueId()

    obj.serverUrl = "https://my.plexapp.com"

    if RegExists("AuthToken", "myplex") then
        obj.ValidateToken(RegRead("AuthToken", "myplex"))
    else
        obj.IsSignedIn = false
    end if

    return obj
End Function

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
    codeRequest = m.CreateRequest("/pins.xml")
    codeRequest.SetPort(port)
    codeRequest.AsyncPostFromString("")

    pollRequest = invalid
    pollUrl = invalid

    while true
        msg = wait(5000, port)
        if msg = invalid AND pollRequest = invalid AND pollUrl <> invalid then
            ' Our 5 second timeout, check the server
            print "Polling for myPlex PIN update at "; pollUrl
            pollRequest = m.CreateRequest(pollUrl)
            pollRequest.SetPort(port)
            pollRequest.AsyncGetToString()
        else if type(msg) = "roCodeRegistrationScreenEvent" then
            if msg.isScreenClosed()
                exit while
            else if msg.isButtonPressed()
                if msg.GetIndex() = 0 then
                    ' Get new code
                    screen.SetRegistrationCode("retrieving code...")
                    codeRequest = m.CreateRequest("/pins.xml")
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
    req = m.CreateRequest("/users/sign_in.xml")
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

Function mpCreateRequest(path As String) As Object
    url = FullUrl(m.serverUrl, "", path)
    req = CreateURLTransferObject(url)
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

