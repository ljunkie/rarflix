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

    theme.RegistrationCodeColor = "#8B0000"

    theme.BackgroundColor = "#363636"
    theme.ButtonMenuNormalText = "#74777A"
    theme.GridScreenBackgroundColor = "#363636"
    theme.SpringboardTitleText = "#AAAEB3"
    theme.SpringboardArtistColor = "#74777A"
    theme.SpringboardAlbumColor = "#74777A"
    theme.SpringboardRuntimeColor = "#74777A"

    app.SetTheme(theme)

End Sub

