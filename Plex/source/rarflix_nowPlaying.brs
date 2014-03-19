Sub rf_homeNowPlayingChange()
    ' RefreshData() -  homeRefreshData() this would refresh all.. but we don't want to do that ( I think )
    ' might be usful to check audio now playing too

    rowkey = "now_playing"
    m.contentArray[m.RowIndexes[rowkey]].refreshContent = []
    m.contentArray[m.RowIndexes[rowkey]].loadedServers.Clear()

    re = CreateObject("roRegex", "my.plexapp.com|plex.tv", "i")        
    for each server in GetOwnedPlexMediaServers()
        if re.IsMatch(server.serverurl) then 
            Debug("Skipping now playing session check on 'cloud sync' server: " + server.serverurl)
        else if server.isavailable and server.supportsmultiuser then ' only query server if available and supportsmultiuser (assuming nowPlaying works with multiuser enabled)
            m.CreateServerRequests(server, true, true, invalid, rowkey) ' only request the nowPlaying;/status/sessions
        end if
    next

End Sub

sub rf_updateNowPlayingSB(screen)
    orig_offset = screen.metadata.viewOffset
    new_metadata = rfUpdateNowPlayingMetadata(screen.metadata)

    if new_metadata.viewOffset <> invalid then
        screen.metadata.isStopped = invalid
        screen.metadata.description = " * Progress: " + GetDurationString(int(new_metadata.viewOffset.toint()/1000),0,1,1) ' update progress - if we exit player
        if new_metadata.length <> invalid then 
            screen.metadata.description = screen.metadata.description + " [" + percentComplete(new_metadata.viewOffset,new_metadata.length) + "%]"
        end if
        screen.metadata.viewOffset = new_metadata.viewOffset ' set new offset
    else 
        screen.metadata.isStopped = true
        screen.metadata.description = " * User has stopped watching"
        screen.metadata.viewOffset = orig_offset
        Debug("---- setting the video Offset to your offset (not remote) " + tostr(orig_offset) + " - user has stopped but you should be able to resume!")
    end if

    screen.metadata.description = screen.metadata.description + " on " + firstof(screen.metadata.nowplaying_platform_title, screen.metadata.nowplaying_platform, "")
    if new_metadata.server.name <> invalid then screen.metadata.description = screen.metadata.description + " [" + new_metadata.server.name + "]" ' show the server 
    screen.metadata.nowPlaying_progress = screen.metadata.description
    screen.metadata.description = screen.metadata.description + chr(10) + screen.metadata.nowPlaying_orig_description ' append the original description
   
    ' on the spring board - we also only want to show the original title - the breadcrumbs will have the user
    if new_metadata.episodestr <> invalid then 
        screen.metadata.titleseason = new_metadata.cleantitle + " - " + new_metadata.episodestr
    else
        screen.metadata.title = new_metadata.cleantitle
    end if
    screen.Screen.setContent(screen.metadata)
    Debug("Refreshing nowPlaying videoSpringBoard content")
end sub

function rfUpdateNowPlayingMetadata(metadata,time = 0 as integer) as object
    ' used mainly on a springboard
    container = createPlexContainerForUrl(metadata.server, metadata.server.serverurl, "/status/sessions")
    keys = container.getkeys()
    found = false

    for index = 0 to container.metadata.count() - 1      '    for index = 0 to keys.Count() - 1
        Debug("Searching for key:" + tostr(metadata.key) + " and machineID:" + tostr(metadata.nowPlaying_maid) ) ' verify same machineID to sync (multiple people can be streaming same content)
        if keys[index] = metadata.key and container.metadata[index].nowPlaying_maid = metadata.nowPlaying_maid then 
            Debug("----- nowPlaying match: key:" + tostr(metadata.key) + ", machineID:" + tostr(metadata.nowPlaying_maid) + " @ " + tostr(metadata.server.serverurl) + "/status/sessions")
            found = true
            Debug("----- prev offset " + tostr(metadata.viewOffset))
            metadata = container.metadata[index]
            if metadata.viewOffset <> invalid then 
                metadata.viewOffset = tostr(metadata.viewOffset.toint() + int(time)) ' just best guess. add on a few seconds since it takes time to buffer
            else 
                metadata.viewOffset = "0"
            end if
            Debug("-----  new offset " + tostr(metadata.viewOffset))
            if time > 0 then  debug("----- added " + tostr(int(time/1000)) + " seconds to offset for sync")
            exit for
        end if
    end for

    if NOT found then
        metadata.viewOffset = invalid
    end if

    return metadata
end function

sub homeCreateNowPlayingRequest() 
    ' only set nowplaying globals if notifications are enabled
    ' this has nothing to do with the home screen now playing rows ( separate requests )
    ' TODO: this will need some work for Audio, Photo ( probably never -- way to chatty )
    if RegRead("rf_notify","preferences","enabled") <> "disabled" then
        for each server in GetOwnedPlexMediaServers()
            ' only query server if available and supportsmultiuser (assuming nowPlaying works with multiuser enabled)
            if server.isavailable and server.supportsmultiuser then
                context = CreateObject("roAssociativeArray")
                context.server = server
                context.key = "nowplaying_sessions"

                ' skip request if still pending
                if hasPendingRequest(context) then return

                ' converted to a non blocking request
                httpRequest = server.CreateRequest("", "/status/sessions" )
                GetViewController().StartRequest(httpRequest, m, context)
                Debug("Kicked off request for now playing sessions on " + tostr(server.name))
            end if
        end for
    end if
end sub

function getNowPlayingNotifications() as object
    if RegRead("rf_notify","preferences","enabled") = "disabled" then return invalid

    notify = []:found = []
    nowPlaying_servers = GetGlobalAA().rf_nowPlaying_servers

    ' iterate through now playing content and set the first unnotified object ( we will grab any others on the next run )
    ' we might want to combined then..
    if type(nowPlaying_servers) = "roAssociativeArray" then 
        for each machineIdentifier in nowPlaying_servers 
            if nowPlaying_servers[machineIdentifier] <> invalid and nowPlaying_servers[machineIdentifier].count() > 0 then
                for each i in nowPlaying_servers[machineIdentifier]
                     nkey = i.maid + "_" + i.key ' this is in case the same machine can play two video.. PMS doesn't allow it ( so overkill )
                     if RegRead(nkey, "rf_notified","false") <> "true" then 
                        i.type = "start"
                        i.title = i.item.title
                        i.text = i.item.description
                        if RegRead("rf_notify_np_type","preferences","all") <> "stop"  then 
                            notify.Push(i) ' set return object
                        else 
                            Debug("skipping start notification due to prefs")
                        end if
                        RegWrite(nkey, "true", "rf_notified") 
        		' TODO - this global should really be an AA
                        GetGlobalAA().AddReplace(nkey + "_user", i.user)
                        GetGlobalAA().AddReplace(nkey + "_title", i.item.CleanTitle)
                        GetGlobalAA().AddReplace(nkey + "_length", i.length) 
                    end if
                    GetGlobalAA().AddReplace(nkey + "_viewOffset", i.item.viewOffset)
                    found.Push(nkey) ' save all now playing for the next checks
                next
            end if
        end for
    end if

    ' Check to verify all seen players are still playing.. otherwise we want to unset (maybe notify at some point) to be able to notify again
    seen = GetGlobalAA().nowplaying_cur
    if type(seen) = "roArray" and seen.count() > 0 then
        for each maid in seen
            Debug( "----- checking if " + tostr(maid) + " is playing")
            RFinarray = false
            for each f_maid in found 
                if f_maid = maid then RFinarray = true
            next    

            if NOT RFinarray then ' if NOT inArray(seen,found) then -- very bad TOFI
                ' notification for stopped content - we will need to grab the itemKey if we want to link the video
                n = CreateObject("roAssociativeArray")
                n.type = "stop" 
                n.title = UcaseFirst(GetGlobalAA().Lookup(maid + "_user"),true) + " stopped " + GetGlobalAA().Lookup(maid + "_title")

                n.viewOffset = GetGlobalAA().Lookup(maid + "_viewOffset")
                n.length = GetGlobalAA().Lookup(maid + "_length")
                if n.length <> invalid then 
                    n.title = "[" + percentComplete(n.viewOffset,n.length.toInt(),true) + "%]" + " " + n.title
                end if
                n.text = ""
                if RegRead("rf_notify_np_type","preferences","all") <> "start"  then 
                    notify.Push(n) 
                else 
                    Debug("skipping stop notification due to prefs")
                end if
                RegDelete(maid, "rf_notified")
                GetGlobalAA().Delete(maid + "_user")
                GetGlobalAA().Delete(maid + "_title")
                GetGlobalAA().Delete(maid + "_length")
                GetGlobalAA().Delete(maid + "_viewOffset")
                Debug("---- removing " + tostr(maid) + " from 'rf_notified' -- video playback stopped")
            else
                Debug("----- " + tostr(maid) + " already notified")
            end if
        next
    end if    

    ' now unset/set currently playing content
    GetGlobalAA().nowplaying_cur = [] 
    GetGlobalAA().AddReplace("nowplaying_cur", found)

    if notify.count() > 0 then return notify
    return invalid
end function

function percentComplete(viewOffset as dynamic, Length as dynamic, round=false as boolean) as String
   'TODO - check if string or integer just to be safe
   if viewOffset <> invalid and length <> invalid then 
       percent = int(((viewOffset.toInt()/1000)/length )*100)
       if round and percent > 90 then return "100"
       return tostr(percent)
   end if
   return "0"
end function

' This needs some work - rough draft - should add link to view videoDetial screen from here
Sub ShowNotifyDialog(obj As dynamic, curIndex = 0, isNowPlaying = false) 
    if m.viewcontroller.IsLocked <> invalid and m.viewcontroller.IsLocked then return
    Debug("showing Dialog notifications ")
    ' isNowPlaying is special - if true, we will show all the NowPlaying items when a user selectes to show the notification (allows this dialog to be used for other notifications)

    if type(obj) = "roArray" then
        item = obj[curIndex]
    else
        item = obj
        obj = []
        obj.push(item)
    end if

    dialog = createBaseDialog()
    dialog.Title = item.title
    dialog.Text = item.text
    dialog.Item = item
    dialog.index = curIndex
    dialog.context = obj
    dialog.isNowPlaying = isNowPlaying

    dialog.HandleButton = notifyDialogHandleButton
    if type(obj) = "roArray" and obj.Count() > 1 then
        dialog.SetButton("fwd", "Next")
        dialog.text = dialog.text + chr(10) ' for overlay 
        dialog.StaticText = tostr(obj.Count()) + " notifications "
    end if
    dialog.text = dialog.text + chr(10) ' for overlay 
    dialog.text = truncateString(dialog.text,200) ' for overlay 
    'dialog.sepBefore.Push("show")
    dialog.SetButton("show", "Show Now Playing")
    dialog.SetButton("close", "Close")
    dialog.Show()
End Sub

Function notifyDialogHandleButton(buttoncommand, index) As Boolean
    close_dialog = false
   
    total = m.context.Count() -1

    refresh = false
    focusbutton = 0
    if buttonCommand = "show" then
        close_dialog = true

        items = []
        itemsIndex = m.index
        if m.isNowPlaying then
            Debug("showing all the now playing items with this item focused in a springBoard screen")
            nowPlaying_servers = GetGlobalAA().rf_nowPlaying_servers
            for each machineIdentifier in nowPlaying_servers 
                if nowPlaying_servers[machineIdentifier] <> invalid and nowPlaying_servers[machineIdentifier].count() > 0 then
                    for each np_item in nowPlaying_servers[machineIdentifier]
                        if m.context[m.index].key = np_item.item.key then itemsIndex = items.count() ' zero index
                        items.Push(np_item.item)
                    end for
                end if
            end for
        else 
            for each i in m.context 
                items.Push(i.item)
            next
        end if

        if items.count() > 0 then 
            m.ViewController.CreateScreenForItem(items, itemsIndex, invalid)
        else 
            ShowErrorDialog("No one is watching anything","Now Playing")
        end if 
    else if buttonCommand = "fwd" then
        m.index = m.index + 1
        if m.index > m.context.Count() - 1 then m.index = 0
        item = m.context[m.index]
        m.title = item.title
	m.text = item.text
        refresh = true
    else if buttonCommand = "rev" then
        m.index = m.index - 1
        if m.index < 0 then m.index = m.context.Count() - 1
        item = m.context[m.index]
        m.title = item.title
	m.text = item.text
        refresh = true
        if m.index > 0 then 
            focusbutton = 1
        end if
    else if buttonCommand = "close" then
        close_dialog = true
    end if

    if refresh then 
        m.FocusedButton = focusbutton
        m.buttons = []
        if m.index < total then 
            m.SetButton("fwd", "Next")
        else 
            m.text = m.text + chr(10) ' for overlay 
        end if
        if m.index > 0 then
            m.SetButton("rev", "Previous")
        else 
            m.text = m.text + chr(10) ' for overlay 
        end if
        m.text = truncateString(m.text,200)
        m.SetButton("show", "Show Now Playing")
        m.SetButton("close", "Close")

        m.Refresh()
    end if

    return close_dialog
End Function

sub setNowPlayingGlobals(msg, requestContext)
        url = tostr(requestContext.Request.GetUrl())

        np_servers = GetGlobalAA().rf_nowPlaying_servers
        if np_servers = invalid then np_servers = {}

        ' container for now playing content ( resets to empty if nothing playing or a failure )
        np = []

        if msg.GetResponseCode() = 200 then 
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + url)

            headers = msg.GetResponseHeaders()
            xml = CreateObject("roXMLElement")
            xml.Parse(msg.GetString())
            response = CreateObject("roAssociativeArray")
            response.xml = xml
            response.server = requestContext.server
            response.sourceUrl = requestContext.Request.GetUrl()
            container = createPlexContainerForXml(response)
            context = container.GetMetadata()
            this_maid = GetGlobalAA().Lookup("rokuUniqueID")

            if context <> invalid and context.count() > 0 then 
                for index = 0 to context.count()-1
                    metadata = context[index]
                    ratingKey = metadata.ratingkey
                    ' ljunkie - for now, we have limited this to Now Playing VIDEO
                    ' it can work for music [track] -- but it's way to chatty 
                    if ratingKey <> invalid and (tostr(metadata.type) = "episode" or tostr(metadata.type) = "movie") then 
                        maid = metadata.nowPlaying_maid
                        user = metadata.nowPlaying_user
                        platform = firstof(metadata.nowPlaying_platform_title, metadata.nowPlaying_platform, "")
                        length = firstof(tostr(metadata.Length), 0)
                        if metadata.episodestr <> invalid then 
                            title = metadata.cleantitle + " - " + metadata.episodestr
                        else
                            title = metadata.cleantitle
                        end if
                        ' let's wait until the EU starts playing.. sometimes people get in buffer/play loops
                        if tostr(metadata.nowplaying_state) = "buffering" then 
                            print "not showing buffering state" + user
                        else if this_maid <> maid then 
                            np.Push({maid: maid, title: title, user: user, key: ratingKey, platform: platform, length: length, item: metadata})
                        end if
                    end if
                end for
            end if
        else 
            ' urlEventFailure - nothing to see here
            failureReason = msg.GetFailureReason()
            Debug("Got a " + tostr(msg.GetResponseCode()) + " response from " + url + " - " + tostr(failureReason))
        end if

        ' set now playing content ( no results/failure is ok -- resets server back to zero results )
        np_servers[requestContext.server.machineid] = np
        GetGlobalAA().AddReplace("rf_nowPlaying_servers", np_servers)
end sub