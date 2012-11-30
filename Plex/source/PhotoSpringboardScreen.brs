Function itemIsPhoto(item) As Boolean
    return item.NodeName = "Photo"
End Function

Function createPhotoSpringboardScreen(context, index, viewController) As Object
    obj = createBaseSpringboardScreen(context, index, viewController, itemIsPhoto)

    obj.SetupButtons = photoSetupButtons
    obj.GetMediaDetails = photoGetMediaDetails

    obj.superHandleMessage = obj.HandleMessage
    obj.HandleMessage = photoHandleMessage

    return obj
End Function

Sub photoSetupButtons()
    m.buttonCommands = CreateObject("roAssociativeArray")
    m.Screen.ClearButtons()
    buttonCount = 0

    m.Screen.AddButton(buttonCount, "Show")
    m.buttonCommands[str(buttonCount)] = "show"
    buttonCount = buttonCount + 1

    m.Screen.AddButton(buttonCount, "Slideshow")
    m.buttonCommands[str(buttonCount)] = "slideshow"
    buttonCount = buttonCount + 1

    m.Screen.AddButton(buttonCount, "Next Photo")
    m.buttonCommands[str(buttonCount)] = "next"
    buttonCount = buttonCount + 1

    m.Screen.AddButton(buttonCount, "Previous Photo")
    m.buttonCommands[str(buttonCount)] = "prev"
    buttonCount = buttonCount + 1

    if m.metadata.UserRating = invalid then
        m.metadata.UserRating = 0
    endif
    if m.metadata.StarRating = invalid then
        m.metadata.StarRating = 0
    endif
    m.Screen.AddRatingButton(buttonCount, m.metadata.UserRating, m.metadata.StarRating)
    m.buttonCommands[str(buttonCount)] = "ratePhoto"
    buttonCount = buttonCount + 1
End Sub

Sub photoGetMediaDetails(content)
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
                Debug("photoHandleMessage:: Start slideshow")
                m.ViewController.CreatePhotoPlayer(m.Context, m.CurIndex)
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
            else
                handled = false
            end if
        end if
    end if

    return handled OR m.superHandleMessage(msg)
End Function
