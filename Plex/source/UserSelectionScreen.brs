'Preferences Sections to seperate out by user:
'myplex,preferences,servers,userinfo
'Not separate out:
'Default, analytics, misc, 
'
' m.userNum = -1 for no user profiles, 0-3 for the 4 valid users.  note that 4 is an arbitrary number and
'can be increased without limit
'
'todo
'setup conversion (with flag) to convert from single user to multi-user
'
'LEFTOFF: Registry done.  Start designing user screen 
'
'remove: EnterSecurityCode I think


'*************************************************************************************
'
' Routines for drawing the actual PIN entry screen
'
'*************************************************************************************
'Creates screen for user Selection
Function createUserSelectionScreen(viewController) as object
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
    'overhangRect = { x:0,y:125 }
    overhangRect = { x:125,y:10 }
    picSize = { w:100, h:100 }  'final size of arrow picture
    bufSize = { w:20, h:20 }  'size of empty buffer between centerpoint and edge of arrows
    textSize = { w:150, h:150 }  'where the name goes
    if GetGlobal("IsHD") <> true then
        'scale down for SD.  Not perfect but good enough on an SD screen. 
        HDRectToSDRect(picSize) 
        HDRectToSDRect(bufSize) 
        HDRectToSDRect(overhangRect) 
    end if
    centerPt = { x:int(canvasRect.w/2),y:int(canvasRect.h/2) }
    
    buttons = [ 'These can be hardcoded later so long as adjusted for HD->SD 
            {url:"pkg:/images/arrow-left.png", TargetRect:{x:int(centerPt.x-picSize.w-bufSize.w),y:int(centerPt.y-(picSize.h/2)),w:picSize.w,h:picSize.h}},
            {url:"pkg:/images/arrow-up.png",   TargetRect:{x:int(centerPt.x-(picSize.w/2)),y:int(centerPt.y-bufSize.h-picSize.h),w:picSize.w,h:picSize.h}},
            {url:"pkg:/images/arrow-right.png", TargetRect:{x:int(centerPt.x+bufSize.w),y:int(centerPt.y-(picSize.h/2)),w:picSize.w,h:picSize.h}},
            {url:"pkg:/images/arrow-down.png", TargetRect:{x:int(centerPt.x-(picSize.w/2)),y:int(centerPt.y+bufSize.h),w:picSize.w,h:picSize.h}}
              ]
    PrintAA(buttons[0])
    PrintAA(buttons[1])
    PrintAA(buttons[2])
    PrintAA(buttons[3])

    m.backgroundItems = [
        {url:"pkg:/images/Background_HD.jpg"}
    ]
    m.logoItems = [
        {url:"pkg:/images/logo_final_HD.png", TargetRect:overhangRect}
    ]
    m.canvasItems = [
        { 
            Text:"[press arrows]"
            TextAttrs:{Color:"#AAAAAA", Font:"Huge",HAlign:"Center", VAlign:"Top",Direction:"LeftToRight"}
            TargetRect:{x:640,y:360,w:500,h:100}
        },
    ]
    m.users = []
    'for i = 0 to 3 step 1
    '    if RegReadByUser(i, "userActive", "userinfo", true) = true then 'RICK - change to first true to false
    '        obj = CreateObject("roAssociativeArray")
    '        o.Add(
    '    end if
    'end for 
    m.users = buttons
    m.screen.SetLayer(0, {Color:"#880000", CompositionMode:"Source"})   'Set opaque background as transparent doesn't draw correctly when content is updated  '#363636
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.backgroundItems)
    m.screen.SetLayer(2, m.logoItems)
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
            'if m.ViewController.afterCloseCallback <> invalid
            '    m.ViewController.afterCloseCallback.pinCode = m.pinCode 'store pinCode in callback obj
            'end if
            m.ViewController.PopScreen(m)
        else if (msg.isRemoteKeyPressed()) then
            codes = bslUniversalControlEventCodes() 'print codes
            i = msg.GetIndex()
            If i=codes.button_up_pressed Then
                m.userSelected = 1
            Else If i=codes.button_down_pressed Then
                m.userSelected = 3
            Else If i=codes.button_right_pressed Then
                m.userSelected = 2
            Else If i=codes.button_left_pressed Then
                m.userSelected = 0
            else If i=codes.button_back_pressed Then   ' Back - Close the screen and exit
                m.userSelected = -1
                m.Screen.Close()
            else 
                Debug("Key Pressed:" + AnyToString(msg.GetIndex()) + ", pinCode:" + AnyToString(m.pinCode))
                'm.pinCode = left(m.pinCode, m.maxPinLength)   'limit to maxPinLength characters
                'm.canvasItems[0].Text = left(m.txtMasked, m.pinCode.Len())  'm.canvasItems[0].Text = m.pinCode to display code
                'm.Screen.SetLayer(1, m.canvasItems)
            end if
            'todo: validate user is real, otherwise set m.userSelect = -1
            if m.userSelected <> -1 then
                if RegReadByUser(m.userSelected,"securityPincode","preferences",invalid) <> invalid then    'pop up PIN screen when user has a password
                    pinScreen = VerifySecurityPin(m.ViewController, RegReadByUser(m.userSelected,"securityPincode","preferences",invalid), false, 0)
                    m.Activate = userSelectionActivate
                    pinScreen.Show()
                else
                    userSelectUser(m.UserSelected)
                end if
            end if
       'else if (msg.isButtonPressed()) then 'OK Button was pressed
       '    m.Screen.Close()
       end if
    end if    
    return handled
End Function

'Called when screen pops to top after the PIN entering screen completes
sub userSelectionActivate(priorScreen)
    m.Activate = invalid    'dont call this routine again
    'Debug("prefsSecurityPinHandleUnlock")
    if (priorScreen.pinOK = invalid) or (priorScreen.pinOK <> true) then    'either no code was entered, was cancelled or wrong code
        'nothing to do, just wait for the next selection
    else
        'pin is OK, select the user
        'm.EnteredPin = true
        userSelectUser(m.UserSelected)
        m.screen.Close()    'for some reason when you use activate and close() within it, the handle loop doesn't seem to get the close message so pop the screen here
        m.ViewController.PopScreen(m)    
    endif
End sub

sub userSelectUser(userNumber as integer)
    Debug("UserNumber changed to " + AnyToString(userNumber))
    'GetGlobalAA().userNum = userNumber  
    'RegSetUserPrefsToCurrentUser()
end sub
