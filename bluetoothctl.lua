function BTInit()
local bt={}

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
local str, CurrDev, toks, tok, name

str=self:readln()
while strutil.strlen(str) > 0
do

if config.debug == true then io.stderr:write("parsedevinfo: " .. str .. "\n") end

	str=strutil.trim(str)
	toks=strutil.TOKENIZER(str, " ")
	tok=toks:next()
	if tok=="Device"
	then 
		if CurrDev ~= nil then CurrDev:finalize() end
		CurrDev=GetDevice(toks:next())
		CurrDev:setname(toks:remaining())
	elseif CurrDev ~= nil
	then
		 if tok=="Paired:" and toks:next() =="yes" then CurrDev.paired=true
		 elseif tok=="Trusted:" and toks:next() =="yes" then CurrDev.trusted=true
		 elseif tok=="Connected:" and toks:next() =="yes" then CurrDev.connected=true
		 elseif tok=="Icon:" then CurrDev.icon=toks:next()
		 elseif tok=="RSSI:" then CurrDev.rssi=toks:next()
		 elseif tok=="Name:" then CurrDev:setname(toks:remaining())
		 elseif tok=="UUID:" then CurrDev:adduuid(toks:remaining())
		 end
	end
	str=self:readln()
end

if CurrDev ~= nil then CurrDev:finalize() end
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



bt.parsedevchange=function(self, toks)
local tok, addr, dev

	addr=toks:next()
	tok=toks:next()
	dev=devices[addr]
	if dev ~= nil
	then
	if tok == "Name:" 
	then 
	dev.name=toks:remaining() 
	ui:loaddevs()
  elseif tok == "RSSI:"
	then 
	dev.rssi=toks:next()
	ui:loaddevs()
	elseif tok == "Connected:" and toks:next() == "yes"
	then
	  self:onconnected(dev)
	end
	end

end

bt.parsechange=function(self, toks)
local dev

tok=toks:next()
if tok == "Device"
then 
	dev=GetDevice(toks:next())
	if dev ~= nil then dev:parsechange(toks) end
elseif tok == "Controller" then 
	dev=controllers:find(toks:next())
	if dev ~= nil then dev:parsechange(toks) end
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



bt.parsepowerchange=function(toks)

end


bt.parse=function(self, str)
local toks, tok, dev

if config.debug == true then io.stderr:write("parse: " .. str.."\n") end
toks=strutil.TOKENIZER(str, " ")
tok=toks:next()
while tok ~= nil
do
	if tok=="Device" then self:parsedev(toks) 
	elseif tok=="Controller" then controllers:parse(toks)
	elseif tok=="Failed" then self:parsefailure(toks)
	elseif tok=="Discovery" and toks:next() == "started" then ui:statusbar("~B~ySCANNING FOR DEVICES")
	elseif tok=="[CHG]" then self:parsechange(toks)
	elseif tok=="[DEL]" then self:parsedelete(toks)
	elseif tok=="[agent]" then ui:statusbar("~Y~n" .. toks:remaining())
	elseif tok=="Changing" then self:parsepowerchange(toks)
	else
		tok=toks:next()
		if tok=="Device"
		then 
		dev=self:parsedev(toks) 
		bt:getdevinfo(dev)
		elseif tok=="Controller" then controllers:parse_state(toks)
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
strutil.trim(str)
bt:parse(str)
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









