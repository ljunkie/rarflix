'*
'* Metadata objects for photo data
'*

Function createBasePhotoMetadata(container, item) As Object
    metadata = createBaseMetadata(container, item)

    metadata.ratingKey = item@ratingKey

    ' We never need to fetch and parse additional details for audio metadata
    metadata.HasDetails = True

    return metadata
End Function

Function newPhotoMetadata(container, item, detailed=true) As Object
    photo = createBasePhotoMetadata(container, item)

    photo.Title = item@title
    photo.mediaContainerIdentifier = container.xml@identifier
    photo.ContentType = "photo"
    if photo.Type = invalid then photo.Type = "photo"

    Print "item = ";item
    Print "photo = ";photo

    return photo
End Function
