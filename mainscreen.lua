
function MainScreen_Init(ui)
local screen={}

screen.ui=ui
screen.Term=ui.Term

screen.menu=terminal.TERMMENU(screen.Term, 1, 2, Term:width()-2, Term:height() -6)

screen.resize=function(self)
screen.menu:resize(Term:width() -2, Term:height() -2)
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

self.Term:move(0, self.Term:height() -4)

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

