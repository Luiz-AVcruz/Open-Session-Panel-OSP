-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local key,clears='',0
local env=setmetatable({OSP={},InputLastPressedKey=function() return key end,InputClear=function() clears=clears+1 end},{__index=_G})
local inputChunk=assert(loadfile('mod/scripts/search_input.lua'));setfenv(inputChunk,env);inputChunk()
local chunk=assert(loadfile('mod/scripts/tools_search.lua'));setfenv(chunk,env);chunk()
local s=env.OSP.ToolSearch
s.query='camera';check(s.matches('CÂMERA avançada','other'),'accent and case folding')
s.query='CAMIÑA';check(s.matches('camiña','other'),'Spanish ñ and case folding')
s.query='camina'..string.char(204,131);check(s.matches('CAMIÑA','other'),'decomposed accent folding')
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
s.clear();s.focused=true;key='ñ';s.key();check(s.query=='ñ','UTF-8 Latin key is captured')
key='Š';s.key();check(s.query=='ñ','unmapped Latin character is ignored without changing the query')
key='backspace';s.key();check(s.query=='','Backspace removes one complete UTF-8 character')
key='f1';s.key();check(s.query=='','named keys are ignored by text capture')
key='ñ';for i=1,80 do s.key() end
check(#s.query==160,'the 80-character limit counts UTF-8 codepoints')
key='a';s.key();check(#s.query==160,'the UTF-8 query stops at 80 characters')
key='backspace';s.key();check(#s.query==158,'Backspace removes the final UTF-8 codepoint')
local other=env.OSP.SearchInput.new();s.query='tools';other.query='ammo';check(not s.matches('camera','other'),'search instances keep independent queries')
check(other.matches('Munição infinita','ammo'),'new search instance shares normalization behavior')
print('PASS tools search normalization and capture: '..n..' assertions')
