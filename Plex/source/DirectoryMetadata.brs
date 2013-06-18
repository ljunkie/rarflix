
Function newDirectoryMetadata(container, item) As Object
    directory = createBaseMetadata(container, item)

    directory.ContentType = item@type
    if directory.ContentType = "show" then
        directory.Rating = item@contentRating
        directory.ContentType = "series"
        directory.Theme = item@theme
    else if directory.ContentType = invalid then
        directory.ContentType = "appClip"
    endif

    directory.MachineID = item@machineIdentifier
    directory.Owned = item@owned

    if item@machineIdentifier <> invalid AND item@path <> invalid
        directory.key = item@path
    end if

    return directory
End Function

