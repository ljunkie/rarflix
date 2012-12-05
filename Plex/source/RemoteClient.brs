'*
'* An implementation of the remote client/player interface that allows the Roku
'* to be controlled by other Plex clients, like the remote built into the
'* iOS/Android apps.
'*

Function ProcessPlayMediaRequest() As Boolean
    ' Note that we're evaluated in the context of a Reply object.

    if RegRead("remotecontrol", "preferences", "1") <> "1" then
        m.default(404, "Remote control is disabled for this device")
        return true
    end if

    Debug("Processing PlayMedia request")
    for each name in m.request.fields
        Debug("  " + name + ": " + UrlUnescape(m.request.fields[name]))
    next

    ' Fetch the container for the path and then look for a matching key. This
    ' allows us to set the context correctly so we can do things like play an
    ' entire album or slideshow.

    url = UrlUnescape(m.request.fields["X-Plex-Arg-Path"])
    key = UrlUnescape(m.request.fields["X-Plex-Arg-Key"])

    server = GetServerForUrl(url)
    if server = invalid then
        Debug("Not sure which server to use for " + tostr(url) + ", falling back to primary")
        server = GetPrimaryServer()
    end if

    container = createPlexContainerForUrl(server, url, "")
    children = container.GetMetadata()
    matchIndex = invalid
    for i = 0 to children.Count() - 1
        item = children[i]
        if key = item.key then
            matchIndex = i
            exit for
        end if
    end for

    if matchIndex <> invalid then
        if m.request.fields.DoesExist("X-Plex-Arg-ViewOffset") then
            seek = m.request.fields["X-Plex-Arg-ViewOffset"].toint()
        else
            seek = 0
        end if

        GetViewController().CreatePlayerForItem(children, matchIndex, seek)

        m.http_code = 200
    else
        Debug("Unable to find matching item for key")
        m.http_code = 404
    end if

    ' Always return an empty body
    body = ""
    m.buf.fromasciistring(body)
    m.length = m.buf.count()
    m.genHdr(true)
    m.source = m.GENERATED

    return true
End Function
