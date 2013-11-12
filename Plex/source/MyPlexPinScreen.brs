'*
'* Code registration screen for linking a myPlex account.
'*

Function createMyPlexPinScreen(viewController As Object) As Object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    screen = CreateObject("roCodeRegistrationScreen")
    screen.SetMessagePort(obj.Port)

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

    ' Set standard screen properties/methods
    obj.Screen = screen
    obj.Show = pinShow
    obj.HandleMessage = pinHandleMessage
    obj.OnUrlEvent = pinOnUrlEvent
    obj.OnTimerExpired = pinOnTimerExpired
    obj.ScreenName = "myPlex PIN"

    obj.pollUrl = invalid

    return obj
End Function

Sub pinShow()
    m.Screen.Show()

    ' Kick off a request for the real pin
    httpRequest = MyPlexManager().CreateRequest("", "/pins.xml")
    context = CreateObject("roAssociativeArray")
    context.requestType = "code"

    m.ViewController.StartRequest(httpRequest, m, context, "")

    ' Create a timer for polling to see if the code has been linked.
    timer = createTimer()
    timer.Name = "poll"
    timer.SetDuration(5000, true)
    m.ViewController.AddTimer(timer, m)
End Sub

Function pinHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roCodeRegistrationScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
        else if msg.isButtonPressed()
            if msg.GetIndex() = 0 then
                ' Get new code
                m.Screen.SetRegistrationCode("retrieving code...")
                httpRequest = MyPlexManager().CreateRequest("", "/pins.xml")
                context = CreateObject("roAssociativeArray")
                context.requestType = "code"

                m.ViewController.StartRequest(httpRequest, m, context, "")
            else
                m.Screen.Close()
            end if
        end if
    end if

    return handled
End Function

Sub pinOnUrlEvent(msg, requestContext)
    if requestContext.requestType = "code" then
        if msg.GetResponseCode() <> 201 then
            Debug("Request for new PIN failed: " + tostr(msg.GetResponseCode()) + " - " + tostr(msg.GetFailureReason()))
            dialog = createBaseDialog()
            dialog.Title = "Server unavailable"
            dialog.Text = "The myPlex server couldn't be reached, please try again later."
            dialog.Show()
        else
            m.pollUrl = msg.GetResponseHeaders().Location
            xml = CreateObject("roXMLElement")
            xml.Parse(msg.GetString())
            m.Screen.SetRegistrationCode(xml.code.GetText())

            Debug("Got a PIN (" + tostr(xml.code.GetText()) + ") that expires at " + tostr(xml.GetNamedElements("expires-at").GetText()))
        end if
    else if requestContext.requestType = "poll" then
        if msg.GetResponseCode() = 200 then
            xml = CreateObject("roXMLElement")
            xml.Parse(msg.GetString())
            token = xml.auth_token.GetText()
            if len(token) > 0 then
                Debug("Got a myPlex token")
                if MyPlexManager().ValidateToken(token) then
                    RegWrite("AuthToken", token, "myplex")
                end if
                m.Screen.Close()
            end if
        else
            ' 404 is expected for expired pins, but treat all errors as expired
            Debug("Expiring PIN, server response was " + tostr(msg.GetResponseCode()))
            m.Screen.SetRegistrationCode("code expired")
            m.pollUrl = invalid
        end if
    end if
End Sub

Sub pinOnTimerExpired(timer)
    if m.pollUrl <> invalid then
        ' Kick off a polling request
        Debug("Polling for myPlex PIN update at " + m.pollUrl)
        httpRequest = MyPlexManager().CreateRequest("", m.pollUrl)
        context = CreateObject("roAssociativeArray")
        context.requestType = "poll"

        m.ViewController.StartRequest(httpRequest, m, context)
    end if
End Sub
