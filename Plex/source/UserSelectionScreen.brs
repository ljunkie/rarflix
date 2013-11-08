'This module holds the multiple-user support for Plex
'
'Multi-user support is implemented by creating separate preference sections for
'each user profile.  There are Reg*() routines that handle all this automatically
'for you.  Just call the usual RegRead() and RegWrite() and they
'will read/write to the correct preference.
'
'The "default user" or "User 0" is special, in that the preference sections
'for that user are the same as they are without multiple users.  This makes
'upgrading easy.  For Users1-3, their preference sections are the usual section
'names but with a "_uN" added onto them.  But again, the Reg*() routines will
'handle this conversion.
'
'Multi-user also allows a security PIN (a sequence of the directional arrows)
'for any of the user profiles.
'
'Limitations:
'*   Switching users requires restarting the channel
'*   User number is limited to 4.  That is a limit set by the desire to have a single
'    button user selection (the direction arrows) on start-up.  That can easily be increased
'    without limit with a different user selection screen.


'*************************************************************************************
'
' Routines for drawing the user selection screen
'
'*************************************************************************************
'Creates screen for user Selection
Function createUserSelectionScreen(viewController) as object
    'TraceFunction("createUserSelectionScreen", viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.Screen = CreateObject("roImageCanvas")
    obj.Show = userSelectionShow
    obj.HandleMessage = userSelectionHandleMessage
    obj.BaseActivate = obj.Activate
    
    obj.userSelected = -1
    obj.theme = getImageCanvasTheme()
    'count users
    obj.userCount = 1
    obj.userPages = 1 ' possible we have enabled user 1,2 and 5 -- we will need to show next page button
    obj.currentUserPage = 0
    for i = 1 to 7 step 1   'user 0 is always enabled
        if RegRead("userActive", "preferences", "0", i) = "1" then
            obj.userCount = obj.userCount + 1 
            if i > 4 then obj.userPages = 2
            'if i > 8 then obj.userPages = 3 if for some reason this happens down the road?
        end if
    end for 
    return obj
End Function

Sub userSelectionShow(refresh=false as Boolean)
    'Check for other users enabled -- otherwise, bypass
    if GetGlobalAA().ViewController.SkipUserSelection then 
        if m.userSelected = invalid then m.userSelected = 0
        pinScreen = VerifySecurityPin(m.ViewController, RegRead("securityPincode","preferences",invalid,m.userSelected), false, 2)
        m.ViewController.InitializeOtherScreen(pinScreen, ["Access to RARflix"])
        m.Activate = userSelectionActivate
        pinScreen.Show()
        return
    end if

    canvasRect = m.screen.GetCanvasRect()   'get screen size
    'HDRectToSDRect(canvasRect)  'JUST FOR TESTING SD!
    picSize = { w:100, h:100 }  'final size of arrow picture
    bufSize = { w:80, h:80 }  'size of empty space between centerpoint and centerpoint of arrows
    textSize = { w:250, h:150 }  'where the name goes
    textBufSize = { w:20, h:5 }  'size of empty space between centerpoint and centerpoint of text
    offsetSize = { h:50 }       'amount to offset the center of the drawing objects from the center of the screen 
    if GetGlobal("IsHD") <> true then
        'scale down for SD.  Not perfect but good enough on an SD screen. 
        HDRectToSDRect(picSize) 
        HDRectToSDRect(bufSize) 
        HDRectToSDRect(textSize) 
        HDRectToSDRect(textBufSize) 
        HDRectToSDRect(offsetSize) 
    end if
    'centerPt of screen
    x=int(canvasRect.w/2)
    y=int(canvasRect.h/2)-offsetSize.h
    
    buttons = [ 'These can be hardcoded later so long as adjusted for HD->SD 
            'The "-picSize.w/2" means rotate around the middle
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:270.0,TargetTranslation:{x:x-bufSize.w,y:y}}
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:0.0,TargetTranslation:{x:x,y:y-bufSize.h}}
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:90.0,TargetTranslation:{x:x+bufSize.w,y:y}}
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:180.0,TargetTranslation:{x:x,y:y+bufSize.h}}
              ]
    textArea = [ 'These can be hardcoded later so long as adjusted for HD->SD 
            'The "-picSize.w/2" centers the text boxes
            {text:"Default User",TextAttrs:{Color:m.theme.colors.detailText, Font:"Huge",HAlign:"Right", VAlign:"Center", Direction:"LeftToRight"},TargetRect:{x:Int(-picSize.w/2), y:Int(-textSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:buttons[0]["TargetTranslation"].x-textBufSize.w-textSize.w,y:y}}
            {text:"User 1",TextAttrs:{Color:m.theme.colors.detailText, Font:"Huge",HAlign:"Center", VAlign:"Bottom", Direction:"LeftToRight"},TargetRect:{x:Int(-textSize.w/2), y:Int(-picSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:x,y:buttons[1]["TargetTranslation"].y-textBufSize.h-textSize.h}}
            {text:"User 2",TextAttrs:{Color:m.theme.colors.detailText, Font:"Huge",HAlign:"Left", VAlign:"Center", Direction:"LeftToRight"},TargetRect:{x:Int(picSize.w/2), y:Int(-textSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:buttons[2]["TargetTranslation"].x+textBufSize.w,y:y}}
            {text:"User 3",TextAttrs:{Color:m.theme.colors.detailText, Font:"Huge",HAlign:"Center", VAlign:"Top", Direction:"LeftToRight"},TargetRect:{x:Int(-textSize.w/2), y:Int(picSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:x,y:buttons[3]["TargetTranslation"].y+textBufSize.h}}
              ]
    m.canvasItems = [
        { 
            Text:"Press direction arrow on remote to select User"
            TextAttrs:{Color:m.theme.colors.normalText, Font:"Large",HAlign:"Center", VAlign:"Top",Direction:"LeftToRight"}
            TargetRect:{x:0,y:int(canvasrect.h*.75),w:canvasrect.w,h:0}
        }
    ]
    m.users = []
    start = 0  
    if m.currentUserPage = 1 then
        start = 4
    end if
    for i = start to (start+3) step 1   'user 0 is always enabled
        if (i=0) or (RegRead("userActive", "preferences", "0", i) = "1") then
            index = int(i AND 3)
            friendlyName = RegRead("friendlyName", "preferences", invalid, i)
            if friendlyName <> invalid and friendlyName <> "" then
                textArea[index]["text"] = RegRead("friendlyName", "preferences", invalid, i)
            else if i = 0 then
                textArea[index]["text"] = "Default User"
            else 
                textArea[index]["text"] = "User " + tostr(i)
            endif 
            m.users.Push(buttons[index])
            m.users.Push(textArea[index])
        end if
    end for
    m.screen.AllowUpdates(false)    'lock screen from drawing
    if refresh = true then 
        m.screen.ClearButtons()
    end if
    m.theme["breadCrumbs"][0]["text"] = "User Profile Selection"
    m.screen.SetLayer(0, m.theme["background"])
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.theme["backgroundItems"])
    m.screen.SetLayer(2, m.theme["logoItems"])
    m.screen.SetLayer(3, m.canvasItems)
    m.screen.SetLayer(4, m.users)
    m.screen.SetLayer(5, m.theme["breadCrumbs"])
    if m.userPages > 1 then ' if m.userCount > 4 then
        if m.currentUserPage = 0 then 
            m.screen.AddButton(0, "Next User Profile page")
        else
            m.screen.AddButton(0, "Previous User Profile page")
        end if 
    end if
    m.screen.AllowUpdates(true)    'Update it now
    m.Screen.SetMessagePort(m.Port)
    m.Screen.Show()
End Sub

Function userSelectionHandleMessage(msg) As Boolean
    handled = false

    'Debug("userSelectionHandleMessage")
    if type(msg) = "roImageCanvasEvent" then
        handled = true
        if msg.isScreenClosed() then
            Debug("Exiting user selection  screen")
            m.ViewController.PopScreen(m)
        else if (msg.isRemoteKeyPressed()) then
            'codes = bslUniversalControlEventCodes() 'print codes
            i = msg.GetIndex()
            If i=2 Then 'codes.button_up_pressed
                m.userSelected = 1
            Else If i=3 Then 'codes.button_down_pressed
                m.userSelected = 3
            Else If i=4 Then 'codes.button_left_pressed 
                m.userSelected = 0
            Else If i=5 Then 'codes.button_right_pressed
                m.userSelected = 2
            else If i=0 Then   ' Back - Close the screen and exit 'codes.button_back_pressed
                m.userSelected = -1
                end ' we will exit the roku application on back button 
            end if
            if m.userSelected <> -1 then
                if m.currentUserPage <> 0 then
                    m.userSelected = m.userSelected + 4
                end if
                'make sure an unavailable user was not selected.  user0 is always active
                if (m.userSelected > 0) and (RegRead("userActive", "preferences", "0",m.userSelected) <> "1") then 
                    m.userSelected = -1 'disable selection
                else if RegRead("securityPincode","preferences",invalid,m.userSelected) <> invalid then    'pop up PIN screen when user has a password
                    pinScreen = VerifySecurityPin(m.ViewController, RegRead("securityPincode","preferences",invalid,m.userSelected), false, 2)
                    m.ViewController.InitializeOtherScreen(pinScreen, ["Access to RARFlix"])
                    m.Activate = userSelectionActivate
                    pinScreen.Show()
                else
                    userSelectUser(m.UserSelected)
                    m.screen.Close()    'for some reason when you use activate and close() within it, the handle loop doesn't seem to get the close message so pop the screen here
                end if
            end if
        else if (msg.isButtonPressed()) then 'OK Button was pressed.  this can only happen when there are > 4 user profiles
            if m.currentUserPage = 0 then
                m.currentUserPage = 1
            else 
                m.currentUserPage = 0
            end if
            m.Show(true) 'redraw screen
        end if
    end if    
    return handled
End Function

'Called when screen pops to top after the PIN entering screen completes
sub userSelectionActivate(priorScreen)
    m.Activate = m.BaseActivate    'dont call this routine again
    if (priorScreen.pinOK = invalid) or (priorScreen.pinOK <> true) then    'either no code was entered, was cancelled or wrong code
        'nothing to do, just wait for the next selection
    else
        'pin is OK, select the user
        userSelectUser(m.UserSelected)
        m.screen.Close()    'for some reason when you use activate and close() within it, the handle loop doesn't seem to get the close message so pop the screen here
        m.ViewController.PopScreen(m)    
    endif
End sub

'Switch the user.  In the end, pretty simple!
sub userSelectUser(userNumber as integer)
    Debug("UserNumber changed to " + tostr(userNumber))
    GetGlobalAA().userNum = userNumber  
    RegSetUserPrefsToCurrentUser()
    initTheme() 're-read rarflix theme
    GetGlobalAA().ViewController.ShowSecurityScreen = false  
end sub
