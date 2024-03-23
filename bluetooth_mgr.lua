require("stream")
require("strutil")
require("terminal")
require("time")
require("process")

config={}

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
if strutil.strlen(name) > 0 then dev.name=name end
end

dev.adduuid=function(self, uuid)
local toks, tok

toks=strutil.TOKENIZER(uuid, "(")
tok=strutil.trim(toks:next())
self.uuids=self.uuids .. tok .. ","
end



dev.parsechange=function(self, toks)
local tok

	tok=toks:next()
	if tok == "Name:" 
	then 
	self.name=toks:remaining() 
	ui:loaddevs()
  elseif tok == "RSSI:"
	then 
	self.rssi=toks:next()
	ui:loaddevs()
	elseif tok == "Connected:" and toks:next() == "yes"
	then
	  bt:onconnected(self)
	end

end



dev.finalize=function(self)
local has_audio_sink=false 
local has_audio_source=false
local toks, tok

if strutil.strlen(self.name) == 0 then self.name=self.addr end

toks=strutil.TOKENIZER(self.uuids, ",")
tok=toks:next()
while tok ~= nil
do
if tok=="Audio Sink" then has_audio_sink=true end
if tok=="Audio Source" then has_audio_source=true end
tok=toks:next()
end

if self.icon == "audio-card"
then
	if has_audio_sink ~= true then self.icon = "audio-source"
	elseif has_audio_source ~= true then self.icon = "audio-output"
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
		if dev ~= nil
		then
			bt:getdevinfo(dev)
			elseif tok=="Controller" then dev:parse_state(toks)
		end
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
function ControllersInit()
local controllers={}

controllers.items={}


controllers.parse=function(self, line)
local dev={}
local toks, tok, str

toks=strutil.TOKENIZER( strutil.trim(line), "\\S")
str=toks:next()
if str == "Controller"
then
	dev=NewController(toks:next())

	tok=toks:next()
	while tok
	do
		if tok=="[default]" then dev.active=true end
		tok=toks:next()
	end

	if self.items[dev.addr] == nil then self.items[dev.addr]=dev end

	if dev.active == true then dev:get_state() end
end

end





controllers.curr=function(self)
local count, addr, dev, current

count=0
for addr,dev in pairs(self.items)
do
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


controllers.load=function(self)
local str

bt:send("list")

str=bt:readln()
while strutil.strlen(str) > 0
do
	if config.debug == true then io.stderr:write("controller:" .. str .. "\n") end
	self:parse(str)
	str=bt:readln()
end


end


controllers.poweron=function(self)
bt:send("power on")
end

bt.poweroff=function(self)
bt:send("power off")
end


return controllers
end
bluealsa={


use=function(self, bt_dev)
local S, str

str=process.getenv("HOME") .. "/.asoundrc"
if config.debug == true then io.stderr:write("BLUEALSA SETUP -----------------------["..str.."]\n") end
S=stream.STREAM(str, "w")
if S ~= nil
then
str="pcm."..bt_dev.name.." {\n"
str=str.."type plug\n"
str=str.."slave.pcm { type bluealsa; service org.bluealsa; device \""..bt_dev.addr.."\"; profile a2dp}\n"
str=str.."}\n\n"
str=str.."ctl."..bt_dev.name.." {\ntype bluealsa\n}\n\n";
str=str.."pcm.!default={type=plug; slave.pcm \""..bt_dev.name.."\"}\n"
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

screen.add=function(self, title, dev)
self.menu:add(title, dev)
end



screen.formatdevicetype=function(self, dev)
local str=""

if strutil.strlen(dev.icon) > 0 
then 
	if dev.icon == "input-keyboard" then str="keyboard"
	elseif dev.icon == "audio-card" then str="audio"
	elseif dev.icon == "input-gaming" then str="gamectrl"
	else str=dev.icon
	end
end

str=strutil.padto(str, ' ', 15)
return str
end


screen.formatrssi=function(self, dev)
local str=""

if dev.rssi == nil then str="signal:????"
else 
-- convert dbm to percent
val=tonumber(dev.rssi) + 100
if val > 0 then val=0 end
str=string.format("signal:%3d%%", val / 50 * 100)
end

return str
end


screen.menu_add_dev=function(self, dev)
local str

str=dev.addr
str=str .. "  " .. self:formatdevicetype(dev)

str=str .. self:formatrssi(dev)

if dev.connected == true then str=str.." * "
else str=str.. "   " end 

if dev.paired == true then str=str.." paired "
else str=str.. "        " end 

if dev.trusted == true then str=str.." trusted "
else str=str.. "         " end 

str=str.. "  ~m" ..dev.name .. "~0  "

self.menu:add(str, dev.addr)

end



screen.dev_cmp_name=function(d1, d2)
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
	 bt:poweroff()
	 self.ui:draw()
	elseif str=="poweroff" then
	 bt:poweron()
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
local addr, dev, count, controller, str, len

controller,count=controllers:curr()

str="~B~wBluetooth_mgr 0.1 controller:"
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

self.Term:move(0, self.Term:height() -4)

if menuchoice == "exit" then self.Term:puts("exit bluetooth_mgr ~>~0")
elseif menuchoice == "scan" then self.Term:puts("scan for devices in the local area ~>~0")
elseif menuchoice == "stop-scan" then self.Term:puts("stop scanning for devices ~>~0")
elseif menuchoice == "poweroff" then self.Term:puts("power down bluetooth controller ~>~0")
else
  dev=GetDevice(menuchoice)
  
  if dev ~= nil and dev.name ~= nil
  then
	str="[" .. dev.name .. "] Supports: " .. string.sub(dev.uuids, 1, len) .. "~>~0"
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


if self.device.icon == "audio-output" then options=options .. "bluealsa set device," end

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





function UI_Init(Term)
ui={}

ui.Term=Term
ui.state_mainscreen=0
ui.state_devscreen=1
ui.state=ui.state_mainscreen
ui.mainscreen=MainScreen_Init(ui)
ui.devscreen=DeviceScreen_Init(ui)

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
ui:draw()
end



ui.draw=function(self)
if self.state == self.state_devscreen then self.devscreen:draw()
else self.mainscreen:draw()
end
self:statusbar("~B~wkeys: w/i/up: menu up s/k/down: menu down d/l/right/enter: select a/j/left/esc: back Q/esc: Quit mainscreen S:start scan")
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
else
return self.mainscreen:onkey(key)
end
end


return(ui)
end




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
controllers:load()
bt:getdevs()


while true
do
	if bt.reload_devices==true then ui:loaddevs() end

	S=poll:select(10)
	if S==bt.S
	then
		bt:handle_input()
	elseif S==Term:get_stream() then
		key=Term:getc()
		if key=="S" then bt:startscan()
		elseif key=="Q" then break
		else
		str=ui:onkey(key) 
		if str == "exit" then break end
		end
  end
end

bt:stopscan() 
Term:clear()
Term:reset()
