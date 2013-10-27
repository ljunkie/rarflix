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
    ViewController.InitializeOtherScreen(obj, invalid)
    return obj
End Function

Sub userSelectionShow()
    canvasRect = m.screen.GetCanvasRect()   'get screen size
    dialogText = "Enter Security PIN for Plex." 'default text
    dialogText2 = "Enter PIN Code using direction arrows on your remote control."   'default text
    if newDialogText <> invalid then dialogText = newDialogText
    if newDialogText2 <> invalid then dialogText2 = newDialogText2
    pinRect = {}
    dlgRect = {} 
    dlgRect2 = {}
    fontRegistry = CreateObject("roFontRegistry")
    fontCurrent = fontRegistry.GetDefaultFont()

    pinRectHeight = int(fontCurrent.GetOneLineHeight() * 3)  'arbitrary number to create space for the large font with border area
    'use the middle of the screen for the PIN code 
    pinRect.w = canvasRect.w    
    pinRect.h = fontCurrent.GetOneLineHeight() 'actual size to use
    pinRect.x = 0 'int((canvasRect.w - pinRect.w) / 2)
    pinRect.y = int((canvasRect.h - pinRect.h) / 2)
    'use 1/4 vertical screen size above and below the pinRect
    dlgRect.w = int((canvasRect.w * 2) / 3) 'horizontally use 2/3 of screen 
    dlgRect.h = int((canvasRect.h * 1) / 4) 'use 1/4 of the vertical screen size  
    dlgRect.x = int((canvasRect.w - dlgRect.w) / 2)
    dlgRect.y = int(((canvasRect.h - pinRectHeight) / 2) - dlgRect.h)
    dlgRect2.w = dlgRect.w
    dlgRect2.h = dlgRect.h
    dlgRect2.x = dlgRect.x
    dlgRect2.y = int(((canvasRect.h + pinRectHeight) / 2))
    if (pinToVerify <> invalid) and (pinToVerify.Len() > 0) then
        m.pinToVerify = pinToVerify
    end if
    
    overhangRect = { x:10,y:125 }
    if GetGlobal("IsHD") <> true then
        'scale down for SD.  Not perfect but good enough on an SD screen.
        HDRectToSDRect(overhangRect)
    end if

    m.backgroundItems = [
        {url:"pkg:/images/Background_HD.jpg", TargetRect:overhangRect},
        {url:"pkg:/images/logo_final_HD.jpg", TargetRect:overhangRect}
    ]
    
    m.canvasItems = [
        {url:"pkg:/images/Background_HD.jpg", TargetRect:overhangRect}

        { 
            Text:"[press arrows]"
            TextAttrs:{Color:"#AAAAAA", Font:"Huge",HAlign:"Center", VAlign:"Top",Direction:"LeftToRight"}
            TargetRect:pinRect
        },
        { 
            Text:dialogText
            TextAttrs:{Color:"#999999", Font:"Large",HAlign:"Center", VAlign:"Bottom", Direction:"LeftToRight"}
            TargetRect:dlgRect
        },
        { 
            Text:dialogText2
            TextAttrs:{Color:"#999999", Font:"Large",HAlign:"Center", VAlign:"Top", Direction:"LeftToRight"}
            TargetRect:dlgRect2
        },
    ] 
    m.screen.SetLayer(0, {Color:"#363636", CompositionMode:"Source"})   'Set opaque background as transparent doesn't draw correctly when content is updated  
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.canvasItems)
    m.Screen.SetMessagePort(m.Port)
    m.Screen.Show()
End Sub

Function userSelectionHandleMessage(msg) As Boolean
    handled = false

    'Debug("userSelectionHandleMessage")
    if type(msg) = "roImageCanvasEvent" then
        handled = true
        if msg.isScreenClosed() then
            'Debug("Exiting user selection  screen")
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
    endif
End sub

sub userSelectUser(userNumber as integer)
    Debug("UserNumber changed to " + AnyToString(userNumber))
    GetGlobalAA().userNum = userNumber  
end sub
