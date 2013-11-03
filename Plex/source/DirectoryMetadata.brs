' ljunkie - directory key from XML is parsed here - this is where RokuPlex get's is RowList
Function newDirectoryMetadata(container, item) As Object
    directory = createBaseMetadata(container, item)

    directory.ContentType = item@type
    if directory.ContentType = "show" then
        directory.Rating = item@contentRating
        directory.ContentType = "series"
        directory.Theme = item@theme
    else if directory.ContentType = "photo" and container.xml@librarySectionID <> invalid then
        ' ljunkie - for the photos sections, it gets confusing if the item actually a PHOTO or a Sub Directory
        ' lets prepend "Dir: " to the title of the item - also include part of the directory structure in the description
        directory.Description = ""
        if container.xml@grandparentTitle <> invalid then directory.Description = container.xml@grandparentTitle + "/"
        directory.Description = directory.Description + firstof( container.xml@title2, container.xml@parentTitle, "") + "/" + directory.Title
        directory.Title = "Dir: " + directory.Title
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

