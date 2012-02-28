'*
'* Metadata object for channels
'*

Function newChannelMetadata(container, item) As Object
    metadata = createBaseMetadata(container, item)

    metadata.popup = (item@popup = "1")
    metadata.installed = (item@installed = "1")
    metadata.FullDescription = item@summary

    metadata.Type = "channel"
    metadata.ContentType = "channel"

    ' We never need to fetch and parse additional details for channels
    metadata.HasDetails = True

    return metadata
End Function

