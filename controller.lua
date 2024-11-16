
function NewController(addr)
dev={}
dev.addr=addr
dev.active=false
dev.powered=false


--this should parse things related to the bluetooth controller
--however, many some commands put the system into a state where it will
--wait for information related to the controller. During this time it can
--receive information about things other than the controller, so we have
--to call 'bt:parse' to handle that
dev.parse_state_item=function(self, toks)
local tok, remaining

remaining=toks:remaining()
if config.debug == true then io.stderr:write("controller:parse_state_item: ".. remaining.."\n") end

tok=toks:next()

if tok=="Discovering:"
then
	tok=toks:next()
	if tok == "yes" then self:scan_active(true)
	else self:scan_active(false)
	end
elseif tok=="Discoverable:"
then
	tok=toks:next()
	if tok == "yes" then self.discoverable=true
	else self.discoverable=false
	end
elseif tok=="Changing"
then
	tok=toks:remaining()
	if tok == "power on succeeded" then self.powered=true
	elseif tok == "power off succeeded" then self.powered=false
	end
elseif tok=="Powered:"
then
	tok=toks:next()
	if tok == "yes" then self.powered=true
	else self.powered=false
	end
else bt:parse(remaining)
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


dev.parse_change=function(self, toks)
self:parse_state_item(toks)
ui.redraw_needed=true
end


dev.toggle_scan=function(self)

	if self.scanning == true then bt:stopscan()
	else bt:startscan()
	end

end


dev.get_state=function(self)
local str

bt:send("show " .. self.addr) 
str=bt:readln()
if str=="[bluetooth]#" then str=bt:readln() end

while strutil.strlen(str) > 0
do
	if str=="[bluetooth]#" then break end
	if config.debug == true then io.stderr:write("controller_state:" .. str .. "\n") end
	self:parse_state(str)
	str=bt:readln()
end

end


dev.scan_active=function(self, value)
if value ~= nil
then
self.scanning=value
ui.redraw_needed=true
if config.debug == true then io.stderr:write("SCAN ACTIVE " .. tostring(value) .."\n") end
end

end

-- functions end here

return dev
end
