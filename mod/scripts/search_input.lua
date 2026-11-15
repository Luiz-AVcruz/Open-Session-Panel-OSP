-- Copyright (C) 2026 Luiz-AVcruz
-- AGPL-3.0-or-later; see LICENSE and ADDITIONAL-PERMISSION.
-- Small, independent text capture state for local searches.
OSP.SearchInput = {}

OSP.SearchInput.replacements={}
for _,group in ipairs({
    {"[ÁÀÂÃÄáàâãä]","a"},{"[ÉÈÊËéèêë]","e"},{"[ÍÌÎÏíìîï]","i"},
    {"[ÓÒÔÕÖóòôõö]","o"},{"[ÚÙÛÜúùûü]","u"},{"[Çç]","c"},{"Ññ","n"},
}) do
    for char in group[1]:gmatch('[\194-\244][\128-\191]+') do OSP.SearchInput.replacements[char]=group[2] end
end

function OSP.SearchInput.fold(value)
    value = tostring(value or "")
    -- Fold all known characters in one UTF-8 pass, rather than running a
    -- separate gsub over each accented letter for every search candidate.
    value=value:gsub('[\194-\244][\128-\191]+',function(char) return OSP.SearchInput.replacements[char] or char end)
    -- A decomposed Spanish/Portuguese accent is still the same letter.
    value=value:gsub("\204[\128-\191]",""):gsub("\205[\128-\175]","")
    return value:lower()
end

function OSP.SearchInput.codepoint(key)
    local first=key:byte(1)
    if not first then return nil end
    if first<0x80 then return #key==1 and first or nil end
    local length,minimum
    if first>=0xC2 and first<=0xDF then length,minimum=2,0x80
    elseif first>=0xE0 and first<=0xEF then length,minimum=3,0x800
    elseif first>=0xF0 and first<=0xF4 then length,minimum=4,0x10000
    else return nil end
    if #key~=length then return nil end
    local value=first%(2^(7-length))
    for i=2,length do
        local byte=key:byte(i)
        if byte<0x80 or byte>0xBF then return nil end
        value=value*64+(byte-0x80)
    end
    if value<minimum or value>0x10FFFF or value>=0xD800 and value<=0xDFFF then return nil end
    return value
end

function OSP.SearchInput.latinCharacter(key)
    local value=OSP.SearchInput.codepoint(key)
    if not value then return false end
    if value<0x80 then return key:match('^[ -~]$')~=nil end
    return OSP.SearchInput.replacements[key]~=nil
        or value>=0x0300 and value<=0x036F
end

function OSP.SearchInput.countCharacters(value)
    local count=0
    for i=1,#value do
        local byte=value:byte(i)
        if byte<0x80 or byte>=0xC0 then count=count+1 end
    end
    return count
end

function OSP.SearchInput.removeLastCharacter(value)
    local i=#value
    while i>1 do
        local byte=value:byte(i)
        if byte>=0x80 and byte<=0xBF then i=i-1 else break end
    end
    return value:sub(1,i-1)
end

function OSP.SearchInput.new()
    local S = {query="",focused=false}
    function S.blur() S.focused=false end
    function S.clear()
        local changed=S.query~=""
        S.query=""
        return changed
    end
    function S.matches(name,id,normalizedQuery)
        local q=normalizedQuery or OSP.SearchInput.fold(S.query)
        if q=="" then return true end
        return OSP.SearchInput.fold(name):find(q,1,true)~=nil or OSP.SearchInput.fold(id):find(q,1,true)~=nil
    end
    function S.key()
        if not S.focused then return false end
        local key=(InputLastPressedKey() or ""):lower()
        if key=="" or key=="lmb" or key=="rmb" or key=="mmb" then return false end
        local old=S.query
        if key=="esc" or key=="return" or key=="enter" then S.blur()
        elseif key=="backspace" then S.query=OSP.SearchInput.removeLastCharacter(S.query)
        elseif key=="delete" then S.query=""
        else
            if key=="space" then key=" " end
            if OSP.SearchInput.latinCharacter(key) and OSP.SearchInput.countCharacters(S.query)<80 then S.query=S.query..key end
        end
        InputClear()
        return old~=S.query
    end
    return S
end
