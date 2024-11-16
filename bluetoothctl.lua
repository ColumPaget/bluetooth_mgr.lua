function BTInit()
local bt={}

bt.reload_devices=true
bt.S=stream.STREAM("cmd:bluetoothctl","rw timeout=5")
bt.S:timeout(10)


-- this just cleans any weird control characters out of a string read
-- from bluetoothctl
bt.clean=function(self, str)
local i, c
local new=""


for i = 1, #str do
    c = string.sub(str, i, i)
		if string.byte(c) > 31 and string.byte(c) < 127 then new=new..c end
end

return new
end


-- write commands to bluetoothctl
bt.send=function(self, line)
if self.S ~= nil
then
self.S:writeln(line.."\n")
if config.debug == true then io.stderr:write("SEND: " .. line .. "\n") end
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
	elseif tok=="[bluetooth]#" then break
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
if addr == "Information" then return end

if devices[addr] ~= nil then return end

if config.debug == true then io.stderr:write("parsedev: " .. addr.." "..toks:remaining() .. "\n") end

dev=NewDevice(addr, toks:remaining())
self.reload_devices=true 

return dev
end


bt.onconnected=function(self, dev)
		dev.connected=true
		dev.paired=true
		ui.redraw_needed=true
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


bt.parse_delete=function(self, toks)
local tok, addr

tok=toks:next()
if tok == "Device"
then
	addr=toks:next()

if config.debug == true then io.stderr:write("DELETE ITEM: " .. addr .. "\n") end
	devices[addr]=nil
	ui:loaddevs()
end

end


bt.parse_attempt=function(self, toks)
local tok

  tok=toks:next()
  tok=toks:next()
	if tok == "connect" then ui:statusbar("~Y~n Attempting to connect: ".. toks:remaining()) 
	elseif tok == "pair" then ui:statusbar("~Y~n Attempting to pair: ".. toks:remaining()) 
	end
end


bt.parse_failure=function(self, toks)
local tok

  tok=toks:next()
  tok=toks:next()

	if tok == "connect:" then ui:statusbar("~R~w Failed to connect: ".. toks:remaining()) 
	elseif tok == "pair:" then ui:statusbar("~R~w Failed to pair: ".. toks:remaining()) 
	elseif tok == "start" 
	then 
    tok=toks:next()
  	if tok=="discovery:" 
   	then
       tok=toks:next()
			 if tok == "org.bluez.Error.InProgress" then controllers:scan_active(true) end
	  end
	end
end





-- a number of statements can have the form ???? Device <dev info>
-- where '????' is some token, and '<dev info>' is the bluetooth address
-- and name of a device. Parse all such instances to support dvice discovery
bt.parse_check_for_device=function(self, toks)
local tok, dev

		tok=toks:next()
		if tok=="Device"
		then 
		dev=self:parsedev(toks) 
		if dev ~= nil then self:getdevinfo(dev) end
		end
end


bt.parse_uuid=function(self, toks)
if config.debug == true then io.stderr:write("parse_uuid: " .. str.."\n") end
end


bt.parse=function(self, str)
local toks, tok, dev

if config.debug == true then io.stderr:write("parse: " .. str.."\n") end
toks=strutil.TOKENIZER(str, " ")
tok=toks:next()


if config.debug == true and tok ~= nil then io.stderr:write("tok1: " .. tok.."\n") end

if tok ~= nil
then
	if tok=="Device" then self:parsedev(toks) 
	elseif tok=="UUID" then self:parse_uuid(toks) 
	elseif tok=="Controller" then controllers:parse(toks:remaining())
	elseif tok=="Attempting" then self:parse_attempt(toks)
	elseif tok=="Failed" then self:parse_failure(toks)
	elseif tok=="Discovery" and toks:next() == "started" then controllers:scan_active(true)
	elseif tok=="Discovery" and toks:next() == "stopped" then controllers:scan_active(false)
	elseif tok=="Discovering" and toks:next() == "yes" then controllers:scan_active(true)
	elseif tok=="Discovering" and toks:next() == "no" then controllers:scan_active(false)
	elseif tok=="[NEW]" then self:parse_check_for_device(toks)
	elseif tok=="[CHG]" then self:parse_change(toks)
	elseif tok=="[DEL]" then self:parse_delete(toks)
	elseif tok=="[agent]" then ui:statusbar("~Y~n" .. toks:remaining())
	elseif tok=="Pairing" then ui:statusbar("~G~n" .. toks:remaining())
	elseif tok=="Changing"
  then
		dev=controllers:curr()
    if dev ~= nil then dev:parse_change(toks) end
	else
		self:parse_check_for_device(toks)
	end
--tok=toks:next()
end

end


bt.readln=function(self)
local str=""
local ch
local good_read=false

ch=self.S:readch()
while ch ~= nil and string.byte(ch) ~= 254
do
good_read=true
if ch == '\n' or ch == '\r' then break end
str=str..ch	
ch=self.S:readch()
end

str=terminal.stripctrl(str)
str=self:clean(str)

if config.debug == true then io.stderr:write("read: " .. str .. "\n") end

return strutil.trim(str), good_read
end


bt.handle_input=function(self)
local str, good_read

str,good_read=bt:readln()
bt:parse(str)

return str,good_read
end



-- consume input until we hit an 'endstr' or we timeout
bt.consume_input=function(self, endstr, debug_prefix)
local str, good_read

str,good_read=bt:handle_input()
while good_read == true
do
	if config.debug == true then io.stderr:write(debug_prefix .. str .. "\n") end
	
	if strutil.strlen(endstr) > 0 and str == endstr then break end
str,good_read=bt:handle_input()
end


end



bt.getdevs=function(self)
local str, CurrDev
local toks, tok, addr, dev

self:send("devices")
str=self:readln()
while strutil.strlen(str) > 0
do
	if str=="[bluetooth]#" then break end
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






