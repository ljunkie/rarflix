'*
'* An object representing a container fetched from a PMS. All of the fetching
'* and parsing of data is handled here. The XML is only parsed once, so
'* sequential calls to things like GetNames and GetKeys should be fast.
'*

Function createPlexContainerForXml(xmlResponse) As Object
    c = CreateObject("roAssociativeArray")

    c.server = xmlResponse.server
    c.sourceUrl = xmlResponse.sourceUrl
    c.xml = xmlResponse.xml

    c.ParseXml = containerParseXml
    c.GetNames = containerGetNames
    c.GetKeys = containerGetKeys
    c.GetMetadata = containerGetMetadata
    c.Count = containerCount

    c.ParseDetails = false

    c.ViewGroup = c.xml@viewGroup

    c.names = []
    c.keys = []
    c.metadata = []
    c.Parsed = false

    return c
End Function

Function createPlexContainerForUrl(server, baseUrl, key) As Object
    responseXml = server.GetQueryResponse(baseUrl, key)
    return createPlexContainerForXml(responseXml)
End Function

Function createFakePlexContainer(server, names, keys) As Object
    c = CreateObject("roAssociativeArray")

    c.server = server
    c.sourceUrl = ""
    c.names = names
    c.keys = keys
    c.Parsed = true

    c.GetNames = containerGetNames
    c.GetKeys = containerGetKeys

    return c
End Function

Sub containerParseXml()
    if m.Parsed then return

    nodes = m.xml.GetChildElements()
    for each n in nodes
        'Print "Processing node of type "; n@type; " and view group: "; m.ViewGroup
        'Print "Node name = ";n.GetName()

        nodeType = firstOf(n@type, m.ViewGroup)

        if n@scanner <> invalid then
            metadata = newDirectoryMetadata(m, n)
            metadata.contentType = "section"
        else if nodeType = "artist" then
            metadata = newArtistMetadata(m, n, m.ParseDetails)
        else if nodeType = "album" then
            metadata = newAlbumMetadata(m, n, m.ParseDetails)
        else if nodeType = "Store:Info" then
            metadata = newChannelMetadata(m, n)
        else if n.GetName() = "Directory" then
            metadata = newDirectoryMetadata(m, n)
        else if nodeType = "movie" OR nodeType = "episode" then
            metadata = newVideoMetadata(m, n, m.ParseDetails)
        else if nodeType = "track" then
            metadata = newTrackMetadata(m, n, m.ParseDetails)
        else if nodeType = "photo" then
            metadata = newPhotoMetadata(m, n, m.ParseDetails)
        else
            metadata = newDirectoryMetadata(m, n)
        end if

        ' Ignore search nodes for now...
        if n@search <> "1" then
            m.metadata.Push(metadata)
            m.names.Push(metadata.Title)
            m.keys.Push(metadata.Key)
        end if
    next

    m.Parsed = true
End Sub

Function containerGetNames()
    if NOT m.Parsed then m.ParseXml()

    return m.names
End Function

Function containerGetKeys()
    if NOT m.Parsed then m.ParseXml()

    return m.keys
End Function

Function containerGetMetadata()
    if NOT m.Parsed then m.ParseXml()

    return m.metadata
End Function

Function containerCount()
    if NOT m.Parsed then m.ParseXml()

    return m.metadata.Count()
End Function
