'*****************************************************************
'**  Home screen: the entry display of the application
'**
'*****************************************************************

Function createHomeScreen(viewController) As Object
    ' At the end of the day, the home screen is just a grid with a custom loader.
    ' So create a regular grid screen and override/extend as necessary.
    obj = createGridScreen(viewController, "flat-square")

    obj.SetUpBehaviorAtTopRow("stop")
    obj.Screen.SetDisplayMode("photo-fit")
    obj.Loader = createHomeScreenDataLoader(obj)

    obj.Refresh = refreshHomeScreen

    return obj
End Function

Sub refreshHomeScreen(changes)
    PrintAA(changes)

    ' If myPlex state changed, we need to update the queue, shared sections,
    ' and any owned servers that were discovered through myPlex.
    if changes.DoesExist("myplex") then
        m.Loader.OnMyPlexChange()
    end if

    ' If a server was added or removed, we need to update the sections,
    ' channels, and channel directories.
    if changes.DoesExist("servers") then
        for each server in PlexMediaServers()
            if server.machineID <> invalid AND GetPlexMediaServer(server.machineID) = invalid then
                PutPlexMediaServer(server)
            end if
        next

        servers = changes["servers"]
        didRemove = false
        for each machineID in servers
            Debug("Server " + tostr(machineID) + " was " + tostr(servers[machineID]))
            if servers[machineID] = "removed" then
                DeletePlexMediaServer(machineID)
                didRemove = true
            else
                server = GetPlexMediaServer(machineID)
                if server <> invalid then
                    m.Loader.CreateServerRequests(server, true, false)
                end if
            end if
        next

        if didRemove then
            m.Loader.RemoveInvalidServers()
        end if
    end if

    ' Recompute our capabilities
    Capabilities(true)
End Sub

Sub ShowHelpScreen()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)
    screen.AddHeaderText("Welcome to Plex for Roku!")
    screen.AddParagraph("Plex for Roku automatically connects to Plex Media Servers on your local network and also works with myPlex to view queued items and connect to your published and shared servers.")
    screen.AddParagraph("To download and install Plex Media Server on your computer, visit http://plexapp.com/getplex")
    screen.AddParagraph("For more information on getting started, visit http://plexapp.com/roku")
    screen.AddButton(1, "close")

    screen.Show()

    while true
        msg = wait(0, port)
        if type(msg) = "roParagraphScreenEvent" then
            if msg.isButtonPressed() OR msg.isScreenClosed() then
                exit while
            end if
        end if
    end while
End Sub
