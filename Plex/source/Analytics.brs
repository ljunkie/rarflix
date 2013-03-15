'*
'* Create an object to interact with analytics backends, specifically Google
'* Analytics for now. While this object could be used to track anything, if
'* you're reading this then please note that nothing identifiable about what
'* you're watching is tracked. We're basically keeping track of how much
'* media of each type is being consumed (movie, music, photo), to allow us
'* to direct future focus most effectively. And you can always opt out.
'*
'* This class is written largely anew, but while reading Trevor Anderson's
'* GATracker.brs, which deserves a hat tip. That library came with a license
'* disclaimer that is duplicated below.
'*

REM *****************************************************
REM   Google Analytics Tracking Library for Roku
REM   GATracker.brs - Version 2.0
REM   (C) 2012, Trevor Anderson, BloggingWordPress.com
REM   Permission is hereby granted, free of charge, to any person obtaining a copy of this software
REM   and associated documentation files (the "Software"), to deal in the Software without restriction,
REM   including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
REM   and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
REM   subject to the following conditions:
REM
REM   The above copyright notice and this permission notice shall be included in all copies or substantial
REM   portions of the Software.
REM
REM   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
REM   LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
REM   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
REM   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
REM   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
REM *****************************************************

Function createAnalyticsTracker()
    obj = CreateObject("roAssociativeArray")

    ' We need a ScreenID property in order to use the view controller for requests.
    obj.ScreenID = -2

    obj.Account = "UA-6111912-16"
    obj.NumEvents = 0
    obj.NumPlaybackEvents = 0

    obj.TrackEvent = analyticsTrackEvent
    obj.OnUrlEvent = analyticsOnUrlEvent
    obj.OnStartup = analyticsOnStartup
    obj.Cleanup = analyticsCleanup

    obj.CustomSessionVars = CreateObject("roArray", 5, false)
    obj.SetCustomSessionVar = analyticsSetCustomSessionVar

    obj.SetCustomSessionVar(1, "X-Plex-Product", "Plex for Roku")
    obj.SetCustomSessionVar(2, "X-Plex-Client-Identifier", GetGlobal("rokuUniqueID"))

    obj.FormatEvent = analyticsFormatEvent
    obj.FormatCustomVars = analyticsFormatCustomVars

    ' The URL is huge and terrible, but most of it is static. Build what we can
    ' now and just append the rest at the time of the event.

    encoder = CreateObject("roUrlTransfer")

    obj.BaseUrl = "http://www.google-analytics.com/__utm.gif"
    obj.BaseUrl = obj.BaseUrl + "?utmwv=1"
    obj.BaseUrl = obj.BaseUrl + "&utmsr=" + encoder.Escape(GetGlobal("DisplayMode") + " " + GetGlobal("DisplayType"))
    obj.BaseUrl = obj.BaseUrl + "&utmsc=24-bit"
    obj.BaseUrl = obj.BaseUrl + "&utmul=en-us"
    obj.BaseUrl = obj.BaseUrl + "&utmje=0"
    obj.BaseUrl = obj.BaseUrl + "&utmfl=-"
    obj.BaseUrl = obj.BaseUrl + "&utmdt=" + encoder.Escape(GetGlobal("appName"))
    obj.BaseUrl = obj.BaseUrl + "&utmp=" + encoder.Escape(GetGlobal("appName"))
    obj.BaseUrl = obj.BaseUrl + "&utmhn=clients.plexapp.com"
    obj.BaseUrl = obj.BaseUrl + "&utmr=-"
    obj.BaseUrl = obj.BaseUrl + "&utmvid=" + encoder.Escape(GetGlobal("rokuUniqueID"))

    ' Initialize our "cookies"
    domainHash = "1095529729" ' should be set by Google, but hardcode to something
    visitorID = RegRead("AnalyticsID", "analytics", invalid)
    if visitorID = invalid then
        visitorID = GARandNumber(1000000000,9999999999).ToStr()
        RegWrite("AnalyticsID", visitorID, "analytics")
    end if

    timestamp = CreateObject("roDateTime")
    firstTimestamp = RegRead("FirstTimestamp", "analytics", invalid)
    prevTimestamp = RegRead("PrevTimestamp", "analytics", invalid)
    curTimestamp = timestamp.asSeconds().ToStr()

    RegWrite("PrevTimestamp", curTimestamp, "analytics")
    if prevTimestamp = invalid then prevTimestamp = curTimestamp
    if firstTimestamp = invalid then
        RegWrite("FirstTimestamp", curTimestamp, "analytics")
        firstTimestamp = curTimestamp
    end if

    numSessions = RegRead("NumSessions", "analytics", "0").toint() + 1
    RegWrite("NumSessions", numSessions.ToStr(), "analytics")

    obj.BaseUrl = obj.BaseUrl + "&utmcc=__utma%3D" + domainHash + "." + visitorID + "." + firstTimestamp + "." + prevTimestamp + "." + curTimestamp + "." + numSessions.tostr()
    obj.BaseUrl = obj.BaseUrl + "%3B%2B__utmb%3D" + domainHash + ".0.10." + curTimestamp + "000"
    obj.BaseUrl = obj.BaseUrl + "%3B%2B__utmc%3D" + domainHash + ".0.10." + curTimestamp + "000"

    obj.SessionTimer = createTimer()

    return obj
End Function

Sub analyticsTrackEvent(category, action, label, value, customVars)
    ' Only if we're enabled
    if RegRead("analytics", "preferences", "1") <> "1" then return

    ' Now's a good time to update our session variables, in case we don't shut
    ' down cleanly.
    if category = "Playback" then m.NumPlaybackEvents = m.NumPlaybackEvents + 1
    RegWrite("session_duration", tostr(m.SessionTimer.GetElapsedSeconds()), "analytics")
    RegWrite("session_playback_events", tostr(m.NumPlaybackEvents), "analytics")

    m.NumEvents = m.NumEvents + 1

    request = CreateObject("roUrlTransfer")
    request.EnableEncodings(true)
    context = CreateObject("roAssociativeArray")
    context.requestType = "analytics"

    url = m.BaseUrl
    url = url + "&utms=" + m.NumEvents.tostr()
    url = url + "&utmn=" + GARandNumber(1000000000,9999999999).ToStr()   'Random Request Number
    url = url + "&utmac=" + m.Account
    url = url + "&utmt=event"
    url = url + "&utme=" + m.FormatEvent(category, action, label, value) + m.FormatCustomVars(customVars)

    Debug("Final analytics URL: " + url)
    request.SetUrl(url)

    GetViewController().StartRequest(request, m, context)
End Sub

Sub analyticsOnUrlEvent(msg, requestContext)
    ' Don't care about the response at all.
End Sub

Sub analyticsOnStartup(signedIn)
    lastSessionDuration = RegRead("session_duration", "analytics", "0").toint()
    if lastSessionDuration > 0 then
        lastSessionPlaybackEvents = RegRead("session_playback_events", "analytics", "0")
        m.TrackEvent("App", "Shutdown", "", lastSessionDuration, [invalid, invalid, {name: "NumEvents", value: lastSessionPlaybackEvents}])
    end if
    m.TrackEvent("App", "Start", "", 1, [invalid, invalid, {name: "Model", value: GetGlobal("rokuModel")}, {name: "myPlex", value: tostr(signedIn)}])
End Sub

Sub analyticsCleanup()
    ' Just note the session duration. We wrote the number of playback events the
    ' last time we got one, and we won't send the actual event until the next
    ' startup.
    RegWrite("session_duration", tostr(m.SessionTimer.GetElapsedSeconds()), "analytics")
    m.SessionTimer = invalid
End Sub

Sub analyticsSetCustomSessionVar(index, name, value)
    m.CustomSessionVars[index - 1] = {name: name, value: value}
End Sub

Function analyticsFormatEvent(category, action, label, value) As String
    encoder = CreateObject("roUrlTransfer")
    event = "5(" + encoder.Escape(category) + "*" + encoder.Escape(action)
    if label <> invalid then
        event = event + "*" + encoder.Escape(firstOf(label, ""))
    end if
    if value <> invalid then
        event = event + ")(" + tostr(value)
    end if
    event = event + ")"
    return event
End Function

Function analyticsFormatCustomVars(pageVars) As String
    encoder = CreateObject("roUrlTransfer")
    vars = CreateObject("roArray", 5, false)
    hasVar = false
    for i = 0 to 4
        vars[i] = firstOf(pageVars[i], m.CustomSessionVars[i])
        if vars[i] <> invalid then hasVar = true
    end for

    if NOT hasVar then return ""

    names = "8"
    values = "9"
    scopes = "11"
    skipped = false

    for i = 0 to vars.Count() - 1
        if vars[i] <> invalid then
            if i = 0 then
                prefix = "("
            else if skipped then
                prefix = i.tostr() + "!"
            else
                prefix = "*"
            end if

            names = names + prefix + encoder.Escape(firstOf(vars[i].name, ""))
            values = values + prefix + encoder.Escape(firstOf(vars[i].value, ""))

            if pageVars[i] <> invalid then
                scope = "3"
            else
                scope = "2"
            end if

            scopes = scopes + prefix + scope
        else
            skipped = true
        end if
    end for

    names = names + ")"
    values = values + ")"
    scopes = scopes + ")"

    return names + values + scopes
End Function

Function GARandNumber(num_min As Integer, num_max As Integer) As Integer
    Return (RND(0) * (num_max - num_min)) + num_min
End Function
