Function photoHandleMessage(msg) As Boolean
    server = m.Item.server

    if type(msg) = "roSlideShowEvent" then
        if msg.isPlaybackPosition() then
            'm.CurIndex = msg.GetIndex()
        else if msg.isRequestFailed() then
            Debug("preload failed:" + tostr(msg.GetIndex()))
        else if msg.isRequestInterrupted() then
            Debug("preload interrupted:" + tostr(msg.GetIndex()))
        else if msg.isPaused() then
            Debug("paused")
        else if msg.isResumed() then
            Debug("resumed")
        end if

        return true
    else if msg = invalid then
    else if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        Debug("Button command: " + tostr(buttonCommand))
        if buttonCommand = "show" then
            Debug("photoHandleMessage:: Show photo fullscreen")
            m.slideshow = m.CreateSlideShow()
            m.slideshow.AddContent(m.item)
            m.slideshow.SetNext(0, true)
            m.slideshow.Show()
        else if buttonCommand = "slideshow" then
            Debug("photoHandleMessage:: Start slideshow")
            m.slideshow = m.CreateSlideShow()
            m.slideshow.SetContentList(m.Context)
            m.slideshow.SetNext(m.CurIndex, true)
            m.slideshow.Show()
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
		    server.Rate(m.metadata.ratingKey, m.metadata.mediaContainerIdentifier,rateValue%.ToStr())
        else
            return false
        end if

        return true
    end if

    return false
End Function

Function photoAddButtons(obj) As Object
    screen = obj.Screen
    metadata = obj.metadata
    media = obj.media

    buttonCommands = CreateObject("roAssociativeArray")
    screen.ClearButtons()
    buttonCount = 0

    screen.AddButton(buttonCount, "Show")
    buttonCommands[str(buttonCount)] = "show"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Slideshow")
    buttonCommands[str(buttonCount)] = "slideshow"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Next Photo")
    buttonCommands[str(buttonCount)] = "next"
    buttonCount = buttonCount + 1

    screen.AddButton(buttonCount, "Previous Photo")
    buttonCommands[str(buttonCount)] = "prev"
    buttonCount = buttonCount + 1

    if metadata.UserRating = invalid then
        metadata.UserRating = 0
    endif
    if metadata.StarRating = invalid then
        metadata.StarRating = 0
    endif
    screen.AddRatingButton(buttonCount, metadata.UserRating, metadata.StarRating)
    buttonCommands[str(buttonCount)] = "ratePhoto"
    buttonCount = buttonCount + 1

    return buttonCommands
End Function

