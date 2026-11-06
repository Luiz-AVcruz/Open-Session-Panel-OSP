-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Engine input is mocked to test only the shared numeric-capture contract.
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function eq(actual,expected,message) check(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
local input={key="",cleared=0}
local env=setmetatable({InputLastPressedKey=function() return input.key end,
    InputClear=function() input.cleared=input.cleared+1;input.key="" end},{__index=_G})
local chunk=assert(loadfile("mod/scripts/number_input.lua"));setfenv(chunk,env);chunk()
local N=env.OSP.NumberInput
local result,calls=nil,0
local function capture(id,value,minimum,maximum,decimals)
    N.begin(id,value,minimum,maximum,decimals,function(v) result=v;calls=calls+1 end)
end
local function press(key)
    input.key=key
    local handled=N.key()
    input.key=""
    return handled
end

eq(N.active(),false,'inactive on load')
capture('rgb',123,0,255,0)
eq(N.active(),true)
eq(N.active('rgb'),true)
eq(N.active('other'),false)
eq(N.caption('rgb',123),'123_','shows value and cursor')
press('4');press('2');eq(N.caption('rgb',123),'42_','first digit replaces current value')
press('return');eq(result,42,'integer entered');eq(calls,1,'one callback')
eq(N.active(),false);press('return');eq(calls,1,'inactive field cannot commit twice')

capture('rgb',4,0,255,0)
for i=1,100 do press('9') end
press('enter');eq(result,255,'enormous positive number clamps to RGB maximum');eq(result==math.huge,false,'no infinite value persisted')
capture('rgb',100,0,255,0)
press('minus');press('9');press('enter');eq(result,0,'negative RGB clamps to minimum')

capture('speed',1.25,.5,3,2)
press(',');eq(N.caption('speed',1.25),'0._','decimal first starts a fresh number with decimal places')
press('5');press('enter');eq(result,.5,'decimal comma accepted with configured precision')
capture('speed',1.25,.5,3,2)
press('period');eq(N.caption('speed',1.25),'0._','decimal first replaces a value with places')
press('5');press('enter');eq(result,.5,'period accepted as decimal separator')
capture('speed',1,0,10,2)
press('period');eq(N.caption('speed',1),'0._','decimal first also works without prior decimal places')
press('2');press('period');eq(N.caption('speed',1),'0.2_','second decimal separator is ignored')
press('3');press('6');press('enter');eq(result,.24,'entered decimals round to configured precision')

capture('speed',1.25,.5,3,2)
press('1');press('2');press('3');press('backspace');eq(N.caption('speed',1.25),'12_','backspace removes final digit')
press('delete');eq(N.caption('speed',1.25),'_','delete clears the text')
press('8');press('enter');eq(result,3,'decimal input clamps to speed maximum')
capture('speed',2,.5,3,2)
press('-');press('9');press('enter');eq(result,.5,'negative speed clamps to minimum')

local prior=calls
capture('invalid',10,0,255,0)
press('-');press('enter');eq(calls,prior,'incomplete sign never commits');eq(N.active('invalid'),true,'invalid value can still be corrected')
press('delete');press('enter');eq(calls,prior,'empty text never commits')
eq(N.cancel(),true,'cancel clears capture');eq(calls,prior,'cancel discards without callback');eq(N.active(),false)
eq(N.cancel(),false,'cancelling twice is harmless')

capture('rgb',128,0,255,0)
local cleared=input.cleared
eq(press('lmb'),true,'active field owns the frame')
eq(input.cleared,cleared,'mouse input is never cleared')
press('7');eq(input.cleared,cleared+1,'keyboard input is consumed')
N.cancel()

capture('old',1,0,255,0)
capture('new',20,0,255,0)
eq(N.active('old'),false,'new field replaces old capture')
press('delete');press('9');press('enter')
eq(result,9,'callback belongs to the active field')

print('PASS numeric input contract: '..checks..' assertions')
