Function photoHandleMessage(msg) As Boolean
    server = m.Item.server
    port = CreateObject("roMessagePort")

    if msg.isButtonPressed() then
        buttonCommand = m.buttonCommands[str(msg.getIndex())]
        print "Button command: ";buttonCommand
        if buttonCommand = "show" then
            Print "photoHandleMessage:: Show photo fullscreen"
            url = FullUrl(m.item.server.serverurl, m.item.sourceurl, m.item.media[0].parts[0].key)
            'Print "Url = ";url2
            slideshow = SlideShowSetup(port, 5.0, "#6b4226", 6)
            pl = CreateObject("roList")
            pl.Push(url)
            DisplaySlideShow(port, slideshow, pl)
        else if buttonCommand = "slideshow" then
            Print "photoHandleMessage:: Start slideshow"
            list = GetPhotoList(m.item.server.serverurl, m.item.sourceurl)
            slideshow = SlideShowSetup(port, 5.0, "#6b4226", 6)
            DisplaySlideShow(port, slideshow, list)
        else if buttonCommand = "next" then
            Print "photoHandleMessage:: show next photo"
             m.GotoNextItem()
        else if buttonCommand = "prev" then
            Print "photoHandleMessage:: show previous photo"
             m.GotoPrevItem()
	    else if buttonCommand = "ratePhoto" then                
            Print "photoHandleMessage:: Rate photo for key ";m.metadata.ratingKey
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

