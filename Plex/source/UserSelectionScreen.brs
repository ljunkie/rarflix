'Preferences Sections to seperate out by user:
'myplex,preferences,servers,userinfo
'Not separate out:
'Default, analytics, misc, 
'
' m.userNum = -1 for no user profiles, 0-3 for the 4 valid users.  note that 4 is an arbitrary number and
'can be increased without limit
'TODO: elminate m.userNum = -1 as interesting???  Why both?
'TODO: (DONE) Check about the screens that are created before homescreen is (-2,-3, etc)
'TODO: Update SecurityPin with better graphics
'TODO: How about using a userNum of -1 and catching that on the Registry stuff for errors!

'*************************************************************************************
'
' Routines for drawing the actual PIN entry screen
'
'*************************************************************************************
'Creates screen for user Selection
Function createUserSelectionScreen(viewController) as object
    TraceFunction("createUserSelectionScreen", viewController)
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.Screen = CreateObject("roImageCanvas")
    obj.Show = userSelectionShow
    obj.HandleMessage = userSelectionHandleMessage
    
    obj.userSelected = -1
    return obj
End Function

Sub userSelectionShow()
    canvasRect = m.screen.GetCanvasRect()   'get screen size
    'HDRectToSDRect(canvasRect)  'JUST FOR TESTING SD!
    m.backgrounds = getBackgrounds()
    picSize = { w:100, h:100 }  'final size of arrow picture
    bufSize = { w:80, h:80 }  'size of empty space between centerpoint and centerpoint of arrows
    textSize = { w:250, h:150 }  'where the name goes
    textBufSize = { w:20, h:5 }  'size of empty space between centerpoint and centerpoint of text
    if GetGlobal("IsHD") <> true then
        'scale down for SD.  Not perfect but good enough on an SD screen. 
        HDRectToSDRect(picSize) 
        HDRectToSDRect(bufSize) 
        HDRectToSDRect(textSize) 
        HDRectToSDRect(textBufSize) 
    end if
    'centerPt of screen
    x=int(canvasRect.w/2)
    y=int(canvasRect.h/2)
    
    buttons = [ 'These can be hardcoded later so long as adjusted for HD->SD 
            'The "-picSize.w/2" means rotate around the middle
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:270.0,TargetTranslation:{x:x-bufSize.w,y:y}}
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:0.0,TargetTranslation:{x:x,y:y-bufSize.h}}
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:90.0,TargetTranslation:{x:x+bufSize.w,y:y}}
            {url:"pkg:/images/arrow-up.png",TargetRect:{x:Int(-picSize.w/2), y:Int(-picSize.h/2), w:picSize.w, h:picSize.h},TargetRotation:180.0,TargetTranslation:{x:x,y:y+bufSize.h}}
              ]
    textArea = [ 'These can be hardcoded later so long as adjusted for HD->SD 
            'The "-picSize.w/2" centers the text boxes
            {text:"Default User",TextAttrs:{Color:"#999999", Font:"Huge",HAlign:"Right", VAlign:"Center", Direction:"LeftToRight"},TargetRect:{x:Int(-picSize.w/2), y:Int(-textSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:buttons[0]["TargetTranslation"].x-textBufSize.w-textSize.w,y:y}}
            {text:"User 1",TextAttrs:{Color:"#999999", Font:"Huge",HAlign:"Center", VAlign:"Bottom", Direction:"LeftToRight"},TargetRect:{x:Int(-textSize.w/2), y:Int(-picSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:x,y:buttons[1]["TargetTranslation"].y-textBufSize.h-textSize.h}}
            {text:"User 2",TextAttrs:{Color:"#999999", Font:"Huge",HAlign:"Left", VAlign:"Center", Direction:"LeftToRight"},TargetRect:{x:Int(picSize.w/2), y:Int(-textSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:buttons[2]["TargetTranslation"].x+textBufSize.w,y:y}}
            {text:"User 3",TextAttrs:{Color:"#999999", Font:"Huge",HAlign:"Center", VAlign:"Top", Direction:"LeftToRight"},TargetRect:{x:Int(-textSize.w/2), y:Int(picSize.h/2), w:textSize.w, h:textSize.h},TargetTranslation:{x:x,y:buttons[3]["TargetTranslation"].y+textBufSize.h}}
              ]
    m.canvasItems = [
        { 
            Text:"Press direction arrow on remote to select User"
            TextAttrs:{Color:"#AAAAAA", Font:"Large",HAlign:"Center", VAlign:"Top",Direction:"LeftToRight"}
            TargetRect:{x:0,y:int(canvasrect.h*.85),w:canvasrect.w,h:0}
        }
    ]
    m.users = [buttons[0],textArea[0]] 'user 0 is always enabled  
    for i = 1 to 3 step 1   'user 0 is always enabled
        if RegReadByUser(i, "userActive", "preferences", "0") = "1" then 
            if RegReadByUser(i, "friendlyName", "preferences", invalid) <> invalid then
                textArea[i]["text"] = RegReadByUser(i, "friendlyName", "preferences", invalid)
            end if 
            m.users.Push(buttons[i])
            m.users.Push(textArea[i])
        end if
    end for 
    'PrintAA(m.users)
    m.screen.SetLayer(0, m.backgrounds["background"])
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.backgrounds["backgroundItems"])
    m.screen.SetLayer(2, m.backgrounds["logoItems"])
    m.screen.SetLayer(3, m.canvasItems)
    m.screen.SetLayer(4, m.users)
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
                m.Screen.Close()
            'else 
            '    Debug("Key Pressed:" + tostr(msg.GetIndex()) + ", pinCode:" + tostr(m.pinCode))
            end if
            if m.userSelected <> -1 then
                'make sure an unavailable user was not selected.  user0 is always active
                if (m.userSelected > 0) and (RegReadByUser(m.userSelected, "userActive", "preferences", "0") <> "1") then 
                    m.userSelected = -1 'disable selection
                else if RegReadByUser(m.userSelected,"securityPincode","preferences",invalid) <> invalid then    'pop up PIN screen when user has a password
                    pinScreen = VerifySecurityPin(m.ViewController, RegReadByUser(m.userSelected,"securityPincode","preferences",invalid), false, 0)
                    m.Activate = userSelectionActivate
                    pinScreen.Show()
                else
                    userSelectUser(m.UserSelected)
                    m.screen.Close()    'for some reason when you use activate and close() within it, the handle loop doesn't seem to get the close message so pop the screen here
                end if
            end if
       end if
    end if    
    return handled
End Function

'Called when screen pops to top after the PIN entering screen completes
sub userSelectionActivate(priorScreen)
    m.Activate = invalid    'dont call this routine again
    if (priorScreen.pinOK = invalid) or (priorScreen.pinOK <> true) then    'either no code was entered, was cancelled or wrong code
        'nothing to do, just wait for the next selection
    else
        'pin is OK, select the user
        userSelectUser(m.UserSelected)
        m.screen.Close()    'for some reason when you use activate and close() within it, the handle loop doesn't seem to get the close message so pop the screen here
        m.ViewController.PopScreen(m)    
    endif
End sub

'TODO - WHAT TO DO HERE?  ONLY VALID ON STARTUP!
sub userSelectUser(userNumber as integer)
    Debug("UserNumber changed to " + tostr(userNumber))
    GetGlobalAA().userNum = userNumber  
    RegSetUserPrefsToCurrentUser()
    GetGlobalAA().ViewController.ShowSecurityScreen = false  
end sub
