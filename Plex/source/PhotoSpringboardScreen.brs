Function itemIsPhoto(item) As Boolean
    return item <> invalid AND item.NodeName = "Photo"
End Function

Function createPhotoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController, itemIsPhoto)

    obj.screen.SetDisplayMode("photo-fit") 
    obj.screen.SetPosterStyle("rounded-rect-16x9-generic") ' makes more sense for photos (opt2: rounded-square-generic)
    obj.SetupButtons = photoSetupButtons
    obj.GetMediaDetails = photoGetMediaDetails

    obj.superHandleMessage = obj.HandleMessage
    obj.HandleMessage = photoHandleMessage

    return obj
End Function

Sub photoSetupButtons()
    m.ClearButtons()

   if m.metadata.starrating = invalid then 'ljunkie - don't show starts if invalid
        m.Screen.SetStaticRatingEnabled(false)
   end if

    m.AddButton("Show", "show")
    m.AddButton("Slideshow", "slideshow")
    m.AddButton("Next Photo", "next")
    m.AddButton("Previous Photo", "prev")

    if m.metadata.UserRating = invalid then
        m.metadata.UserRating = 0
    endif
    if m.metadata.StarRating = invalid then
        m.metadata.StarRating = 0
    endif
    if m.metadata.origStarRating = invalid then
        m.metadata.origStarRating = 0
    endif

    ' When delete is present, put delete and rate in a separate dialog.
    if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
        m.AddButton("More...", "more")
    else
        m.AddRatingButton(m.metadata.UserRating, m.metadata.origStarRating, "ratePhoto")
    end if
End Sub

Sub photoGetMediaDetails(content)
    ' ljunkie - refresh exif for descriptions ( we lazy load this on the grid )
    if content.ExifSBloaded = invalid then
        description = getExifData(content,false)
        if description <> invalid then
            content.description = description
            content.ExifSBloaded = true ' make sure we don't load it again
        end if
    end if

    m.metadata = content
    m.media = invalid
End Sub

Function photoHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roSpringboardScreenEvent" then
        if msg.isButtonPressed() then
            handled = true
            buttonCommand = m.buttonCommands[str(msg.getIndex())]
            Debug("Button command: " + tostr(buttonCommand))
            if buttonCommand = "show" then
                Debug("photoHandleMessage:: Show photo fullscreen")
                m.ViewController.CreatePhotoPlayer(m.Item)
            else if buttonCommand = "slideshow" then
                ' Playing Photos from springBoard in a FULL grid context
                GetContextFromFullGrid(m,m.focusedIndex) 
		if m.context.count() = 0 then
                    ShowErrorDialog("Sorry! We were unable to load your photos.","Warning")
                else 
                    Debug("photoHandleMessage:: springboard Start slideshow with " + tostr(m.context.count()) + " items")
                    Debug("starting at index: " + tostr(m.curindex))
                    m.ViewController.CreatePhotoPlayer(m.Context, m.CurIndex, true, m.IsShuffled)
                end if
            else if buttonCommand = "next" then
                Debug("photoHandleMessage:: show next photo")
                 m.GotoNextItem()
            else if buttonCommand = "prev" then
                Debug("photoHandleMessage:: show previous photo")
                 m.GotoPrevItem()
            else if buttonCommand = "ratePhoto" then
                Debug("photoHandleMessage:: Rate photo for key " + tostr(m.metadata.ratingKey))
                rateValue% = (msg.getData() /10)
                m.metadata.UserRating = msg.getdata()
                if m.metadata.ratingKey = invalid then
                    m.metadata.ratingKey = 0
                end if
                m.Item.server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
            else if buttonCommand = "more" then
                dialog = createBaseDialog()
                dialog.Title = ""
                dialog.Text = ""
                dialog.Item = m.metadata
                if m.IsShuffled then
                    dialog.SetButton("shuffle", "Shuffle: On")
                else
                    dialog.SetButton("shuffle", "Shuffle: Off")
                end if
                dialog.SetButton("rate", "_rate_")
                if m.metadata.server.AllowsMediaDeletion AND m.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
                    dialog.SetButton("delete", "Delete permanently")
                end if
                dialog.SetButton("close", "Back")
                dialog.HandleButton = photoDialogHandleButton
                dialog.ParentScreen = m
                dialog.Show()
            else
                handled = false
            end if
        end if
    end if

    return handled OR m.superHandleMessage(msg)
End Function

Function photoDialogHandleButton(command, data) As Boolean
    ' We're evaluated in the context of the dialog, but we want to be in
    ' the context of the original screen.
    obj = m.ParentScreen

    if command = "delete" then
        obj.metadata.server.delete(obj.metadata.key)
        obj.closeOnActivate = true
        return true
    else if command = "shuffle" then
        if obj.IsShuffled then
            obj.Unshuffle()
            obj.IsShuffled = false
            m.SetButton(command, "Shuffle: Off")
        else
            obj.Shuffle()
            obj.IsShuffled = true
            m.SetButton(command, "Shuffle: On")
        end if
        m.Refresh()
    else if command = "rate" then
        Debug("photoHandleMessage:: Rate audio for key " + tostr(obj.metadata.ratingKey))
        rateValue% = (data /10)
        obj.metadata.UserRating = data
        if obj.metadata.ratingKey <> invalid then
            obj.Item.server.Rate(obj.metadata.ratingKey, obj.metadata.mediaContainerIdentifier, rateValue%.ToStr())
        end if
    else if command = "close" then
        return true
    end if
    return false
End Function
