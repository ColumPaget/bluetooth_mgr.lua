require("stream")
require("strutil")
require("terminal")
require("time")
require("process")

config={}
config.version="1.7"
config.show_beacons=false

function make_sorted(input, cmp_func)
local output={}
local key, value

for key,value in pairs(input)
do
  table.insert(output, value)
end

table.sort(output, cmp_func)

return output
end
devices={}

function NewDevice(addr, name)
local dev={}

if devices[addr] ~= nil then return devices[addr] end

-- functions
dev.setname=function(self, name)
local str

if strutil.strlen(name) == 0 then return end
if name=="(random)" then return end
if name=="(public)" then return end

str=string.gsub(name, "-", ":")
if strutil.strlen(name) > 0 and str ~= dev.addr then dev.name=name end
end


dev.add_uuid=function(self, uuid)
local toks, tok

toks=strutil.TOKENIZER(uuid, "(")
tok=strutil.trim(toks:next())
self.uuids=self.uuids .. tok .. ","
end



dev.parse_manufacturer_key=function(self, toks)
local id

	id=toks:next()
	if id == "0x0000" then self.vendor="ericson"
	elseif id == "0x0001" then self.vendor="nokia"
	elseif id == "0x0002" then self.vendor="intel"
	elseif id == "0x0003" then self.vendor="ibm"
	elseif id == "0x0004" then self.vendor="toshiba"
	elseif id == "0x0005" then self.vendor="3com"
	elseif id == "0x0006" then self.vendor="microsoft"
	elseif id == "0x0007" then self.vendor="lucent"
	elseif id == "0x0008" then self.vendor="motorola"
	elseif id == "0x004c" then self.vendor="apple"
	elseif id == "0x0087" then self.vendor="garmin"
	elseif id == "0x00E0" then self.vendor="google"
	elseif id == "0x011b" then self.vendor="hp ent."
	elseif id == "0x013a" then self.vendor="tencent"
	elseif id == "0x0c8c" then self.vendor="tmobile"
	elseif id == "0x0d04" then self.vendor="bartec"
	elseif id == "0x0d07" then self.vendor="datalogic"
	elseif id == "0x0d08" then self.vendor="datalogic"
	elseif id == "0x0d5b" then self.vendor="axis"
	elseif id == "0x0d28" then self.vendor="fujitsu"
	elseif id == "0x0bee" then self.vendor="linksys"
	end
end


dev.parse_manufacturer=function(self, toks)
if toks:next() == "Key:"
then
 self:parse_manufacturer_key(toks)
end
end


dev.parse_rssi=function(self, toks)
local str

		str=toks:next()
		if string.sub(str, 1, 2) == "0x" then str=toks:next() end
		if string.sub(str, 1, 1) == "(" then str=string.sub(str, 2, 4) end
		self.rssi=str
end

dev.parse_info=function(self, tok, toks)

	if tok == "Name:" then self:setname(toks:remaining())
	elseif tok == "Paired:" and toks:next() =="yes" then self.paired=true
	elseif tok == "Trusted:" and toks:next() =="yes" then self.trusted=true
	elseif tok == "Connected:" and toks:next() =="yes" then self.connected=true; bt:onconnected(self)
	elseif tok == "Icon:" then self.icon=toks:next()
	elseif tok == "Name:" then self:setname(toks:remaining())
	elseif tok == "UUID:" then self:add_uuid(toks:remaining())
	--old format is "MaunfacturerData Key:"
	elseif tok == "ManufacturerData" then self:parse_manufacturer(toks)
	--new format is "MaunfacturerData.Key:"
	elseif tok == "ManufacturerData.Key:" then self:parse_manufacturer_key(toks)
	elseif tok == "RSSI:" then self:parse_rssi(toks)
	end
end

dev.parse_change=function(self, toks)
local tok

	tok=toks:next()
	self:parse_info(tok, toks)
	ui:loaddevs()
end



dev.finalize=function(self)
local toks, tok

--if strutil.strlen(self.name) == 0 then self.name=self.addr end
self.audio_output=false
self.audio_input=false

toks=strutil.TOKENIZER(self.uuids, ",")
tok=toks:next()
while tok ~= nil
do
if tok=="Audio Sink" then self.audio_output=true end
if tok=="Audio Source" then self.audio_input=true end
tok=toks:next()
end

if self.icon == "audio-card"
then
	if self.audio_output ~= true then self.icon = "audio-source"
	elseif self.audio_input ~= true then self.icon = "audio-output"
	end
end

end

--end functions

dev.addr=addr
dev:setname(name)
dev.uuids=""
devices[addr]=dev

return dev
end


function GetDevice(addr)
local dev

dev=devices[addr]
if dev == nil then dev=NewDevice(addr) end

return dev
end

function SettingsInit(cmd_line_args)
config.debug=false

for i,val in ipairs(cmd_line_args)
do
if val == "-debug" then config.debug=true end
end

end
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
function ControllersInit()
local controllers={}

controllers.items={}
controllers.needs_refresh=false

controllers.parse=function(self, line)
local dev={}
local toks, tok, str

controllers.needs_refresh=true
toks=strutil.TOKENIZER( strutil.trim(line), "\\S")
dev=NewController(toks:next())

	tok=toks:next()
	while tok
	do
		if tok=="[default]" then dev.active=true end
		tok=toks:next()
	end

	if self.items[dev.addr] == nil then self.items[dev.addr]=dev end

end



controllers.refresh=function(self)
local addr, dev

if self.needs_refresh == true
then
  for addr,dev in pairs(self.items)
  do
    dev:get_state()
  end
end

end



controllers.curr=function(self)
local count, addr, dev, current

count=0
for addr,dev in pairs(self.items)
do
dev:get_state()
if dev.active==true then current=dev end
count=count + 1
end

return current,count
end


controllers.find=function(self, addr)
local addr, dev

for addr,dev in pairs(self.items)
do
if dev.addr==addr then return dev end
end

return nil
end


controllers.count=function(self)
return #self.items
end

controllers.load=function(self)
bt:send("list")
bt:consume_input("", "")
self:refresh()
end



controllers.poweron=function(self)
bt:send("power on")
bt:consume_input("Changing power on succeeded", "controller:")
controllers:load()
bt:getdevs()
end

controllers.poweroff=function(self)
bt:send("power off")
bt:consume_input("Changing power off succeeded", "controller:")
end

controllers.toggle_scan=function(self)
local dev

dev=self:curr()
if dev ~= nil then dev:toggle_scan() end
self:refresh()
end

controllers.scan_active=function(self, value)
local dev

dev=self:curr()
if dev ~= nil then 
dev:scan_active(value)
end

end

return controllers
end
bluealsa={


use=function(self, bt_dev)
local S, str, name

name=string.gsub(bt_dev.name, " ", "_")
str=process.getenv("HOME") .. "/.asoundrc"
if config.debug == true then io.stderr:write("BLUEALSA SETUP -----------------------["..str.."]\n") end
S=stream.STREAM(str, "w")
if S ~= nil
then
str="pcm."..name.." {\n"
str=str.."type plug\n"
str=str.."slave.pcm { type bluealsa; service org.bluealsa; device \""..bt_dev.addr.."\"; profile a2dp}\n"
str=str.."}\n\n"
str=str.."ctl."..name.." {\ntype bluealsa\n}\n\n";
str=str.."pcm.!default {type plug; slave.pcm \""..name.."\"}\n"
S:writeln(str)
if config.debug == true then io.stderr:write(str) end
S:close()
if config.debug == true then io.stderr:write("BLUEALSA SETUP -----------------------\n") end
end

end

}

function MainScreen_Init(ui)
local screen={}

screen.ui=ui
screen.Term=ui.Term

screen.menu=terminal.TERMMENU(screen.Term, 1, 2, Term:width()-2, Term:height() -6)

screen.resize=function(self)
screen.menu:resize(Term:width() -2, Term:height() -6)
end

screen.add=function(self, title, dev)
self.menu:add(title, dev)
end



screen.formatdevicetype=function(self, dev)
local str=""

if strutil.strlen(dev.icon) > 0 
then 
	if dev.icon == "input-keyboard" then str="keyboard"
	elseif dev.icon == "audio-card" then str="audio"
	elseif dev.icon == "audio-headset" then str="audio"
	elseif dev.icon == "audio-output" then str="audio"
	elseif dev.icon == "audio-source" then str="audio"
	elseif dev.icon == "audio-sink" then str="audio"
	elseif dev.icon == "input-gaming" then str="gamectrl"
	else str=dev.icon
	end
end

str=strutil.padto(str, ' ', 10)
return str
end


screen.formatrssi=function(self, dev)
local str=""

if dev.rssi == nil 
then 
 str="     --    "
else 
 val=tonumber(dev.rssi)
 if val ~= nil
	then
-- convert dbm to percent
 val=2 * ( val + 100)
 str=string.format("signal:%3d%%", val)
	end
end

return str
end


screen.menu_add_dev=function(self, dev)
local str, name, vendor, term_wide

term_wide=ui.Term:width()
if config.show_beacons ~= true and strutil.strlen(dev.name) == 0 then return end

str=dev.addr

if term_wide > 60
then
str=str .. "  " .. self:formatdevicetype(dev)
end

if term_wide > 80 then str=str .. self:formatrssi(dev) end

if dev.connected == true then str=str.." * "
else str=str.. "   " end 


if term_wide > 80
then
if dev.paired == true then str=str.." paired "
else str=str.. "        " end 

if dev.trusted == true then str=str.." trusted "
else str=str.. "         " end 
end


if dev.vendor==nil then vendor=""
else vendor=dev.vendor end
str=str.. string.format("%10s", vendor)

if dev.name==nil 
then 
	if dev.vendor=="apple" then name="iBeacon" 
	else name="???????"
  end
else name=dev.name 
end

str=str.."  ~m" .. name .."~0"
self.menu:add(str, dev.addr)

end



screen.dev_cmp_name=function(d1, d2)
if d1.name == nil and d2.name == nil then return(false) end
if d1.name == nil then return(true) end
if d2.name == nil then return(false) end
return d1.name < d2.name
end


screen.update_menu=function(self)
local addr,dev,str,controller
local pos=0
local sorted

controller=controllers:curr()

pos=self.menu:curr()
self.menu:clear()
self.menu:add("Exit app", "exit")

if controller ~= nil
then
if controller.scanning == true then self.menu:add("Stop scanning", "stop-scan") 
else self.menu:add("Scan for devices", "scan") end


if controller.powered == true then self.menu:add("Power down controller", "poweroff")
else self.menu:add("Power on controller", "poweron")
end

self.menu:add("Change controller", "change controller")
end

bt.reload_devices=false

sorted=make_sorted(devices, self.dev_cmp_name)
for addr,dev in pairs(sorted)
do
	screen:menu_add_dev(dev)
end

if strutil.strlen(pos) > 0 then self.menu:setpos(pos) end

end


screen.onkey=function(self, key)
local str

str=self.menu:onkey(key)
self.menu:draw()

if strutil.strlen(str) > 0
then
	if str=="exit" then
	 --do nothing, 'exit' gets passed up to a higher function
	elseif str=="scan" then
	 bt:startscan()
	 self:update_menu()
	 self:update()
	elseif str=="stop-scan" then
	 bt:stopscan()
	 self:update_menu()
	 self:update()
	elseif str=="poweroff" then
	 controllers:poweroff()
	 self.ui:draw()
	elseif str=="poweron" then
	 controllers:poweron()
	 self.ui:draw()
	else -- switch to device screen
		self.ui.devscreen.device=devices[str]
		self.ui.state=self.ui.state_devscreen
		self.ui:draw()
  end
else
	self:update()
end


return(str)
end



screen.title=function(self)
local addr, dev, count, controller, str

controller,count=controllers:curr()

str="~B~wBluetooth_mgr-"..config.version.." controller:"
if controller == nil then str=str .. "~rNONE"
else 
  str=str .. controller.addr .. " " 
	if controller.powered == true then str=str.. " ~gON ~w"
	elseif controller.powered == false then  str=str.. " ~rOFF~w"
	end

	str=str ..  "  (" .. tostring(count).." in total)"
  if controller.scanning==true then str=str.." ~rscanning~w" end
end

str=str.. "~>~0"

self.Term:puts(str)
end

screen.infobox=function(self, menuchoice)
local name, dev, str

self.Term:move(0, self.Term:height() -3)

if menuchoice == "exit" then self.Term:puts("exit bluetooth_mgr ~>~0")
elseif menuchoice == "scan" then self.Term:puts("scan for devices in the local area ~>~0")
elseif menuchoice == "stop-scan" then self.Term:puts("stop scanning for devices ~>~0")
elseif menuchoice == "poweroff" then self.Term:puts("power down bluetooth controller ~>~0")
elseif menuchoice == "poweron" then self.Term:puts("power on bluetooth controller ~>~0")
else
  dev=GetDevice(menuchoice)
  
  if dev ~= nil 
  then
	if strutil.strlen(dev.name) ==0 then name=dev.addr
	else name=dev.name
	end

	str="[" .. name .. "] Supports: " .. string.sub(dev.uuids, 1, len) .. "~>~0"
	str=terminal.strtrunc(str, Term:width())
	self.Term:puts(str)
  end
end

end


screen.update=function(self)
local curr, dev

self.menu:draw()
curr=self.menu:curr()
if strutil.strlen(curr) > 0 then self:infobox(curr)  end

end

screen.draw=function(self)
self.Term:clear()
self.Term:move(0,0)
self:title()
self:update_menu()
self:update()
end


return(screen)
end


--[[

This module handles the menu for a selected device

]]--

function DeviceScreen_Init(ui)
local screen={}

screen.ui=ui
screen.Term=ui.Term
screen.menu=terminal.TERMMENU(screen.Term, 1, 4, Term:width()-2, Term:height() -6)

screen.add_option=function(self, option)
local toks, id

toks=strutil.TOKENIZER(option, " ")
id=toks:next()
self.menu:add(option, id)
end



screen.display_dev=function(self)
local status=""
local options="back,"

if self.device.paired==true
then
	status="paired"
	if self.device.connected ~= true then options=options .. "connect," end
else
	options=options .. "pair,connect (pair trust and connect),"
end

if self.device.trusted==true
then
	status="trusted"
	options=options .. "untrust,"
else
	options=options .. "trust,"
end

if self.device.connected==true
then 
self.Term:puts("~G~nDEVICE: " .. self.device.name .. " " .. self.device.addr .. " ~w~eCONNECTED~>~0\n")
options=options .. "reconnect (disconnect then reconnect),disconnect,"
else
self.Term:puts("~B~wDEVICE: " .. self.device.name .. " " .. self.device.addr .. " " .. status .. "~>~0\n")
end


if self.device.audio_output == true then options=options .. "bluealsa set device," end

--if self.device.paired==true then options=options.."remove" end
options=options .. "remove" 

self.Term:puts("\n" .. self.device.uuids)

return options
end


screen.draw=function(self)
local toks
local options

self.Term:clear()
self.Term:move(0,0)

if self.device ~= nil and self.device.name ~= nil
then
options=self:display_dev()
end


self.menu:clear()
toks=strutil.TOKENIZER(options, ",")
str=toks:next()
while str ~= nil
do
self:add_option(str)
str=toks:next()
end

self.menu:draw()
end


screen.done=function(self)
  self.ui.state=self.ui.state_mainscreen 
	self.ui:draw()
end


screen.onkey=function(self, key)
local str

if key=="ESC"
then 
	self:done()
  return
end


str=self.menu:onkey(key)

if config.debug == true and strutil.strlen(str) > 0 then io.stderr:write("DeviceScreen: [".. str .."]\n") end

if str=="back" then screen:done()
elseif str=="remove"
then 
bt:removedev(self.device)
screen:done()
elseif str=="pair" then bt:pairdev(self.device)
elseif str=="trust" then bt:trustdev(self.device)
elseif str=="untrust" then bt:untrustdev(self.device)
elseif str=="disconnect" 
then 
bt:disconnectdev(self.device)
self:draw()
elseif str=="connect" then 
	if self.device.connected ~= true
	then
		bt:pairdev(self.device)
		process.sleep(2)
		bt:trustdev(self.device)
	end
	bt:connectdev(self.device)
	self:draw()
elseif str=="reconnect" then 
	bt:disconnectdev(self.device)
	process.sleep(1)
	bt:connectdev(self.device)
elseif str=="bluealsa" then
	bluealsa:use(self.device)
	ui:statusbar("~w~MALSA config file '~/.asoundrc' written~>")
end

end

return(screen)
end



function HelpScreen_Init(ui)
local screen={}


screen.resize=function(self)
screen.menu:resize(Term:width() -2, Term:height() -2)
end

screen.add=function(self, title)
self.menu:add(title)
end





screen.onkey=function(self, key)
local str

str=self.menu:onkey(key)
self.menu:draw()

return(str)
end


screen.update=function(self)
self.menu:draw()
end



screen.draw=function(self)
self.Term:clear()
self.Term:move(0,0)
self:update()

end


screen.ui=ui
screen.Term=ui.Term
screen.menu=terminal.TERMMENU(screen.Term, 1, 2, Term:width()-2, Term:height() -2)
screen.menu:add("?                 -   this help");
screen.menu:add("up/w/i            -   menu cursor up");
screen.menu:add("down/s/k          -   menu cursor down");
screen.menu:add("escape/left/a/j   -   back");
screen.menu:add("enter/right/d/l   -   menu select");
screen.menu:add("b                 -   toggle show bluetooth beacons");
screen.menu:add("S                 -   toggle bluetooth scanning");
screen.menu:add("Q                 -   quit application");



return(screen)
end




function UI_Init(Term)
ui={}

ui.Term=Term
ui.state_mainscreen=0
ui.state_devscreen=1
ui.state_helpscreen=2
ui.state=ui.state_mainscreen
ui.redraw_needed=false

ui.mainscreen=MainScreen_Init(ui)
ui.devscreen=DeviceScreen_Init(ui)
ui.helpscreen=HelpScreen_Init(ui)


ui.switchscreen=function(self, name)
local state=ui.state_mainscreen

if name=="help" then state=ui.state_helpscreen
elseif name=="device" then state=ui.state_devscreen
elseif name=="main" then state=ui.state_mainscreen
end

if state == ui.state then ui.state = ui.state_mainscreen
else ui.state = state
end

ui:draw()
end



ui.statusbar=function(self, text)
local Term, len

Term=self.Term
Term:move(0, Term:height() -1)
text=terminal.strtrunc(text, Term:width())
Term:puts(text.."~>~0")
Term:flush()
end


ui.loaddevs=function(self)
self.mainscreen:update_menu()
--if self.state==self.state_mainscreen then self.mainscreen:update() end
self:draw()
end


ui.resize=function(self)
self.mainscreen:resize() 
self:draw()
end


ui.draw=function(self)

self.Term:cork()
self.Term:clear()
if self.state == self.state_devscreen then self.devscreen:draw()
elseif self.state == self.state_helpscreen then self.helpscreen:draw()
else self.mainscreen:draw()
end

self:statusbar("~B~wkeys: ?:help  w/i/up:menu up  s/k/down:menu down  d/l/right/enter:select  a/j/left/esc:back  Q/esc:Quit  S:scan")
self.Term:flush()

end


ui.onkey=function(self, key)

--translate ijkl to arrow keys
if key=="i" then key="UP"
elseif key=="k" then key="DOWN"
elseif key=="j" then key="ESC"
elseif key=="l" then key="ENTER"
--translate wasd to arrow keys
elseif key=="w" then key="UP"
elseif key=="s" then key="DOWN"
elseif key=="a" then key="ESC"
elseif key=="d" then key="ENTER"
--translate 'left' and 'right' arrows to menu in/out
elseif key=="LEFT" then key="ESC"
elseif key=="RIGHT" then key="ENTER"
elseif key=="\n" then key="ENTER"
end


if self.state==self.state_devscreen 
then 
return ui.devscreen:onkey(key)
elseif self.state==self.state_helpscreen 
then 
return ui.helpscreen:onkey(key)
else
return self.mainscreen:onkey(key)
end

ui:draw()

end

ui.start=function(self)
self:switchscreen("main")
end

ui.refresh=function(self)
if ui.redraw_needed==true
then
ui:draw()
ui.redraw_needed=false
end
end

return(ui)
end




-- must do this to ensure that we get standard english
-- messages back from all programs we talk to
process.setenv("LANG", "C")
process.setenv("LC_ALL", "C")


SettingsInit(arg)

Term=terminal.TERM(nil, "wheelmouse rawkeys save")
Term:clear()
Term:move(0,0)
ui=UI_Init(Term)

bt=BTInit()
controllers=ControllersInit()

poll=stream.POLL_IO()
poll:add(Term:get_stream())
poll:add(bt.S)

Term:puts("~R~wBluetooth_mgr 0.1   LOADING DEVICES~>~0\r")
controllers:poweron()


ui:start()
while true
do
	if bt.reload_devices==true then ui:loaddevs() end
  if process.sigcheck(process.SIGWINCH) == true then ui:resize() end
  process.sigwatch(process.SIGWINCH)


	S=poll:select(10)
	if S==bt.S
	then
		bt:handle_input()
 	elseif S==Term:get_stream() then
		key=Term:getc()
		if key=="S" then controllers:toggle_scan()
		elseif key=="b" 
		then 
			if config.show_beacons == true then config.show_beacons=false
			else config.show_beacons=true
			end
			ui:draw()
		elseif key=="Q" then break
		elseif key=="?" then ui:switchscreen("help")
		else
		str=ui:onkey(key) 
		if str == "exit" then break end
		end

  end

	ui:refresh()
end

bt:stopscan() 
Term:clear()
Term:reset()
