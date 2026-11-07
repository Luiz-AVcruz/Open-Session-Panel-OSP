-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local key,clears='',0
local env=setmetatable({OSP={},InputLastPressedKey=function() return key end,InputClear=function() clears=clears+1 end},{__index=_G})
local chunk=assert(loadfile('mod/scripts/tools_search.lua'));setfenv(chunk,env);chunk()
local s=env.OSP.ToolSearch
s.query='camera';check(s.matches('CÂMERA avançada','other'),'accent and case folding')
s.query='ID42';check(s.matches('Other','mod.id42'),'ID case folding')
s.query='%';check(not s.matches('Anything','a'),'literal pattern');check(s.matches('100%','b'))
s.query='';s.focused=true
for i=1,100 do key='a';s.key() end
check(#s.query==80,'bounded query')
key='lmb';local before=clears;s.key();check(clears==before,'mouse press is preserved')
key='esc';s.key();check(not s.focused and #s.query==80,'Escape keeps query')
key='x';s.key();check(#s.query==80,'blurred field ignores keys')
s.clear();check(s.query=='');s.focused=true;key='space';s.key();check(s.query==' ')
key='return';s.key();check(not s.focused)
print('PASS tools search normalization and capture: '..n..' assertions')
