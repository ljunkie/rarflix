'*****************************************************************
'**  Security Pin Screen
'**
'*****************************************************************
Library "v30/bslCore.brs" 
'*****************************************************************
' This file introduces security pins for PLEX 
' Security PINS are simply any sequence of keys on the remote.
' Note that currently the keys are limited to just the direction keys
' but that can be changed at any time.
'
'The lowest level is accessed by createSecurityPINEntryScreen()
'and following the usual ViewController methods.  That said there are
'two defined methods and wrapper for these.   
'
'Security pins can be verified by calling VerifySecurityPin().  See the 
'function docs for exact specs but this opens up two screens.  The first
'screen is simply to keep the user from seeing the Home screen whenever
'a bad password is entered.  This has built-in functionality to exit plex
'when a bad password is entered.  It is also flexible enough to be 
'called at anytime, in preparation for multiple users down the road
'
'Security pins can be entered by calling SetSecurityPin().  See the 
'PreferencesScreens.brs for an implementation.  Otherwise is very
'similar to VerifySecurityPin()
'
'*****************************************************************

'*************************************************************************************
'
' Routines for drawing the actual PIN entry screen
'
'*************************************************************************************
'Creates screen for PIN entry
Function createSecurityPINEntryScreen(viewController) as object
    obj = CreateObject("roAssociativeArray")
    initBaseScreen(obj, viewController)

    obj.pinCode = ""
    obj.maxPinLength = 20
    obj.txtMasked = "**********************"
    obj.Screen = CreateObject("roImageCanvas")
    obj.Show = securityPINEntryShow
    obj.HandleMessage = securityPINEntryHandleMessage
    obj.SetBreadcrumbText = securityPINEntrySetBreadcrumbText
    obj.txtTop = "Enter Security PIN for RARflix" 'default text
    obj.txtBottom = "Enter PIN Code using direction arrows on your remote control.  When you have entered the correct code you will automatically continue.  Press OK when done."   'default text
    obj.theme = getImageCanvasTheme()
    return obj
End Function

Sub securityPINEntrySetBreadcrumbText(bread2)
    if m.theme = invalid then return    'just in case
    if bread2 = invalid then bread2 = ""
    m.theme["breadCrumbs"][0]["text"] = bread2
end sub

'Shows PIN entry screen.  OK Button is nice to have on for setting a new PIN.  if pinToVerify is set, then window will be closed once the PIN is entered
'if blocking=true then uses own messagePort and blocks global message loop
Sub securityPINEntryShow(showOKButton=true as boolean, pinToVerify="" as string, blocking=false as boolean)
    canvasRect = m.screen.GetCanvasRect()   'get screen size
    'HDRectToSDRect(canvasRect)  'JUST FOR TESTING SD!
    pinRect = {x:0,y:360,w:1280,h:0}        'set .h and .y programmatically
    topRect = {x:200,y:100,w:880,h:0}       'set .h programmatically
    bottomRect = {x:200,y:360,w:880,h:360}  'set .h and .y programmatically
    if GetGlobal("IsHD") <> true then
        'scale down for SD.  Not perfect but good enough on an SD screen. 
        HDRectToSDRect(picSize) 
        HDRectToSDRect(topRect) 
        HDRectToSDRect(bottomRect) 
    end if
    fontRegistry = CreateObject("roFontRegistry")
    fontCurrent = fontRegistry.GetDefaultFont()
    'use the middle of the screen for the PIN code 
    pinRect.h = int(fontCurrent.GetOneLineHeight() * 3)  'arbitrary multiplier to create space for the large font with border area.  
    pinRect.y = int((canvasRect.h - pinRect.h) / 2)
    'resize rects
    topRect.h = pinRect.y-topRect.y
    bottomRect.y = pinRect.y + pinRect.h
    bottomRect.h = canvasRect.h - bottomRect.y
    
    PrintAA(pinRect)
    PrintAA(topRect)
    PrintAA(bottomRect)
    if (pinToVerify <> invalid) and (pinToVerify <> "") then
        m.pinToVerify = pinToVerify
    end if
    m.canvasItems = [
        { 
            Text:"[press arrows]"
            TextAttrs:{Color:m.theme.colors.detailText, Font:"Huge",HAlign:"Center", VAlign:"Center",Direction:"LeftToRight"}
            TargetRect:pinRect
        },
        { 
            Text:m.txtTop
            TextAttrs:{Color:m.theme.colors.normalText, Font:"Large",HAlign:"Center", VAlign:"Bottom", Direction:"LeftToRight"}
            TargetRect:topRect
        },
        { 
            Text:m.txtBottom
            TextAttrs:{Color:m.theme.colors.normalText, Font:"Large",HAlign:"Center", VAlign:"Top", Direction:"LeftToRight"}
            TargetRect:bottomRect
        },
    ] 
    m.screen.SetLayer(0, m.theme["background"])
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.theme["backgroundItems"])
    m.screen.SetLayer(2, m.theme["logoItems"])
    m.screen.SetLayer(3, m.theme["breadCrumbs"])
    m.screen.SetLayer(4, m.canvasItems)
    if showOKButton = true then
        m.screen.AddButton(0, "OK")
    end if
    if blocking then    'use own message port and block the global message loop
        m.Port = CreateObject("roMessagePort")
    end if
    m.Screen.SetMessagePort(m.Port)
    m.Screen.Show()
    if blocking then
        while m.ScreenID = m.ViewController.Screens.Peek().ScreenID
            msg = wait(0, m.Port)
            m.HandleMessage(msg)
        end while    
    end if 
End Sub

Function securityPINEntryHandleMessage(msg) As Boolean
    handled = false

    'Debug("securityPINEntryHandleMessage")
    if type(msg) = "roImageCanvasEvent" then
        handled = true
        if msg.isScreenClosed() then
            'Debug("Exiting PIN screen")
            if m.ViewController.afterCloseCallback <> invalid
                m.ViewController.afterCloseCallback.pinCode = m.pinCode 'store pinCode in callback obj
            end if
            m.ViewController.PopScreen(m)
        else if (msg.isRemoteKeyPressed()) then
            'codes = bslUniversalControlEventCodes() 'print codes
            i = msg.GetIndex()
            If i=2 Then         'codes.button_up_pressed 
                m.pinCode = m.pinCode + "U"
            Else If i=3 Then    'codes.button_down_pressed 
                m.pinCode = m.pinCode + "D"
            Else If i=4 Then    'codes.button_left_pressed 
                m.pinCode = m.pinCode + "L"
            Else If i=5 Then    'codes.button_right_pressed
                m.pinCode = m.pinCode + "R"
            end if
            if (m.pinToVerify <> invalid) and (m.pinToVerify = m.pinCode) then  'Immediately exit once correct PIN is entered
                m.Screen.Close()
            else If i=0 Then   ' Back - Close the screen and exit without the pinCode    'codes.button_back_pressed
                m.pinCode = ""
                m.Screen.Close()
            Else If i=6 Then  'this only shows up when there is no OK button             'codes.button_select_pressed 
                m.Screen.Close()
            else 
                'Debug("Key Pressed:" + tostr(msg.GetIndex()) + ", pinCode:" + tostr(m.pinCode))
                m.pinCode = left(m.pinCode, m.maxPinLength)   'limit to maxPinLength characters
                m.canvasItems[0].Text = left(m.txtMasked, m.pinCode.Len())  'm.canvasItems[0].Text = m.pinCode to display code
                m.Screen.SetLayer(4, m.canvasItems)
            end if
       else if (msg.isButtonPressed()) then 'OK Button was pressed
           m.Screen.Close()
       end if
    end if    
    return handled
End Function

'*************************************************************************************
'
' Routines for verifying a PIN, either at startup or on a user change
'
'*************************************************************************************
'Enter PIN code.  if exitAppOnFailure then this returns what happened by setting screen.pinOK=true (invalid if not).  Use the "Activated" function to catch this returning
'Returns the screen object to the facade screen
function VerifySecurityPin(viewController, pinToValidate as String, exitAppOnFailure=false as Boolean, numRetries=5 as Integer) as object
    'create master screen for verifying PIN
    screen = createSecurityPinScreen(viewController, pinToValidate)
    'members for verifying code
    screen.numRetries = numRetries
    screen.exitAppOnFailure = exitAppOnFailure
    screen.Activate = VerifySecurityPinActivate
    return screen
End function

'Called when screen pops to top after the PIN entering screen completes
sub VerifySecurityPinActivate(priorScreen)
    'Debug("VerifySecurityPinActivate")
    if priorScreen.pinCode = m.pinToValidate then
        m.pinOK = true
        if m.ViewController.ShowSecurityScreen <> invalid then m.ViewController.ShowSecurityScreen = false
        m.screen.Close()    'Closing from within Activate never calls the message loop to pop the screen
        m.ViewController.PopScreen(m)   'close this screen
    else 'if type(screen.Screen) = "roImageCanvas"  'ensure that there wasn't some type of pop-up 'update:removed as I can't see how this can occur
        if m.numRetries <= 0 then
            if m.exitAppOnFailure = true then  'Close the home screen which causes an exit
                m.ViewController.PopScreen(m.ViewController.home)
            else
                m.screen.Close()    'Closing from within Activate never calls the message loop to pop the screen
                m.ViewController.PopScreen(m)   'close this screen
            end if
        else
            m.numRetries = m.numRetries - 1
            m.pinScreen = createSecurityPINEntryScreen(m.ViewController)
            m.ViewController.InitializeOtherScreen(m.pinScreen, [m.breadCrumb])
            m.pinScreen.txtTop = "Incorrect Security PIN. Re-enter Security PIN." 
            m.pinScreen.Show(false)
        end if
    end if
End sub

'*************************************************************************************
'
' Routines for entering a PIN
'
'*************************************************************************************
'Returns the screen object to the facade screen.  New PIN is returned in screen.newPinCode
function SetSecurityPin(viewController) as object
    'Debug("SetSecurityPin")
    'create master screen for verifying PIN
    screen = createSecurityPinScreen(viewController, "")
    'members for verifying code
    screen.newPinCode = ""
    screen.Activate = SetSecurityPinActivate
    return screen
End function

'Called when screen pops to top after the PIN entering screen completes.  Called after either a PIN has been entered or cancelled
sub SetSecurityPinActivate(priorScreen)
    'Debug("SetSecurityPinActivate")
    if (priorScreen.pinCode = invalid) or (priorScreen.pinCode ="") then    'either no code was entered or it was cancelled
        m.newPinCode = ""  'report back that no pin was created
        m.ViewController.PopScreen(m)   'close this screen
    else if m.newPinCode = "" then  'just entered the first pinCode.  re-enter to validate
        'Create second PIN verification screen
        m.newPinCode = priorScreen.pinCode
        m.pinScreen = createSecurityPINEntryScreen(m.ViewController)
        m.ViewController.InitializeOtherScreen(m.pinScreen, [m.breadCrumb])
        m.pinScreen.txtTop = "Re-enter the PIN code to verify."                 'change the new text
        m.pinScreen.txtBottom = "Enter PIN Code using direction arrows on your remote control.  When you have entered the correct code you will automatically continue.  Press OK to try again."
        m.pinScreen.Show(false, m.newPinCode)
    else 'verify 2nd pinCode
        if m.newPinCode <> priorScreen.pinCode then  'pinCodes don't match
            m.newPinCode = ""  'report back that no pin was created
        end if
        m.ViewController.PopScreen(m)   'close this screen
    endif
End sub


'*************************************************************************************
'
' Shared routines for creating and managing PIN entry screens 
'
'*************************************************************************************
'Common function to create screen.  Used both when verifying and setting PIN
function createSecurityPinScreen(viewController, pinToValidate = "" as string) as object
    'create master screen for verifying PIN
    screen = CreateObject("roAssociativeArray")
    initBaseScreen(screen, viewController)
    'use a blank screen to reduce the annoying flashing to the Home screen when a bad password is entered
    screen.Screen = CreateObject("roImageCanvas") 'using this screen type as it's lightweight and will block whats behind it
    screen.Screen.SetMessagePort(m.Port)
    screen.Show = securityPinShow
    screen.pinToValidate = pinToValidate
    screen.HandleMessage = securityPinHandleMessage
    screen.SetBreadcrumbText = securityPinSetBreadcrumbText
    screen.theme = getImageCanvasTheme()
    return screen
End function

Function securityPinHandleMessage(msg) As Boolean
    handled = false
    
    'Debug("securityPinHandleMessage")
    if type(msg) = "roImageCanvasEvent" then
        handled = true
        if msg.isScreenClosed() then
            'Debug("Exiting PIN Verification facade screen")
            m.ViewController.PopScreen(m)
        end if
    end if
    return handled
End Function

sub securityPinShow(showOKButton=false as boolean)
    'Debug("securityPinShow")
    'show the actual facade screen that blocks the background
    m.screen.SetLayer(0, m.theme["background"])
    m.screen.SetRequireAllImagesToDraw(true)
    m.screen.SetLayer(1, m.theme["backgroundItems"])
    m.screen.SetLayer(2, m.theme["logoItems"])
    m.screen.SetLayer(3, m.theme["breadCrumbs"])
    m.screen.Show()
    
    'Create first PIN verification screen
    m.pinScreen = createSecurityPINEntryScreen(m.ViewController)
    m.ViewController.InitializeOtherScreen(m.pinScreen, [m.breadCrumb])
    if m.txtTop <> invalid then m.pinScreen.txtTop = m.txtTop    'copy text to actual pinScreen
    if m.txtBottom <> invalid then m.pinScreen.txtBottom = m.txtBottom   'copy text to actual pinScreen
    m.pinScreen.Show(showOKButton, m.pinToValidate)
End sub

Sub securityPinSetBreadcrumbText(bread2)
    'TraceFunction("securityPinSetBreadcrumbText", bread2)
    if m.theme = invalid then return    'just in case
    if bread2 = invalid then bread2 = ""
    m.breadCrumb = bread2
    m.theme["breadCrumbs"][0]["text"] = m.breadCrumb
    'send breadcrumb to pinScreen if it exists
    if (m.pinScreen <> invalid) and (m.pinScreen.SetBreadcrumbText <> invalid) then
        m.pinScreen.SetBreadcrumbText(m.breadCrumb)
    end if
end sub



