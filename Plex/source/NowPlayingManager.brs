'*
'* Manage state about what is currently playing, who is currently subscribed
'* to that information, and sending timeline information to subscribers.
'*

Function NowPlayingManager()
    if m.NowPlayingManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.NAVIGATION = "navigation"
        obj.FULLSCREEN_VIDEO = "fullScreenVideo"
        obj.FULLSCREEN_MUSIC = "fullScreenMusic"
        obj.FULLSCREEN_PHOTO = "fullScreenPhoto"

        ' Members
        obj.subscribers = CreateObject("roAssociativeArray")
        obj.timelines = CreateObject("roAssociativeArray")
        obj.location = obj.NAVIGATION

        ' Functions
        obj.AddSubscriber = nowPlayingAddSubscriber
        obj.RemoveSubscriber = nowPlayingRemoveSubscriber
        obj.SendTimelineToSubscriber = nowPlayingSendTimelineToSubscriber
        obj.SendTimelineToServer = nowPlayingSendTimelineToServer

        ' Initialization
        obj.timelines.video = TimelineData("video")
        obj.timelines.music = TimelineData("music")
        obj.timelines.photo = TimelineData("photo")

        ' Singleton
        m.NowPlayingManager = obj
    end if

    return m.NowPlayingManager
End Function

Function TimelineData(timelineType As String)
    obj = CreateObject("roAssociativeArray")

    obj.type = timelineType

    return obj
End Function

Function NowPlayingSubscriber(deviceID, connectionUrl, commandID)
    obj = CreateObject("roAssociativeArray")

    obj.deviceID = deviceID
    obj.connectionUrl = connectionUrl
    obj.commandID = validint(commandID)

    obj.SubscriptionTimer = createTimer()
    obj.SubscriptionTimer.SetDuration(90000)

    return obj
End Function

Function nowPlayingAddSubscriber(deviceID, connectionUrl, commandID) As Boolean
    if firstOf(deviceID, "") = "" then
        Debug("Now Playing: received subscribe without an identifier")
        return false
    end if

    subscriber = m.subscribers[deviceID]

    if subscriber = invalid then
        Debug("Now Playing: New subscriber " + deviceID + " at " + tostr(connectionUrl) + " with command id " + tostr(commandID))
        subscriber = NowPlayingSubscriber(deviceID, connectionUrl, commandID)
        m.subscribers[deviceID] = subscriber
    end if

    subscriber.SubscriptionTimer.Mark()

    m.SendTimelineToSubscriber(subscriber)

    return true
End Function

Sub nowPlayingRemoveSubscriber(deviceID)
    if deviceID <> invalid then
        Debug("Now Playing: Removing subscriber " + deviceID)
        m.subscribers.Delete(deviceID)
    end if
End Sub

Sub nowPlayingSendTimelineToSubscriber(subscriber)
End Sub

Sub nowPlayingSendTimelineToServer(timelineType, server)
End Sub
