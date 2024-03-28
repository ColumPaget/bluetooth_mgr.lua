function BTInit()
local bt={}

bt.reload_devices=true
bt.S=stream.STREAM("cmd:bluetoothctl","rw timeout=5")
bt.S:timeout(10)

bt.send=function(self, line)
if self.S ~= nil
then
self.S:writeln(line.."\n")
if config.debug == true then io.stderr:write(line.."\n") end
end
end


bt.connectdev=function(self, dev)
self:send("connect "..dev.addr)
end

bt.disconnectdev=function(self, dev)
dev.connected=false
self:send("disconnect "..dev.addr)
end

bt.pairdev=function(self, dev)
self:send("pair "..dev.addr)
end


bt.trustdev=function(self, dev)
self:send("trust "..dev.addr)
end

bt.untrustdev=function(self, dev)
dev.trusted=false
self:send("untrust "..dev.addr)
end

bt.removedev=function(self, dev)
self:send("remove "..dev.addr)
end


bt.startscan=function(self)
self:send("scan on")
end

bt.stopscan=function(self)
self:send("scan off")
end



bt.parse_device_info=function(self)
local str, dev, toks, tok, name

str=self:readln()
while strutil.strlen(str) > 0
do

if config.debug == true then io.stderr:write("parsedevinfo: " .. str .. "\n") end

	str=strutil.trim(str)
	toks=strutil.TOKENIZER(str, " ")
	tok=toks:next()
	if tok=="Device"
	then 
		if dev ~= nil then dev:finalize() end
		dev=GetDevice(toks:next())
		dev:setname(toks:remaining())
	elseif dev ~= nil then dev:parse_info(tok, toks) 
	end
	str=self:readln()
end

if dev ~= nil then dev:finalize() end
end

bt.getdevinfo=function(self, dev)

self:send("info "..dev.addr)
self:parse_device_info()

end


bt.parsedev=function(self, toks)
local dev, addr, name

if toks:remaining() == "has been removed" then return end

addr=toks:next()
if devices[addr] ~= nil then return end

if config.debug == true then io.stderr:write("parsedev: " .. addr.." "..toks:remaining() .. "\n") end

dev=NewDevice(addr, toks:remaining())
self.reload_devices=true 

return dev
end

bt.onconnected=function(self, dev)
		dev.connected=true
		dev.paired=true
		ui:draw()
		ui:statusbar("~G~wConnected to: " .. dev.addr .. " " .. dev.name)
end



bt.parse_change=function(self, toks)
local dev, tok

tok=toks:next()
if tok == "Device"
then 
	dev=GetDevice(toks:next())
	if dev ~= nil then dev:parse_change(toks) end
elseif tok == "Controller" then 
	dev=controllers:find(toks:next())
	if dev ~= nil then dev:parse_change(toks) end
end

end


bt.parsedelete=function(self, toks)
local tok, addr

tok=toks:next()
if tok == "Device"
then
	addr=toks:next()
	devices[addr]=nil
	ui:loaddevs()
end

end





bt.parsefailure=function(self, toks)
local tok

  tok=toks:next()
  tok=toks:next()
	if tok == "connect:" then ui:statusbar("~R~w Failed to connect: ".. toks:remaining()) 
	end
end




bt.parse=function(self, str)
local toks, tok, dev

if config.debug == true then io.stderr:write("parse: " .. str.."\n") end
toks=strutil.TOKENIZER(str, " ")
tok=toks:next()
while tok ~= nil
do
	if tok=="Device" then self:parsedev(toks) 
	elseif tok=="Controller" then controllers:parse(toks:remaining())
	elseif tok=="Failed" then self:parsefailure(toks)
	elseif tok=="Discovery" and toks:next() == "started" then ui:statusbar("~B~ySCANNING FOR DEVICES")
	elseif tok=="[CHG]" then self:parse_change(toks)
	elseif tok=="[DEL]" then self:parsedelete(toks)
	elseif tok=="[agent]" then ui:statusbar("~Y~n" .. toks:remaining())
	elseif tok=="Changing"
  then
		dev=controllers:curr()
    if dev ~= nil then dev:parse_change(toks) end
	else
		tok=toks:next()
		if tok=="Device"
		then 
		dev=self:parsedev(toks) 
		if dev ~= nil then bt:getdevinfo(dev) end
		end
	end
tok=toks:next()
end

end


bt.readln=function(self)
local str=""
local ch

ch=self.S:readch()
while ch ~= '\n' and ch ~= '\r' and ch ~= nil and string.byte(ch) ~= 254
do
str=str..ch	
ch=self.S:readch()
end

str=terminal.stripctrl(str)
return strutil.trim(str)
end


bt.handle_input=function(self)
local str 

str=bt:readln()
bt:parse(str)

return str
end



-- consume input until we hit an 'endstr' or we timeout
bt.consume_input=function(self, endstr, debug_prefix)
local str

str=bt:handle_input()
while strutil.strlen(str) > 0
do
	if config.debug == true then io.stderr:write(debug_prefix .. str .. "\n") end
	if strutil.strlen(endstr) > 0 and str == endstr then break end
	str=bt:handle_input()
end


end



bt.getdevs=function(self)
local str, CurrDev
local toks, tok, addr, dev

self:send("devices")
str=self:readln()
while strutil.strlen(str) > 0
do
	if config.debug == true then io.stderr:write("dev:" .. str .. "\n") end
	self:parse(str)
	str=self:readln()
end


for addr,dev in pairs(devices)
do
self:send("info "..addr)
end
self:parse_device_info()
end


return(bt)
end









