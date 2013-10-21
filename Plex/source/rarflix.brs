'* Rob Reed: Cast and Crew functions
'*  
'* misc rarflix function
'*

' other functions required for my mods

function isRFdev() as boolean
    ' dev only
    if GetGlobalAA().appName = "RARflixDev" then 
        return true
    end if
    return false
end function

function isRFtest() as boolean
    ' test and dev 
    if GetGlobalAA().appName = "RARflix" then 
        return false
    end if
    return true
end function

Sub InitRARFlix() 

    GetGlobalAA()
    'RegDelete("rf_unwatched_limit", "preferences")
    'RegDelete("rf_grid_style", "preferences")
    'RegDelete("rf_poster_grid_style", "preferences")
    'RegDelete("rf_theme", "preferences")
    'RegDelete("rf_img_overlay", "preferences")
    Debug("=======================RARFLIX SETTINGS ====================================")

    ' purge specific sections - works for unclean exists ( add new sections to purge to "purge_sections")
    Debug("---- purge registry settings for specific sections ---- ")
    purge_sections = ["rf_notified"]
    flush = false
    reg = CreateObject("roRegistry")
    reg_keys = reg.Getsectionlist()
    for each purge in purge_sections 
        for each sec in reg_keys
            if purge = sec then 
                Debug("    purging " + purge + " from registry")
                reg.Delete(sec)
                flush = true
            end if 
         next
    next
    if flush then 
        reg.Flush()
        Debug("    flushed changes to registry")
    end if

    '     this might be useful if we ever need to remove specific keys -- needs work since it was used for what I am doing above (above is better to flush all)
    '     flush = []
    '     for each sec_key in purge_sections 
    '         sec = CreateObject("roRegistrySection", sec_key)
    '         keys = sec.GetKeyList()
    '         delete  = invalid
    '         for each k in keys
    '             delete = sec_key
    '             Debug("    deleting " + tostr(k) + " from " + tostr(sec_key))
    '             sec.Delete(k)
    '         next
    '         if delete <> invalid then flush.Push(delete)
    '     next 
    '
    '     ' we only want to flush once per registry section     
    '     if flush.Count() > 0 then
    '         for each sec_key in flush
    '             sec = CreateObject("roRegistrySection", sec_key)
    '             sec.Flush()
    '             Debug("Flush called for " + tostr(sec_key))
    '         next
    '     end if

    Debug("---- end purge ----")

    ' Temporarily disable theme music due to bug - user can change it back if they really want it
    if RegRead("rf_temp_thememusic", "preferences","first") = "first" then
        prev_setting = RegRead("theme_music", "preferences","disabled")
        Debug("first run - disabling theme music due to bug")
        RegWrite("theme_music", "disabled", "preferences")
        RegWrite("rf_temp_thememusic", prev_setting, "preferences")
    end if
 
    'RegRead("rf_theme", "preferences","black") done in appMain initTheme()
    RegRead("rf_img_overlay", "preferences","BFBFBF") ' plex white
    RegRead("rf_channel_text", "preferences","disabled") ' enabled channel icons to show text ( after the main row )
    RegRead("rf_poster_grid", "preferences","grid")
    RegRead("rf_grid_style", "preferences","flat-movie")
    RegRead("rf_home_displaymode", "preferences","photo-fit")
    RegRead("rf_grid_displaymode", "preferences","scale-to-fit")
    RegRead("rf_poster_displaymode", "preferences","scale-to-fit")
    RegRead("rf_music_artist", "preferences","track")
    RegRead("rf_bcdynamic", "preferences","enabled")
    RegRead("rf_rottentomatoes", "preferences","enabled")
    RegRead("rf_rottentomatoes_score", "preferences","audience")
    RegRead("rf_trailers", "preferences","enabled")
    RegRead("rf_tvwatch", "preferences","enabled")
    RegRead("rf_searchtitle", "preferences","title")
    RegRead("rf_rowfilter_limit", "preferences","200") ' no toggle yet
    RegRead("rf_hs_clock", "preferences", "enabled")
    RegRead("rf_focus_unwatched", "preferences", "enabled")
    RegRead("rf_user_rating_only", "preferences", "user_prefer") ' this will show the original star rating as the users if it exists. seems safe to set at first
    RegRead("rf_up_behavior", "preferences", "exit") ' default is exit screen ( except for home )
    RegRead("rf_notify", "preferences", "enabled") ' enabled:all, video:video only, nonvideo:non video, disabled:disabled (when to notify)
    RegRead("rf_notify_np_type", "preferences", "all") ' now playing notify types

    ' ljunkie Youtube Trailers (extended to TMDB)
    m.youtube = InitYouTube()


    Debug("rf_theme: " + tostr(RegRead("rf_theme", "preferences")))
    Debug("rf_img_overlay: " + tostr(RegRead("rf_img_overlay", "preferences")))
    Debug("rf_channel_text: " + tostr(RegRead("rf_channel_text", "preferences")))
    Debug("rf_poster_grid: " + tostr(RegRead("rf_poster_grid", "preferences")))
    Debug("rf_grid_style: " + tostr(RegRead("rf_grid_style", "preferences")))
    Debug("rf_home_displaymode: " + tostr(RegRead("rf_home_displaymode", "preferences")))
    Debug("rf_grid_displaymode: " + tostr(RegRead("rf_grid_displaymode", "preferences")))
    Debug("rf_poster_displaymode: " + tostr(RegRead("rf_poster_displaymode", "preferences")))
    Debug("rf_bcdynamic: " + tostr(RegRead("rf_bcdynamic", "preferences")))
    Debug("rf_hs_clock: " + tostr(RegRead("rf_hs_clock", "preferences")))
    Debug("rf_rottentomatoes: " + tostr(RegRead("rf_rottentomatoes", "preferences")))
    Debug("rf_rottentomatoes_score: " + tostr(RegRead("rf_rottentomatoes_score", "preferences")))
    Debug("rf_trailers: " + tostr(RegRead("rf_trailers", "preferences")))
    Debug("rf_tvwatch: " + tostr(RegRead("rf_tvwatch", "preferences")))
    Debug("rf_searchtitle: " + tostr(RegRead("rf_searchtitle", "preferences")))
    Debug("rf_rowfilter_limit: " + tostr(RegRead("rf_rowfilter_limit", "preferences")))
    Debug("rf_focus_unwatched: " + tostr(RegRead("rf_focus_unwatched", "preferences")))
    Debug("rf_user_rating_only: " + tostr(RegRead("rf_user_rating_only", "preferences")))
    Debug("rf_up_behavior: " + tostr(RegRead("rf_up_behavior", "preferences")))
    Debug("rf_notify: " + tostr(RegRead("rf_notify", "preferences")))
    Debug("rf_notify_np_type: " + tostr(RegRead("rf_notify_np_type", "preferences")))
    Debug("rf_temp_thememusic: " + tostr(RegRead("rf_temp_thememusic", "preferences")))
    Debug("rf_music_artist: " + tostr(RegRead("rf_music_artist", "preferences")))
    Debug("============================================================================")

end sub


Function GetDurationString( Seconds As Dynamic, emptyHr = 0 As Integer, emptyMin = 0 As Integer, emptySec = 0 As Integer  ) As String
   datetime = CreateObject( "roDateTime" )

   if (type(Seconds) = "roString") then
       TotalSeconds% = Seconds.toint()
   else if (type(Seconds) = "roInteger") or (type(Seconds) = "Integer") then
       TotalSeconds% = Seconds
   else
       return "Unknown"
   end if

   datetime.FromSeconds( TotalSeconds% )
      
   hours = datetime.GetHours().ToStr()
   minutes = datetime.GetMinutes().ToStr()
   seconds = datetime.GetSeconds().ToStr()
   
   duration = ""
   If hours <> "0" or emptyHr = 1 Then
      duration = duration + hours + "h "
   End If

   If minutes <> "0" or emptyMin = 1 Then
      duration = duration + minutes + "m "
   End If
   If seconds <> "0" or emptySec = 1 Then
      duration = duration + seconds + "s"
   End If
   
   Return duration
End Function

Function RRmktime( epoch As Integer, localize = 1 as Integer) As String
    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(epoch)
    if localize = 1 then 
        datetime.ToLocalTime()
    end if
    hours = datetime.GetHours()
    minutes = datetime.GetMinutes()
    seconds = datetime.GetSeconds()
       
    duration = ""
    hour = hours
    If hours = 0 Then
       hour = 12
    End If

    If hours > 12 Then
        hour = hours-12
    End If

    If hours >= 0 and hours < 12 Then
        AMPM = "am"
    else
        AMPM = "pm"
    End if
       
    minute = minutes.ToStr()
    If minutes < 10 Then
      minute = "0" + minutes.ToStr()
    end if

    result = hour.ToStr() + ":" + minute + AMPM

    Return result
End Function

Function RRbitrate( bitrate As Float) As String
    speed = bitrate/1000/1000
    ' brightscript doesn't have sprintf ( only include on decimal place )
    speed = speed * 10
    speed = speed + 0.5
    speed = fix(speed)
    speed = speed / 10
    format = "mbps"
    if speed < 1 then
      speed = speed*1000
      format = "kbps"
    end if
    return tostr(speed) + format
End Function

Function RRbreadcrumbDate(myscreen) As Object
    if RegRead("rf_hs_clock", "preferences", "enabled") = "enabled" then
        screenName = firstOf(myScreen.ScreenName, type(myScreen.Screen))
        if screenName <> invalid and screenName = "Home" then 
            'Debug("update " + screenName + " screen time") 'stop printing this.. it's been tested enough
            date = CreateObject("roDateTime")
            date.ToLocalTime() ' localizetime
            timeString = RRmktime(date.AsSeconds(),0)
            dateString = date.AsDateString("short-month-short-weekday")
            myscreen.Screen.SetBreadcrumbEnabled(true)
            myscreen.Screen.SetBreadcrumbText(dateString, timeString)
        'else 
        '    Debug("will NOT update " + screenName + " screen time. " + screenName +"=Home")
        end if
    end if
End function

Function createRARFlixPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)
    obj.HandleMessage = prefsRARFflixHandleMessage

    ' Home Screen clock
    rf_hs_clock_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Show clock on Home Screen" },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Show clock on Home Screen" },
    ]
    obj.Prefs["rf_hs_clock"] = {
        values: rf_hs_clock_prefs,
        heading: "Date and Time",
        default: "enabled"
    }

    rf_theme = [
        { title: "Original", EnumValue: "original", },
        { title: "Black", EnumValue: "black", },
    ]
    obj.Prefs["rf_theme"] = {
        values: rf_theme,
        heading: "Theme for Channel (restart required)",
        default: "black"
    }

    ' Rotten Tomatoes
    rt_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Display Ratings from RottenTomatoes" },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Display Ratings from RottenTomatoes" },
    ]
    obj.Prefs["rf_rottentomatoes"] = {
        values: rt_prefs,
        heading: "Movie Ratings from Critics and Users",
        default: "enabled"
    }

    ' Rotten Tomatoes
    rt_prefs_score = [
        { title: "Critic's", EnumValue: "critic", ShortDescriptionLine2: "Use Critic's Score" },
        { title: "Audience's", EnumValue: "audience", ShortDescriptionLine2: "Use Audience's Score" },
    ]
    obj.Prefs["rf_rottentomatoes_score"] = {
        values: rt_prefs_score,
        heading: "Score to display on the Movie Details Screen",
        default: "audience"
    }

    ' RT/Trailers - search title
    rt_prefs = [
        { title: "Title", EnumValue: "title", ShortDescriptionLine2: "Search by Movie Title" },
        { title: "Original Title", EnumValue: "originalTitle", ShortDescriptionLine2: "Search by Original Movie Title" },
    ]
    obj.Prefs["rf_searchtitle"] = {
        values: rt_prefs,
        heading: "Search by Title or 'Original' Title",
        default: "title"
    }

    ' Trailers
    trailer_prefs = [
        { title: "Enabled TMDB & Youtube", EnumValue: "enabled", ShortDescriptionLine2: "Display Movie Trailers" + chr(10) + "themoviedb.org and Youtube" },
        { title: "Enabled TMDB w/ Youtube Fallback", EnumValue: "enabled_tmdb_ytfb", ShortDescriptionLine2: "Display Movie Trailers" + chr(10) + "themoviedb.org or Fallback to Youtube" },
        { title: "Disabled", EnumValue: "disabled"}

    ]
    obj.Prefs["rf_trailers"] = {
        values: trailer_prefs,
        heading: "Show Movie Trailer button",
        default: "enabled_tmdb_yt"
    }

    ' Breadcrumb fixes
    bc_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Update header when browsing " +chr(10)+ "On Deck, Recently Added, etc.."  },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Update header when browsing " +chr(10)+ "On Deck, Recently Added, etc.."  },


    ]
    obj.Prefs["rf_bcdynamic"] = {
        values: bc_prefs,
        heading: "Update Header (top right)",
        default: "enabled"
    }


    ' TV Watched status next to ShowTITLE
    tv_watch_prefs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Dexter (watched)" + chr(10) + "Dexter (1 of 12 watched)" },
        { title: "Disabled", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_tvwatch"] = {
        values: tv_watch_prefs,
        heading: "Append the watched status to TV Show Titles",
        default: "enabled"
    }

    ' focus to the unwatched item in a postescreen -  maybe others later
    focus_unwatched = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "",}
        { title: "Disabled", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_focus_unwatched"] = {
        values: focus_unwatched,
        heading: "Focus on the first Unwatched item"
        default: "enabled"
    }

    ' focus to the unwatched item in a postescreen -  maybe others later
    music_artist = [
        { title: "Track", EnumValue: "track", ShortDescriptionLine2: "Track Artist",}
        { title: "Album", EnumValue: "album", ShortDescriptionLine2: "Album Artist",}
        { title: "Various", EnumValue: "various", ShortDescriptionLine2: "Track Artist when Various Artists",}
    ]
    obj.Prefs["rf_music_artist"] = {
        values: music_artist,
        heading: "Display Artist when Playing a Track"
        default: "enabled"
    }

    ' user ratings only
    user_ratings = [
        { title: "Only Your Ratings", EnumValue: "user_only", ShortDescriptionLine2: "Display your Star Ratings Only",}
        { title: "Prefer Your Ratings", EnumValue: "user_prefer", ShortDescriptionLine2: "Prefer your Ratings over the Default",}
        { title: "Default", EnumValue: "disabled" },

    ]
    obj.Prefs["rf_user_rating_only"] = {
        values: user_ratings,
        heading: "Only show or Prefer your Star Ratings"
        default: "disabled"
    }

    ' user ratings only
    up_behavior = [
        { title: "Previous Screen", EnumValue: "exit", ShortDescriptionLine2: "Go to the Previous Screen (go back)",}
        { title: "Do Nothing", EnumValue: "stop", ShortDescriptionLine2: "Stay on Screen (do nothing)",}

    ]
    obj.Prefs["rf_up_behavior"] = {
        values: up_behavior,
        heading: "Up Key action when Top Row is Selected",
        default: "exit"
    }

    ' text overlay color (customer posters)
    rf_overlay = [
        { title: "White  (Plex)", EnumValue: "BFBFBF", }
        { title: "Orange (Plex)", EnumValue: "FFA500", }
        { title: "White", EnumValue: "F5F5F5",}
        { title: "Light Gray", EnumValue: "A0A0A0",}
        { title: "Gray", EnumValue: "606060",}
        { title: "Tan", EnumValue: "bf8e60",}
        { title: "Green", EnumValue: "778554",}
        { title: "Sky", EnumValue: "bfcada",}
    ]
    obj.Prefs["rf_img_overlay"] = {
        values: rf_overlay,
        heading: "Text Color for Images in Sub Sections",
        default: "BFBFBF"
    }

    ' Breadcrumb fixes
    custom_thumbs = [
        { title: "Enabled", EnumValue: "enabled", ShortDescriptionLine2: "Use Custom"  },
        { title: "Disabled", EnumValue: "disabled", ShortDescriptionLine2: "Use Generic Icon"  },


    ]
    obj.Prefs["rf_custom_thumbs"] = {
        values: custom_thumbs,
        heading: "Replace Generic Icons with Text",
        default: "enabled"
    }

   ' enable notifications?  (if we add more events (currently now playing) we can add more toggles )
    notifications = [
        { title: "Enabled", EnumValue: "enabled",}
        { title: "in Video Screen", EnumValue: "video", ShortDescriptionLine2: "Only show on Video Screen",}
        { title: "in NON Video Screens", EnumValue: "nonvideo", ShortDescriptionLine2: "Only when not Playing a Video",}
        { title: "Disabled", EnumValue: "disabled",}

    ]
    obj.Prefs["rf_notify"] = {
        values: notifications,
        heading: "Show Now Playing Notifications",
        default: "exit"
    }

    ' start, stop, all:enabled
    np_notificationstypes = [
        { title: "All", EnumValue: "all", ShortDescriptionLine2: "Notify on Start and Stop",}
        { title: "Start", EnumValue: "start", ShortDescriptionLine2: "Notify on Start",}
        { title: "Stop", EnumValue: "stop", ShortDescriptionLine2: "Notify on Stop",}
    ]
    obj.Prefs["rf_notify_np_type"] = {
        values: np_notificationstypes,
        heading: "When to Notify?",
        default: "all"
    }


    filter_limit = [
        { title: "100", EnumValue: "100" },
        { title: "200", EnumValue: "200" },
        { title: "300", EnumValue: "300", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "400", EnumValue: "400", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "500", EnumValue: "500", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "600", EnumValue: "600", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "700", EnumValue: "700", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "800", EnumValue: "800", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "900", EnumValue: "900", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "1000", EnumValue: "1000", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "1500", EnumValue: "1500", ShortDescriptionLine2: "May cause Plex to be Sluggish"},
        { title: "All", EnumValue: "9999", ShortDescriptionLine2: "May cause Plex to be Sluggish.. really?"},
    ]
    obj.Prefs["rf_rowfilter_limit"] = {
        values: filter_limit,
        heading: "Item limit for Unwatched Recently Added & Released [movies]",
        default: "200"
    }


    obj.Screen.SetHeader("RARFlix Preferences")
    obj.AddItem({title: "Theme"}, "rf_theme", obj.GetEnumValue("rf_theme"))
    obj.AddItem({title: "Custom Icons", ShortDescriptionLine2: "Replace generic icons with Text"}, "rf_custom_thumbs", obj.GetEnumValue("rf_custom_thumbs"))
    if RegRead("rf_custom_thumbs", "preferences","enabled") = "enabled" then
        obj.AddItem({title: "Custom Icons Text", ShortDescriptionLine2: "Color of text to use"}, "rf_img_overlay", obj.GetEnumValue("rf_img_overlay"))
    end if
    obj.AddItem({title: "Hide Rows",ShortDescriptionLine2: "Sorry for the confusion..."}, "hide_rows_prefs")
    obj.AddItem({title: "Section Display", ShortDescriptionLine2: "a plex original, for easy access"}, "sections")

    obj.AddItem({title: "Movie Trailers", ShortDescriptionLine2: "Got Trailers?"}, "rf_trailers", obj.GetEnumValue("rf_trailers"))
    obj.AddItem({title: "Rotten Tomatoes", ShortDescriptionLine2: "Movie Ratings from Rotten Tomatoes"}, "rf_rottentomatoes", obj.GetEnumValue("rf_rottentomatoes"))
    if RegRead("rf_rottentomatoes", "preferences","enabled") = "enabled" then
        obj.AddItem({title: "Rotten Tomatoes Score", ShortDescriptionLine2: "Who do you trust more..." + chr(10) + "A Critic or an Audience?"}, "rf_rottentomatoes_score", obj.GetEnumValue("rf_rottentomatoes_score"))
    end if
    if RegRead("rf_rottentomatoes", "preferences","enabled") = "enabled" or RegRead("rf_trailers", "preferences") <> "disabled" then
        obj.AddItem({title: "Trailers/Tomatoes Search by", ShortDescriptionLine2: "You probably don't want to change this"}, "rf_searchtitle", obj.GetEnumValue("rf_searchtitle"))
    end if
    obj.AddItem({title: "Dynamic Headers", ShortDescriptionLine2: "Info on the top Right of the Screen"}, "rf_bcdynamic", obj.GetEnumValue("rf_bcdynamic"))
    obj.AddItem({title: "TV Show (Watched Status)", ShortDescriptionLine2: "feels good enabled"}, "rf_tvwatch", obj.GetEnumValue("rf_tvwatch"))
    obj.AddItem({title: "Focus on Unwatched", ShortDescriptionLine2: "Default to the first unwatched " + chr(10) + "item (poster screen only)"}, "rf_focus_unwatched", obj.GetEnumValue("rf_focus_unwatched"))
    obj.AddItem({title: "Clock on Home Screen"}, "rf_hs_clock", obj.GetEnumValue("rf_hs_clock"))
    obj.AddItem({title: "Unwatched Added/Released", ShortDescriptionLine2: "Item limit for unwatched Recently Added &" + chr(10) +"Recently Released rows [movies]"}, "rf_rowfilter_limit", obj.GetEnumValue("rf_rowfilter_limit"))
    obj.AddItem({title: "Star Ratings Override", ShortDescriptionLine2: "Only show or Prefer"+chr(10)+"Star Ratings that you have set"}, "rf_user_rating_only", obj.GetEnumValue("rf_user_rating_only"))
    obj.AddItem({title: "Up Button (row screens)", ShortDescriptionLine2: "What to do when the UP button is " + chr(10) + "pressed on a screen with rows"}, "rf_up_behavior", obj.GetEnumValue("rf_up_behavior"))
    obj.AddItem({title: "Music Artists", ShortDescriptionLine2: "Artist to display for a track"}, "rf_music_artist", obj.GetEnumValue("rf_music_artist"))

    if isRFtest() then 
        obj.AddItem({title: "Now Playing Notifications", ShortDescriptionLine2: "Want to be notified on Now Playing?"}, "rf_notify", obj.GetEnumValue("rf_notify"))
        if RegRead("rf_notify", "preferences","enabled") = "enabled" then 
            obj.AddItem({title: "Now Playing Notify Types", ShortDescriptionLine2: "When do you want to be notified?" + chr(10) + " On Start/Stop or Both"}, "rf_notify_np_type", obj.GetEnumValue("rf_notify_np_type"))
        end if
    end if

    obj.AddItem({title: "Close"}, "close")
    return obj
End Function

Function prefsRARFflixHandleMessage(msg) As Boolean
    handled = false

    if type(msg) = "roListScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            m.ViewController.PopScreen(m)
            m.ViewController.Home.Refresh(m.Changes) ' include the Changes for homescreen refresh ( might be useful to add this to the main ALL *HandleMessages functions )
        else if msg.isListItemSelected() then
            command = m.GetSelectedCommand(msg.GetIndex())
            if command = "hide_rows_prefs" then
                screen = createHideRowsPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Hide Rows Preferences"])
                screen.Show()
            else if command = "sections" then
                screen = createSectionDisplayPrefsScreen(m.ViewController)
                m.ViewController.InitializeOtherScreen(screen, ["Section Display Preferences"])
                screen.Show()
            else if command = "close" then
                m.Screen.Close()
            else
                m.HandleEnumPreference(command, msg.GetIndex())
            end if
        end if
    end if

    return handled
End Function

Function createHideRowsPrefsScreen(viewController) As Object
    obj = createBasePrefsScreen(viewController)
    obj.HandleMessage = prefsRARFflixHandleMessage

    'a little cleaner: if Plex adds/changes rows it will be in PreferenceScreen.brs:createSectionDisplayPrefsScreen()
    PlexRows = [
        { title: "All Items", key: "all" },
        { title: "On Deck", key: "onDeck" },
        { title: "Recently Added", key: "recentlyAdded" },
        { title: "Recently Released", key: "newest" },
        { title: "Unwatched", key: "unwatched" },
        { title: "[movie] Recently Added (uw)", key: "all?type=1&unwatched=1&sort=addedAt:desc" }, 'movie/film for now
        { title: "[movie] Recently Released (uw)", key: "all?type=1&unwatched=1&sort=originallyAvailableAt:desc" }, 'movie/film for now
        { title: "Recently Viewed", key: "recentlyViewed" },
        { title: "[tv] Recently Viewed Shows", key: "recentlyViewedShows" },
        { title: "By Album", key: "albums" },
        { title: "By Collection", key: "collection" },
        { title: "By Genre", key: "genre" },
        { title: "By Year", key: "year" },
        { title: "By Decade", key: "decade" },
        { title: "By Director", key: "director" },
        { title: "By Actor", key: "actor" },
        { title: "By Country", key: "country" },
        { title: "By Content Rating", key: "contentRating" },
        { title: "By Rating", key: "rating" },
        { title: "By Resolution", key: "resolution" },
        { title: "By First Letter", key: "firstCharacter" },
        { title: "By Folder", key: "folder" },
        { title: "Search", key: "_search_" }
    ]
    obj.Screen.SetHeader("Hide or Show Rows for Library Sections")

    ReorderItemsByKeyPriority(PlexRows, RegRead("section_row_order", "preferences", ""))

    for each item in PlexRows
        if item.key = "_search_" then item.key = "search" 'special case
        rf_hide_key = "rf_hide_"+item.key

        ' allow one to Hide Recently Released and Recently Added if Movie/Show/Music - would really be nice to reorder per section.. but that's another time (TODO)
        if item.key = "newest" or item.key = "recentlyAdded" then 
            itypes = [
                { type: "movie", short: "[movie]", },
                { type: "artist", short: "[music]", },
                { type: "show", short: "[tv]", newest: "Recently Aired" },
            ]

            for each it in itypes
                new_hide_key = rf_hide_key + "_" + it.type
                title = it.short + " " + item.title
                if it[item.key] <> invalid then title = it.short + " " + it[item.key]

                values = [
                    { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: title },
                    { title: "Show", EnumValue: "show", ShortDescriptionLine2: title },
                ]
                obj.Prefs[new_hide_key] = {
                    values: values,
                    heading: "Show or Hide Row",
                    default: "show"
                }
                if (it.type = "artist" and item.key <> "newest") or ( it.type <> "artist")   then
                    obj.AddItem({title: title}, new_hide_key, obj.GetEnumValue(new_hide_key))
                end if
            end for
        end if ' else  -- allow other sections to hide recentlyAdded/released normally

        if item.key = "recentlyAdded" then item.title = "[other] Recently Added"
        if item.key = "newest" then item.title = "[other] Recently Released"
        values = [
            { title: "Hide", EnumValue: "hide", ShortDescriptionLine2: item.title },
            { title: "Show", EnumValue: "show", ShortDescriptionLine2: item.title },
        ]
        obj.Prefs[rf_hide_key] = {
            values: values,
            heading: "Show or Hide Row",
            default: "show"
        }
        if NOT item.key = "newest" then ' others don't have this yet
            obj.AddItem({title: item.title}, rf_hide_key, obj.GetEnumValue(rf_hide_key))
        end if
    next
   
    obj.AddItem({title: "Close"}, "close")
    return obj
End Function

Function ShowPleaseWait(title As dynamic, text As dynamic) As Object
    if not isstr(title) title = ""
    if not isstr(text) text = ""

    port = CreateObject("roMessagePort")
    dialog = invalid

    'the OneLineDialog renders a single line of text better
    'than the MessageDialog.

    if text = ""
        dialog = CreateObject("roOneLineDialog")
    else
        dialog = CreateObject("roMessageDialog")
        dialog.SetText(text)
    end if

    dialog.SetMessagePort(port)
    dialog.SetTitle(title)
    dialog.ShowBusyAnimation()
    dialog.Show()
    return dialog
End Function



sub rfVideoMoreButton(obj as Object) as Dynamic
    dialog = createBaseDialog()
    dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.umtitle, obj.metadata.title)
    'dialog.Text = truncateString(obj.metadata.shortdescriptionline2,80)
    dialog.Text = "" ' too many buttons for text now
    dialog.Item = obj.metadata

    supportedIdentifier = (obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    isMovieShowEpisode = (obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode")

    if isMovieShowEpisode then 
        dialog.SetButton("options", "Playback options")
    end if

    ' display View All Seasons if we have grandparentKey -- entered from a episode
    if obj.metadata.grandparentKey <> invalid then
         dialog.SetButton("showFromEpisode", "View All Seasons")
    end if

    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if obj.metadata.parentKey <> invalid AND obj.metadata.parentIndex <> invalid then
       dialog.SetButton("seasonFromEpisode", "View Season " + obj.metadata.parentIndex)
    end if

    if supportedIdentifier then
        if obj.metadata.viewOffset <> invalid AND val(obj.metadata.viewOffset) > 0 then ' partially watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            dialog.SetButton("scrobble", "Mark as watched")
        else if obj.metadata.viewCount <> invalid AND val(obj.metadata.viewCount) > 0 then ' watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            ' no need to show watched button (already watched)
        else if obj.metadata.viewCount = invalid then  ' not watched
            dialog.SetButton("scrobble", "Mark as watched")
            ' no need to show unwatched 
        end if
        if obj.metadata.server.AllowsMediaDeletion AND obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" then
            dialog.SetButton("delete", "Delete permanently")
        end if

    end if

    ' these are on the main details screen -- show them last ( maybe not at all )
    if isMovieShowEpisode or obj.metadata.type = "season" or obj.metadata.ContentType = "series" then
        dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
    else 
       Debug("---- Cast and Crew are not available for " + tostr(obj.metadata.ContentType))
    end if

    if obj.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
        dialog.SetButton("getTrailers", "Trailer")
    end if

    ' set this to last -- unless someone complains
    if supportedIdentifier then
        if obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "show"  then
            dialog.SetButton("rate", "_rate_")
        end if
    end if

    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub


sub fakeRefresh(force=false) 
    Debug("refresh? it we have a valid item")
    if m.item <> invalid and type(m.item.refresh) = "roFunction" then 
        m.item.refresh()
        Debug("refresh item")
    end if

    if type(m.screen) = "roPosterScreen" then 
        if type(m.contentarray) = "roArray" then 
            focusedIndex = m.contentarray[0].focusedindex
            content = m.contentarray[0].content
            if focusedIndex <> invalid and type(content) = "roArray" and type(content[focusedIndex]) = "roAssociativeArray" then 
                if type(content[focusedIndex].refresh) = "roFunction" then  
                    content[focusedIndex].refresh()
                    m.screen.SetContentList(content)
		    Debug("refresh content list!")
                end if
            end if
        end if
    end if
'    stop
'    m.Screen.Show()
'    stop
    'fake it for now
end sub 

' This is the context Dialog from the GRID - I should rename this TODO
sub rfVideoMoreButtonFromGrid(obj as Object) as Dynamic

    ' this should probably just be combined into rfVideoMoreButton  ( there are some caveats though and maybe more to come.. so until this has been finalized )
    dialog = createBaseDialog()

    ' TODO full grid screen yo
    if obj.isfullgrid = invalid and type(obj.screen) = "roGridScreen" then 
        fromName = "invalid"
        if type(obj.loader.getnames) = "roFunction" and obj.selectedrow <> invalid then fromName = obj.loader.getnames()[obj.selectedrow]
        dialog.sepAfter.Push("fullGridScreen")
        dialog.SetButton("fullGridScreen", "Grid View: " + fromName)
    end if


    if (obj.metadata.type = "season") then 
        dialog.Title = firstof(obj.metadata.title, obj.metadata.umtitle, obj.metadata.title)
        dialog.Text = ""
    else if (obj.metadata.type = "episode") then 
        dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.title)
        dialog.Text = firstof(obj.metadata.shortdescriptionline2,  obj.metadata.shortdescriptionline1)
        dialog.Text = dialog.Text + chr(10) + chr(32) + chr(32) +chr(32) +firstof(obj.metadata.description, obj.metadata.umtitle)
    else 
        ' movies -- the description is too much
        dialog.Title = firstof(obj.metadata.showtitle, obj.metadata.umtitle, obj.metadata.title)
        dialog.Text = obj.metadata.shortdescriptionline2
     end if

    'dialog.Text = truncateString(dialog.Text,80)
    dialog.Text = "" ' too many buttons for text now

    dialog.Item = obj.metadata

    if type(obj.Refresh) <> "Function" then 
      obj.Refresh = fakeRefresh ' sbRefresh is called normally - in a poster screen this doesn't happen?
    end if

    ' hack for global recently added ( tv shows are displayed as seasons )
    if (obj.metadata.type = "season") and obj.metadata.grandparentKey = invalid then 
        ' available: obj.metadata.key = "/library/metadata/88482/childen'
        re = CreateObject("roRegex", "/children.*", "i")
        obj.metadata.parentKey = re.ReplaceAll(obj.metadata.key, "")
        container = createPlexContainerForUrl(obj.metadata.server, obj.metadata.server.serverUrl, obj.metadata.parentKey)
        if container <> invalid then
            obj.metadata.grandparentKey = container.xml.Directory[0]@parentKey
            obj.metadata.parentIndex = container.xml.Directory[0]@index
            obj.metadata.ShowTitle = container.xml.Directory[0]@parentTitle
        end if
    else if (obj.metadata.type = "show") and obj.metadata.grandparentKey = invalid then 
        ' object type is a show -- we have all we need
        re = CreateObject("roRegex", "/children.*", "i")
        obj.metadata.grandparentKey = re.ReplaceAll(obj.metadata.key, "")
        obj.metadata.ShowTitle = firstof(obj.metadata.umtitle, obj.metadata.showtitle, obj.metadata.title)
        'end if
    else if obj.metadata.grandparentKey = invalid then 
         Debug("---- we should probably handle " + tostr(obj.metadata.type) + "? figure out the parentKey/grandparentkey for: " + tostr(obj.metadata.key))
    end if
    ' end hack

    ' display View All Seasons if we have grandparentKey -- entered from a episode
    if obj.metadata.grandparentKey <> invalid then 
        if obj.metadata.type = "season" and type(obj.screen) = "roPosterScreen"  then
            ' this is a ALL seasons view on a posterscreen -- can we add mark as watched/unwatched to make them all??
        else 
            dialog.SetButton("showFromEpisode", "View All Seasons of " + tostr(obj.metadata.ShowTitle) )
        end if
    end if
    ' display View specific season if we have parentKey/parentIndex -- entered from a episode
    if obj.metadata.parentKey <> invalid AND obj.metadata.parentIndex <> invalid and type(obj.screen) <> "roPosterScreen" then 
       dialog.SetButton("seasonFromEpisode", "View Season " + obj.metadata.parentIndex)
    end if

    ' Trailers link - RR (last now that we include it on the main screen .. well before delete - people my be used to delete being second to last)
    if obj.metadata.ContentType = "movie" AND  RegRead("rf_trailers", "preferences", "disabled") <> "disabled" then 
        dialog.SetButton("getTrailers", "Trailer")
    end if

    ' cast and crew
    if obj.metadata.type = "season" or obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "show" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "series" then
        dialog.SetButton("RFCastAndCrewList", "Cast & Crew")
    else
       Debug(" Cast and Crew are not available for " + tostr(obj.metadata.ContentType))
    end if

    supportedIdentifier = (obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.library" OR obj.metadata.mediaContainerIdentifier = "com.plexapp.plugins.myplex")
    if supportedIdentifier then
        if obj.metadata.viewOffset <> invalid AND val(obj.metadata.viewOffset) > 0 then ' partially watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            dialog.SetButton("scrobble", "Mark as watched")
        else if obj.metadata.viewCount <> invalid AND val(obj.metadata.viewCount) > 0 then ' watched
            dialog.SetButton("unscrobble", "Mark as unwatched")
            ' no need to show watched button (already watched)
        else if obj.metadata.viewCount = invalid then  ' not watched
            dialog.SetButton("scrobble", "Mark as watched")
            ' no need to show unwatched 
        end if

        if obj.metadata.ContentType = "movie" or obj.metadata.ContentType = "episode" or obj.metadata.ContentType = "show"  then
            if obj.Item.StarRating = invalid then obj.Item.StarRating = 0
            if obj.Item.origStarRating = invalid then obj.Item.origStarRating = 0
            dialog.SetButton("rate", "_rate_")
        end if

        ' should we allow the delete from here?

    end if

    dialog.SetButton("close", "Back")
    dialog.HandleButton = videoDialogHandleButton
    dialog.ParentScreen = obj
    dialog.Show()
end sub

function UcaseFirst(var,strip = invalid) as dynamic
 'Debug("UcaseFirst start:" + var)
 if strip <> invalid then ' extra function to strip chars/replace them - I didn't want to create another function
     re = CreateObject("roRegex", "_", "i")
     var = re.ReplaceAll(var, "       ")
     re = CreateObject("roRegex", "rarforge", "i") ' just for me :)
     var = re.ReplaceAll(var, "")
     'Debug("UcaseFirst strip:" + var)
 end if

 re = CreateObject("roRegex", "  ", "i") ' remove double spaces
 var = re.ReplaceAll(var, " ")
 'Debug("UcaseFirst spaces:" + var)

 ' Capitalize first of every word
 parts = strTokenize(var, " ")
 result = invalid
 for each part in parts
     if result = invalid then 
         result = ucase(left(part,1))+right(part,len(part)-1)
     else
         result = result + " " + ucase(left(part,1))+right(part,len(part)-1)
     end if
 end for
 if result <> invalid then var = result
 'Debug("UcaseFirst result:" + var)

 return var ' return either modified or untouched var
end function



' Hack to show the HUD
Sub SendRemoteKey(key)
    di = CreateObject("roDeviceInfo")
    ipaddrs = di.GetIPAddrs()
    if ipaddrs.eth0 <> invalid then ipaddr = ipaddrs.eth0
    if ipaddrs.eth1 <> invalid then ipaddr = ipaddrs.eth1
    'print "ipaddr: ";ipaddr
    sleep(200)
    url = "http://"+ipaddr+":8060/keypress/" + key
    Debug("sending key " + tostr(key) + " " + tostr(url))
    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.PostFromString("")
End Sub


' Hack to show a notification through the HUD
sub HUDnotify(screen,obj = invalid) 
    ' we must be in a roVideoScreen
    if type(screen.screen) = "roVideoScreen" and type(obj) = "roArray" then
        Debug("showing HUD notification")
        content = CreateObject("roAssociativeArray")
        content_orig = screen.VideoItem        ' set original content to reset
        content.title = "Now Playing" ' we use the title for HUD messages ( less text )
        content.releasedate = ""
        for each i in obj
            content.releasedate = content.releasedate + chr(10) + i.title + chr(10)  'chr(10) for spacing between notifications (works with 1 too)
        next
        screen.Screen.SetContent(content)      ' set new content for notification 
        SendRemoteKey("Down")                  ' show HUD
        screen.Screen.SetContent(content_orig) ' reset HUD to our original content
    end if
end sub

sub rfDefRemoteOptionButton(m) 
    'for now we will show the preferences screen :)

    sec_metadata = getSectionType(m)
    notAllowed = CreateObject("roRegex", "artist|music|album", "") 
    if  NOT notAllowed.isMatch(tostr(sec_metadata.type)) then 
        new = CreateObject("roAssociativeArray")
        new.sourceUrl = ""
        'new.ContentType = "prefs"
        'new.Key = "globalprefs"
        'new.Title = "Preferences"
        new.Key = "globalsearch"
        new.Title = "Search"
        new.ContentType = "search"
        breadcrumbs = ["Miscellaneous","Search"]
        m.ViewController.CreateScreenForItem(new, invalid, breadcrumbs)
        Debug("Showing default serach screen - remote option button pressed ")
     else
        Debug("Default dialog not allowed in this section")
     end if 
end sub


sub rfDialogGridScreen(obj as Object) as Dynamic

    if tostr(obj.item.contenttype) = "section" or obj.selectedrow = 0 then ' row 0 is reserved for the fullGrid shortcuts
        rfDefRemoteOptionButton(obj) 
    ' for now the only option is grid view so we will verify we are in a roGridScreen. It we add more buttons, the type check below is for fullGridScreen
    else if obj.isfullgrid = invalid and type(obj.screen) = "roGridScreen" then 
        dialog = createBaseDialog()
        fromName = "invalid"
        if type(obj.loader.getnames) = "roFunction" and obj.selectedrow <> invalid then fromName = obj.loader.getnames()[obj.selectedrow]
        dialog.sepAfter.Push("fullGridScreen")
        dialog.SetButton("fullGridScreen", "Grid View: " + fromName) 'and type(obj.screen) = "roGridScreen" 
        dialog.Text = ""
        dialog.Title = "Options"
    
        dialog.SetButton("close", "Back")
        dialog.HandleButton = videoDialogHandleButton
        dialog.ParentScreen = obj
        dialog.Show()
     else 
         return invalid
     end if

end sub

function getAllRowsContext(screen,context,index) as object
    obj = CreateObject("roAssociativeArray")
    obj.curindex = index

    if type(screen.screen) = "roGridScreen" then
        srow = screen.selectedrow
        sitem = screen.focusedindex+1
        rsize = screen.contentarray[0].count()
        obj.curindex = (srow*rsize)+sitem-1 ' index is zero based (minus 1)
        context = []
        for each c in screen.contentarray
            for each i in c
                context.push(i)
            end for
        end for
    end if

    obj.context = context

    return obj
end function

function getFullGridCurIndex(vc,index) as object
    print " ------------------ full grid index = " + tostr(index)

    if type(vc.screen) = "roAssociativeArray" then
        screen = vc.screen
    else if type(vc.screens) = "roArray" then
        screen = vc.screens[vc.screens.count()-1]
    else if type(vc.viewcontroller) = "roAssociativeArray" then
        screen = vc.viewcontroller.screens[vc.viewcontroller.screens.count()-2]
    end if

    if type(screen.screen) = "roGridScreen" then
        srow = screen.selectedrow
        sitem = screen.focusedindex+1
        rsize = screen.contentarray[0].count()
        print "selected row:" + tostr(srow) + " focusedindex:" + tostr(sitem) + " rowsize:" + tostr(rsize)
        index = (srow*rsize)+sitem-1 ' index is zero based (minus 1)
    end if
    print " ------------------  new grid index = " + tostr(index)
    return index
end function

Function ShallowCopy(array As Dynamic, depth = 0 As Integer) As Dynamic
    If Type(array) = "roArray" Then
        copy = []
        For Each item In array
            childCopy = ShallowCopy(item, depth)
            If childCopy <> invalid Then
                copy.Push(childCopy)
            End If
        Next
        Return copy
    Else If Type(array) = "roAssociativeArray" Then
        copy = {}
        For Each key In array
            If depth > 0 Then
                copy[key] = ShallowCopy(array[key], depth - 1)
            Else
                copy[key] = array[key]
            End If
        Next
        Return copy
    Else
        Return array
    End If
    Return invalid
End Function

sub rfCDNthumb(metadata,thumb_text,nodetype = invalid)
    if RegRead("rf_custom_thumbs", "preferences","enabled") = "enabled" then
        sizes = ImageSizes(metadata.ViewGroup, nodeType)
        ' mod_rewrite/apache do not allow & or %26
        ' replace with :::: - the cdn will replace with &
        reand = CreateObject("roRegex", "&", "") 
        reslash = CreateObject("roRegex", "/", "")  ' seo urls, so replace these
        redots = CreateObject("roRegex", "\.", "")  ' freaks out the photo transcoder
        thumb_text = reand.ReplaceAll(thumb_text, "::::") 
        thumb_text = reslash.ReplaceAll(thumb_text, "::") 
        thumb_text = redots.ReplaceAll(thumb_text, " ") 
        sdWidth  = "223"
        sdHeight = "200"
        hdWidth  = "300"
        hdHeight = "300"
        if isRFdev() then 
            rarflix_cdn = "http://ec2.rarflix.com" ' use non-cached server for testing (same destination as cloudfrount)
        else
            rarflix_cdn = "http://d1gah69i16tuow.cloudfront.net"
        end if 
        NewThumb = rarflix_cdn + "/images/key/" + URLEncode(thumb_text) ' this will be a autogenerate poster (transparent)
        NewThumb = NewThumb + "/size/" + tostr(hdWidth) + "x" + tostr(hdHeight) ' things seem to play nice this way with the my image processor
        NewThumb = NewThumb + "/fg/" + RegRead("rf_img_overlay", "preferences","999999")
        Debug("----   newraw:" + tostr(NewThumb))
        ' we still want to transcode the size to the specific roku standard
        metadata.SDPosterURL = metadata.server.TranscodedImage(metadata.server.serverurl, NewThumb, sizes.sdWidth, sizes.sdHeight) 
        metadata.HDPosterURL = metadata.server.TranscodedImage(metadata.server.serverurl, NewThumb, sizes.hdWidth, sizes.hdHeight)
        Debug("----      new:" + tostr(metadata.HDPosterURL))
    end if
end sub

' ljunkie - crazy sauce right? this is a way to figure out what section we are in 
function getSectionType(vc) as object
    Debug("---- checking if we can figure out the section we are in")
    metadata = CreateObject("roAssociativeArray")
    if type(vc.screens) = "roArray" then
        screens = vc.screens
    else if type(vc.viewcontroller) = "roAssociativeArray" then
        screens = vc.viewcontroller.screens
    end if

    if type(screens) = "roArray" and screens.count() >= 0 then
       screen = screens[0]
       if type(screen) = "roAssociativeArray" and screen.loader <> invalid and type(screen.loader.contentarray) = "roArray" then
           row = screen.selectedrow
           index = screen.focusedindex
           if row <> invalid and index <> invalid then
               if type(screen.loader.contentarray[row].content) = "roArray" then 
                   metadata = screen.loader.contentarray[row].content[index]
               end if
           end if
        end if
    end if
    return metadata ' return empty assoc
end function

