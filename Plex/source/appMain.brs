' ********************************************************************
' **  Entry point for the Plex client. Configurable themes etc. haven't been yet.
' **
' ********************************************************************

Sub Main(args)
    ' Process any launch args (set registry values)
    for each arg in args
        if Left(arg, 5) = "pref!" then
            pref = Mid(arg, 6)
            value = args[arg]
            Debug("Setting preference from launch param: " + pref + " = " + value)
            if value <> "" then
                RegWrite(pref, value, "preferences")
            else
                RegDelete(pref, "preferences")
            end if
        end if
    next

    ' If necessary, restore the direct play preference. It's possible for a
    ' temporary value to persist if the video player crashes.
    directPlay = RegRead("directplay_restore", "preferences")
    if directPlay <> invalid then
        Debug("Restoring direct play options to: " + tostr(directPlay))
        RegWrite("directplay", directPlay, "preferences")
        RegDelete("directplay_restore", "preferences")
    end if

    'initialize theme attributes like titles, logos and overhang color
    initTheme()

    initGlobals()

    'prepare the screen for display and get ready to begin
    controller = createViewController()
    controller.ShowHomeScreen()
End Sub

Sub initGlobals()
    device = CreateObject("roDeviceInfo")

    version = device.GetVersion()
    major = Mid(version, 3, 1).toInt()
    minor = Mid(version, 5, 2).toInt()
    build = Mid(version, 8, 5).toInt()
    versionStr = major.toStr() + "." + minor.toStr() + " build " + build.toStr()

    GetGlobalAA().AddReplace("rokuVersionStr", versionStr)
    GetGlobalAA().AddReplace("rokuVersionArr", [major, minor, build])

    Debug("Roku version: " + versionStr + " (" + version + ")")

    manifest = ReadAsciiFile("pkg:/manifest")
    lines = manifest.Tokenize(chr(10))
    aa = {}
    for each line in lines
        entry = line.Tokenize("=")
        aa.AddReplace(entry[0], entry[1])
    next

    appVersion = firstOf(aa["version"], "Unknown")
    GetGlobalAA().AddReplace("appVersionStr", appVersion)

    Debug("App version: " + appVersion)

    knownModels = {}
    knownModels["N1050"] = "Roku SD"
    knownModels["N1000"] = "Roku HD"
    knownModels["N1100"] = "Roku HD"
    knownModels["2000C"] = "Roku HD"
    knownModels["2050N"] = "Roku XD"
    knownModels["2050X"] = "Roku XD"
    knownModels["N1101"] = "Roku XD|S"
    knownModels["2100X"] = "Roku XD|S"
    knownModels["2400X"] = "Roku LT"
    knownModels["2450X"] = "Roku LT"
    knownModels["3000X"] = "Roku 2 HD"
    knownModels["3050X"] = "Roku 2 XD"
    knownModels["3100X"] = "Roku 2 XS"

    model = firstOf(knownModels[device.GetModel()], "Roku " + device.GetModel())
    GetGlobalAA().AddReplace("rokuModel", model)

    Debug("Roku model: " + model)

    GetGlobalAA().AddReplace("rokuUniqueID", device.GetDeviceUniqueId())

    ' The Roku 1 doesn't seem to like anamorphic videos. It stretches them
    ' vertically and squishes them horizontally. We should try not to Direct
    ' Play these videos, and tell the transcoder that we don't support them.
    ' It doesn't appear to matter how the Roku is configured, even if the
    ' display type is set to 16:9 Anamorphic the videos are distorted.
    ' On the Roku 2, support was somewhat murkier, but 4.8 is intended to
    ' fix things.

    Debug("Display type: " + tostr(device.GetDisplayType()))

    playsAnamorphic = major > 4 OR (major = 4 AND (minor >= 8 OR device.GetDisplayType() = "HDTV"))
    Debug("Anamorphic support: " + tostr(playsAnamorphic))
    GetGlobalAA().AddReplace("playsAnamorphic", playsAnamorphic)

    ' Support for ReFrames seems mixed. These numbers could be wrong, but
    ' there are reports that the Roku 1 can't handle more than 5 ReFrames,
    ' and testing has shown that the video is black beyond that point. The
    ' Roku 2 has been observed to play all the way up to 16 ReFrames, but
    ' on at least one test video there were noticeable artifacts as the
    ' number increased, starting with 8.
    if major >= 4 then
        GetGlobalAA().AddReplace("maxRefFrames", 8)
    else
        GetGlobalAA().AddReplace("maxRefFrames", 5)
    end if
End Sub

Function GetGlobal(var, default=invalid)
    return firstOf(GetGlobalAA().Lookup(var), default)
End Function


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

    ' The actual focus border is set by the grid based on the style
    theme.GridScreenBorderOffsetHD = "(-9,-9)"
    theme.GridScreenBorderOffsetSD = "(-9,-9)"

    theme.ListScreenHeaderText = titleText
    theme.ListItemText = normalText
    theme.ListItemHighlightText = titleText
    theme.ListScreenDescriptionText = normalText

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

