
function NewController(addr)
dev={}
dev.addr=addr
dev.active=false


dev.parse_state_item=function(self, toks)
local tok

if config.debug == true then io.stderr:write("controller:parse_state_item: ".. toks:remaining().."\n") end

tok=toks:next()

if tok=="Discovering:"
then
	tok=toks:next()
	if tok == "yes" then self.scanning=true
	else self.scanning=false
	end
elseif tok=="Powered:"
then
	tok=toks:next()
	if tok == "yes" then self.powered=true
	else self.powered=false
	end
elseif tok=="Discoverable:"
then
	tok=toks:next()
	if tok == "yes" then self.discoverable=true
	else self.discoverable=false
	end
end

end

-- functions start here
dev.parse_state=function(self, line)
local toks, tok

toks=strutil.TOKENIZER( strutil.trim(line), "\\S")
if toks ~= nil 
then
--tok=toks:next()
self:parse_state_item(toks)
end

end


dev.parsechange=function(self, toks)
self:parse_state_item(toks)
ui:draw()
end


dev.get_state=function(self)
local str

bt:send("show " .. self.addr) 
str=bt:readln()
while strutil.strlen(str) > 0
do
	if config.debug == true then io.stderr:write("controller_state:" .. str .. "\n") end
	self:parse_state(str)
	str=bt:readln()
end

end
-- functions end here

return dev
end
