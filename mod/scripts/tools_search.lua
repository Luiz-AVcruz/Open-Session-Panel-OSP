-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
OSP.ToolSearch={query="",focused=false}
local S=OSP.ToolSearch
function S.blur() S.focused=false end
function S.clear() local changed=S.query~="";S.query="";return changed end
local function fold(s)
    for _,group in ipairs({{"[ÁÀÂÃÄáàâãä]","a"},{"[ÉÈÊËéèêë]","e"},{"[ÍÌÎÏíìîï]","i"},{"[ÓÒÔÕÖóòôõö]","o"},{"[ÚÙÛÜúùûü]","u"},{"[Çç]","c"}}) do
        -- Lua patterns operate on bytes; replace each UTF-8 symbol literally.
        for char in group[1]:gmatch('[\194-\244][\128-\191]+') do s=s:gsub(char,group[2]) end
    end
    return s:lower()
end
function S.matches(name,id)
    local q=fold(S.query)
    return fold(name):find(q,1,true)~=nil or fold(id):find(q,1,true)~=nil
end
function S.key()
    if not S.focused then return false end
    local key=(InputLastPressedKey() or ""):lower()
    if key=="" or key=="lmb" or key=="rmb" or key=="mmb" then return false end
    local old=S.query
    if key=="esc" or key=="return" or key=="enter" then S.blur()
    elseif key=="backspace" then S.query=S.query:sub(1,-2)
    elseif key=="delete" then S.query=""
    else
        if key=="space" then key=" " end
        if #key==1 and key:match('^[ -~]$') and #S.query<80 then S.query=S.query..key end
    end
    InputClear();return old~=S.query
end
