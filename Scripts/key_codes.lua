local M = {}

-- Numeric representation used by the first consumer prototype: Windows virtual-key codes.
-- Unreal FKey names are mapped explicitly; unsupported keys return nil and never touch stock state.
local byName = {
    None=0, -- existing unbound numeric value; Escape is deliberately not bindable
    LeftMouseButton=0x01, RightMouseButton=0x02, MiddleMouseButton=0x04,
    ThumbMouseButton=0x05, ThumbMouseButton2=0x06,

    BackSpace=0x08, Tab=0x09, Clear=0x0C, Enter=0x0D,
    Pause=0x13, CapsLock=0x14, SpaceBar=0x20,
    PageUp=0x21, PageDown=0x22, End=0x23, Home=0x24,
    Left=0x25, Up=0x26, Right=0x27, Down=0x28,
    Select=0x29, Print=0x2A, Execute=0x2B, PrintScreen=0x2C,
    Insert=0x2D, Delete=0x2E, Help=0x2F,

    LeftCommand=0x5B, RightCommand=0x5C, Menu=0x5D, Sleep=0x5F,
    NumPadZero=0x60, NumPadOne=0x61, NumPadTwo=0x62, NumPadThree=0x63,
    NumPadFour=0x64, NumPadFive=0x65, NumPadSix=0x66, NumPadSeven=0x67,
    NumPadEight=0x68, NumPadNine=0x69, Multiply=0x6A, Add=0x6B,
    Separator=0x6C, Subtract=0x6D, Decimal=0x6E, Divide=0x6F,
    NumLock=0x90, ScrollLock=0x91,
    LeftShift=0xA0, RightShift=0xA1,
    LeftControl=0xA2, RightControl=0xA3,
    LeftAlt=0xA4, RightAlt=0xA5,

    BrowserBack=0xA6, BrowserForward=0xA7, BrowserRefresh=0xA8,
    BrowserStop=0xA9, BrowserSearch=0xAA, BrowserFavorites=0xAB, BrowserHome=0xAC,
    VolumeMute=0xAD, VolumeDown=0xAE, VolumeUp=0xAF,
    MediaNextTrack=0xB0, MediaPreviousTrack=0xB1, MediaStop=0xB2, MediaPlayPause=0xB3,
    LaunchMail=0xB4, LaunchMediaSelect=0xB5, LaunchApp1=0xB6, LaunchApp2=0xB7,

    Zero=0x30, One=0x31, Two=0x32, Three=0x33, Four=0x34,
    Five=0x35, Six=0x36, Seven=0x37, Eight=0x38, Nine=0x39,

    Semicolon=0xBA, Equals=0xBB, Comma=0xBC, Hyphen=0xBD,
    Period=0xBE, Slash=0xBF, Tilde=0xC0, LeftBracket=0xDB,
    Backslash=0xDC, RightBracket=0xDD, Apostrophe=0xDE,
}

for c=string.byte('A'),string.byte('Z') do byName[string.char(c)] = c end
for i=1,24 do byName['F'..i] = 0x6F + i end

local aliases = {
    Backspace='BackSpace', Space='SpaceBar', Spacebar='SpaceBar',
    LeftMouse='LeftMouseButton', RightMouse='RightMouseButton', MiddleMouse='MiddleMouseButton',
    Mouse4='ThumbMouseButton', Mouse5='ThumbMouseButton2',
    UpArrow='Up', DownArrow='Down', LeftArrow='Left', RightArrow='Right',
    LeftCtrl='LeftControl', RightCtrl='RightControl',
    LeftWindows='LeftCommand', RightWindows='RightCommand',
    Return='Enter', Capital='CapsLock', Snapshot='PrintScreen', Apps='Menu',
    NumpadZero='NumPadZero', NumpadOne='NumPadOne', NumpadTwo='NumPadTwo',
    NumpadThree='NumPadThree', NumpadFour='NumPadFour', NumpadFive='NumPadFive',
    NumpadSix='NumPadSix', NumpadSeven='NumPadSeven', NumpadEight='NumPadEight', NumpadNine='NumPadNine',
    NumPad0='NumPadZero',NumPad1='NumPadOne',NumPad2='NumPadTwo',NumPad3='NumPadThree',NumPad4='NumPadFour',
    NumPad5='NumPadFive',NumPad6='NumPadSix',NumPad7='NumPadSeven',NumPad8='NumPadEight',NumPad9='NumPadNine',
    Asterix='Multiply',Quote='Apostrophe',BackQuote='Tilde',
}

local byValue = {}
for name,value in pairs(byName) do
    if not byValue[value] then byValue[value]=name end
end

function M.toValue(name)
    if type(name)~='string' then return nil end
    name=aliases[name] or name
    return byName[name]
end

function M.toName(value)
    return byValue[tonumber(value)]
end

return M
