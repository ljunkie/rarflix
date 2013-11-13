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
        obj.TIMELINE_TYPES = ["video", "music", "photo"]

        ' Members
        obj.subscribers = CreateObject("roAssociativeArray")
        obj.timelines = CreateObject("roAssociativeArray")
        obj.location = obj.NAVIGATION

        ' Functions
        obj.UpdateCommandID = nowPlayingUpdateCommandID
        obj.AddSubscriber = nowPlayingAddSubscriber
        obj.RemoveSubscriber = nowPlayingRemoveSubscriber
        obj.SendTimelineToSubscriber = nowPlayingSendTimelineToSubscriber
        obj.SendTimelineToServer = nowPlayingSendTimelineToServer
        obj.SendTimelineToAll = nowPlayingSendTimelineToAll
        obj.CreateTimelineDataXml = nowPlayingCreateTimelineDataXml
        obj.UpdatePlaybackState = nowPlayingUpdatePlaybackState

        ' Initialization
        for each timelineType in obj.TIMELINE_TYPES
            obj.timelines[timelineType] = TimelineData(timelineType)
        next

        ' Singleton
        m.NowPlayingManager = obj
    end if

    return m.NowPlayingManager
End Function

Function TimelineData(timelineType As String)
    obj = CreateObject("roAssociativeArray")

    obj.type = timelineType
    obj.state = "stopped"
    obj.item = invalid

    obj.attrs = CreateObject("roAssociativeArray")

    obj.ToQueryString = timelineDataToQueryString
    obj.ToXmlAttributes = timelineDataToXmlAttributes

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

Sub nowPlayingUpdateCommandID(deviceID, commandID)
    subscriber = m.subscribers[deviceID]
    if subscriber <> invalid then
        subscriber.commandID = validint(commandID)
    end if
End Sub

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

Sub nowPlayingSendTimelineToSubscriber(subscriber, xml=invalid)
    if xml = invalid then
        xml = m.CreateTimelineDataXml()
    end if

    xml.AddAttribute("commandID", tostr(subscriber.commandID))

    url = subscriber.connectionUrl + "/:/timeline"
    StartRequestIgnoringResponse(url, xml.GenXml(false))
End Sub

Sub nowPlayingSendTimelineToServer(timelineType, server)
End Sub

Sub nowPlayingSendTimelineToAll()
    m.subscribers.Reset()
    if m.subscribers.IsNext() then
        xml = m.CreateTimelineDataXml()
    end if
    expiredSubscribers = CreateObject("roList")

    for each id in m.subscribers
        subscriber = m.subscribers[id]
        if subscriber.SubscriptionTimer.IsExpired() then
            expiredSubscribers.AddTail(id)
        else
            m.SendTimelineToSubscriber(subscriber, xml)
        end if
    next

    for each id in expiredSubscribers
        m.subscribers.Delete(id)
    next
End Sub

Sub nowPlayingUpdatePlaybackState(timelineType, item, state, time)
    timeline = m.timelines[timelineType]
    timeline.state = state
    timeline.item = item
    timeline.attrs["time"] = tostr(time)

    m.SendTimelineToAll()
End Sub

Function nowPlayingCreateTimelineDataXml()
    mc = CreateObject("roXMLElement")
    mc.SetName("MediaContainer")
    mc.AddAttribute("location", m.location)

    for each timelineType in m.TIMELINE_TYPES
        timeline = mc.AddElement("Timeline")
        m.timelines[timelineType].ToXmlAttributes(timeline)
    next

    return mc
End Function

Function timelineDataToQueryString()
    return ""
End Function

Sub timelineDataToXmlAttributes(elem)
    elem.AddAttribute("type", m.type)
    elem.AddAttribute("state", m.state)

    if m.item <> invalid then
        addAttributeIfValid(elem, "duration", m.item.RawLength)
        addAttributeIfValid(elem, "ratingKey", m.item.ratingKey)
        addAttributeIfValid(elem, "key", m.item.key)
        addAttributeIfValid(elem, "containerKey", m.item.sourceUrl)

        server = m.item.server
        if server <> invalid then
            elem.AddAttribute("machineIdentifier", server.machineID)
            parts = server.serverUrl.tokenize(":")
            elem.AddAttribute("protocol", parts.RemoveHead())
            elem.AddAttribute("address", Mid(parts.RemoveHead(), 3))
            elem.AddAttribute("port", parts.RemoveHead())
        end if
    end if

    for each key in m.attrs
        elem.AddAttribute(key, m.attrs[key])
    next
End Sub

Sub addAttributeIfValid(elem, name, value)
    if value <> invalid then
        elem.AddAttribute(name, tostr(value))
    end if
End Sub

Sub StartRequestIgnoringResponse(url, body=invalid, contentType="xml")
    request = CreateURLTransferObject(url)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")

    if body <> invalid then
        ' TODO(schuyler): Remove this
        Debug("Sending timeline information:")
        Debug(body)
        request.AddHeader("Content-Type", MimeType(contentType))
    end if

    context = CreateObject("roAssociativeArray")
    context.requestType = "ignored"

    GetViewController().StartRequest(request, invalid, context, body)
End Sub
