package.path='Scripts/?.lua;'..package.path
local Codes=require('key_codes')
local expected={
    LeftMouseButton=0x01,CapsLock=0x14,PrintScreen=0x2C,Menu=0x5D,
    NumPadZero=0x60,NumPadNine=0x69,Multiply=0x6A,Divide=0x6F,
    F13=0x7C,F24=0x87,NumLock=0x90,ScrollLock=0x91,
    BrowserBack=0xA6,VolumeUp=0xAF,MediaPlayPause=0xB3,
    Semicolon=0xBA,Equals=0xBB,Slash=0xBF,Tilde=0xC0,
    LeftBracket=0xDB,Backslash=0xDC,RightBracket=0xDD,Apostrophe=0xDE,
}
for name,value in pairs(expected) do
    assert(Codes.toValue(name)==value,name..' was not accepted')
    assert(Codes.toName(value)==name,value..' did not retain its canonical key name')
end
assert(Codes.toValue('NumPad7')==0x67 and Codes.toValue('Quote')==0xDE)
assert(Codes.toValue('Escape')==nil,'Escape must remain reserved for cancellation')
assert(Codes.toValue('Gamepad_FaceButton_Bottom')==nil,'gamepad keys must remain unsupported')
print('PASS expanded keyboard, keypad, punctuation, media and mouse key coverage')
