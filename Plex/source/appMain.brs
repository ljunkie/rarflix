' ********************************************************************
' **  Entry point for the Plex client. Configurable themes etc. haven't been yet.
' **
' ********************************************************************

Sub Main()
	' Development statements
	' RemoveAllServers()
	' AddServer("iMac", "http://192.168.1.3:32400")

    'initialize theme attributes like titles, logos and overhang color
    initTheme()

    'prepare the screen for display and get ready to begin
    controller = createViewController()
    controller.ShowHomeScreen()
End Sub


'*************************************************************
'** Set the configurable theme attributes for the application
'** 
'** Configure the custom overhang and Logo attributes
'** Theme attributes affect the branding of the application
'** and are artwork, colors and offsets specific to the app
'*************************************************************

Sub initTheme()

    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")

    theme.OverhangOffsetSD_X = "72"
    theme.OverhangOffsetSD_Y = "10"
    theme.OverhangSliceSD = "pkg:/images/Background_SD.jpg"
    theme.OverhangLogoSD  = "pkg:/images/logo_final_SD.png"

    theme.OverhangOffsetHD_X = "125"
    theme.OverhangOffsetHD_Y = "10"
    theme.OverhangSliceHD = "pkg:/images/Background_HD.jpg"
    theme.OverhangLogoHD  = "pkg:/images/logo_final_HD.png"

    theme.GridScreenLogoOffsetHD_X = "125"
    theme.GridScreenLogoOffsetHD_Y = "10"
    theme.GridScreenOverhangSliceHD = "pkg:/images/Background_HD.jpg"
    theme.GridScreenLogoHD  = "pkg:/images/logo_final_HD.png"
    theme.GridScreenOverhangHeightHD = "99"

    theme.GridScreenLogoOffsetSD_X = "72"
    theme.GridScreenLogoOffsetSD_Y = "10"
    theme.GridScreenOverhangSliceSD = "pkg:/images/Background_SD.jpg"
    theme.GridScreenLogoSD  = "pkg:/images/logo_final_SD.png"
    theme.GridScreenOverhangHeightSD = "66"

    ' We want to use a dark background throughout, just like the default
    ' grid. Unfortunately that means we need to change all sorts of stuff.
    ' The general idea is that we have a small number of colors for text
    ' and try to set them appropriately for each screen type.

    background = "#363636"
    titleText = "#BFBFBF"
    normalText = "#999999"
    detailText = "#74777A"
    subtleText = "#525252"

    theme.BackgroundColor = background

    theme.GridScreenBackgroundColor = background
    theme.GridScreenRetrievingColor = subtleText
    theme.GridScreenListNameColor = titleText
    theme.CounterTextLeft = titleText
    theme.CounterSeparator = normalText
    theme.CounterTextRight = normalText
    ' Defaults for all GridScreenDescriptionXXX

    theme.ListScreenHeaderText = titleText
    theme.ListItemText = normalText
    theme.ListItemHighlightText = titleText
    ' Other roListScreen attrs a mystery...

    theme.ParagraphHeaderText = titleText
    theme.ParagraphBodyText = normalText

    theme.ButtonNormalColor = normalText
    ' Default for ButtonHighlightColor seems OK...

    theme.RegistrationCodeColor = "#FFA500"
    theme.RegistrationFocalColor = normalText

    theme.SearchHeaderText = titleText
    theme.ButtonMenuHighlightText = titleText
    theme.ButtonMenuNormalText = titleText

    theme.PosterScreenLine1Text = titleText
    theme.PosterScreenLine2Text = normalText

    theme.SpringboardTitleText = titleText
    theme.SpringboardArtistColor = titleText
    theme.SpringboardArtistLabelColor = detailText
    theme.SpringboardAlbumColor = titleText
    theme.SpringboardAlbumLabelColor = detailText
    theme.SpringboardRuntimeColor = normalText
    theme.SpringboardActorColor = titleText
    theme.SpringboardDirectorColor = titleText
    theme.SpringboardDirectorLabel = detailText
    theme.SpringboardGenreColor = normalText
    theme.SpringboardSynopsisColor = normalText

    ' Not sure these are actually used, but they should probably be normal
    theme.SpringboardSynopsisText = normalText
    theme.EpisodeSynopsisText = normalText

    app.SetTheme(theme)

End Sub

