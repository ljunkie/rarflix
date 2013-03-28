'*
'* Create an object to interact with analytics backends, specifically Google
'* Analytics for now. While this object could be used to track anything, if
'* you're reading this then please note that nothing identifiable about what
'* you're watching is tracked. We're basically keeping track of how much
'* media of each type is being consumed (movie, music, photo), to allow us
'* to direct future focus most effectively. And you can always opt out.
'*
'* This class has been updated to use the new Universal Analytics, which has
'* an actual documented API.
'*

Function createAnalyticsTracker()
    obj = CreateObject("roAssociativeArray")

    ' We need a ScreenID property in order to use the view controller for requests.
    obj.ScreenID = -2

    obj.NumPlaybackEvents = 0

    obj.TrackEvent = analyticsTrackEvent
    obj.TrackScreen = analyticsTrackScreen
    obj.TrackTiming = analyticsTrackTiming
    obj.SendTrackingRequest = analyticsSendTrackingRequest
    obj.OnUrlEvent = analyticsOnUrlEvent
    obj.OnStartup = analyticsOnStartup
    obj.Cleanup = analyticsCleanup

    ' Much of the data that we need to submit is session based and can be built
    ' now. When we're tracking an indvidual hit we'll append the hit-specific
    ' variables.

    encoder = CreateObject("roUrlTransfer")

    uuid = RegRead("UUID", "analytics")
    if uuid = invalid then
        uuid = CreateUUID()
        RegWrite("UUID", uuid, "analytics")
    end if

    dimensionsObj = GetGlobal("DisplaySize")
    dimensions = tostr(dimensionsObj.w) + "x" + tostr(dimensionsObj.h)

    obj.BaseData = "v=1"
    obj.BaseData = obj.BaseData + "&tid=UA-6111912-18"
    obj.BaseData = obj.BaseData + "&cid=" + uuid
    obj.BaseData = obj.BaseData + "&sr=" + dimensions
    obj.BaseData = obj.BaseData + "&ul=en-us"
    obj.BaseData = obj.BaseData + "&cd1=" + encoder.Escape(GetGlobal("appName") + " for Roku")
    obj.BaseData = obj.BaseData + "&cd2=" + encoder.Escape(GetGlobal("rokuUniqueID"))
    obj.BaseData = obj.BaseData + "&cd3=Roku"
    obj.BaseData = obj.BaseData + "&cd4=" + encoder.Escape(GetGlobal("rokuVersionStr", "unknown"))
    obj.BaseData = obj.BaseData + "&cd5=" + encoder.Escape(GetGlobal("rokuModel"))
    obj.BaseData = obj.BaseData + "&cd6=" + encoder.Escape(GetGlobal("appVersionStr"))
    obj.BaseData = obj.BaseData + "&an=" + encoder.Escape(GetGlobal("appName") + " for Roku")
    obj.BaseData = obj.BaseData + "&av=" + encoder.Escape(GetGlobal("appVersionStr"))

    numSessions = RegRead("NumSessions", "analytics", "0").toint() + 1
    RegWrite("NumSessions", numSessions.ToStr(), "analytics")

    obj.SessionTimer = createTimer()

    return obj
End Function

Sub analyticsTrackEvent(category, action, label, value, customVars={})
    ' Now's a good time to update our session variables, in case we don't shut
    ' down cleanly.
    if category = "Playback" then m.NumPlaybackEvents = m.NumPlaybackEvents + 1
    RegWrite("session_duration", tostr(m.SessionTimer.GetElapsedSeconds()), "analytics")
    RegWrite("session_playback_events", tostr(m.NumPlaybackEvents), "analytics")

    customVars["t"] = "event"
    customVars["ec"] = category
    customVars["ea"] = action
    customVars["el"] = label
    customVars["ev"] = tostr(value)

    m.SendTrackingRequest(customVars)
End Sub

Sub analyticsTrackScreen(screenName, customVars={})
    customVars["t"] = "appview"
    customVars["cd"] = screenName

    m.SendTrackingRequest(customVars)
End Sub

Sub analyticsTrackTiming(time, category, variable, label, customVars={})
    customVars["t"] = "timing"
    customVars["utc"] = category
    customVars["utv"] = variable
    customVars["utl"] = label
    customVars["utt"] = tostr(time)

    m.SendTrackingRequest(customVars)
End Sub

Sub analyticsSendTrackingRequest(vars)
    ' Only if we're enabled
    if RegRead("analytics", "preferences", "1") <> "1" then return

    request = CreateObject("roUrlTransfer")
    request.EnableEncodings(true)
    request.SetUrl("http://www.google-analytics.com/collect")
    context = CreateObject("roAssociativeArray")
    context.requestType = "analytics"

    data = m.BaseData
    for each name in vars
        data = data + "&" + name + "=" + request.Escape(vars[name])
    next

    Debug("Final analytics data: " + data)

    GetViewController().StartRequest(request, m, context, data)
End Sub

Sub analyticsOnUrlEvent(msg, requestContext)
    ' Don't care about the response at all.
End Sub

Sub analyticsOnStartup(signedIn)
    lastSessionDuration = RegRead("session_duration", "analytics", "0").toint()
    if lastSessionDuration > 0 then
        lastSessionPlaybackEvents = RegRead("session_playback_events", "analytics", "0")
        m.TrackEvent("App", "Shutdown", "", lastSessionDuration, {cm1: lastSessionPlaybackEvents})
    end if
    m.TrackEvent("App", "Start", "", 1, {sc: "start"})
End Sub

Sub analyticsCleanup()
    ' Just note the session duration. We wrote the number of playback events the
    ' last time we got one, and we won't send the actual event until the next
    ' startup.
    RegWrite("session_duration", tostr(m.SessionTimer.GetElapsedSeconds()), "analytics")
    m.SessionTimer = invalid
End Sub

' This isn't a "real" UUID, but it should at least be random and look like one.
Function CreateUUID()
    uuid = ""
    for each numChars in [8, 4, 4, 4, 12]
        if Len(uuid) > 0 then uuid = uuid + "-"
        for i=1 to numChars
            o = Rnd(16)
            if o <= 10
                o = o + 47
            else
                o = o + 96 - 10
            end if
            uuid = uuid + Chr(o)
        end for
    next
    return uuid
End Function
