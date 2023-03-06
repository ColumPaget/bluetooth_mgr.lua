
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



screen.update_menu=function(self)
local addr,dev,str,controller
local pos=0

controller=controllers:curr()

pos=self.menu:curr()
self.menu:clear()
self.menu:add("Exit app", "exit")

if controller.scanning == true then self.menu:add("Stop scanning", "stop-scan") 
else self.menu:add("Scan for devices", "scan") end
self.menu:add("Power down controller", "poweroff")

bt.reload_devices=false

for addr,dev in pairs(devices)
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
if controller == nil then str=str .. "none"
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

