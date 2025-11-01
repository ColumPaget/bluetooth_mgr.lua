
--[[

This module handles the menu for a selected device

]]--

function DeviceScreen_Init(ui)
local screen={}

screen.ui=ui
screen.curr="back"
screen.Term=ui.Term
screen.menu=terminal.TERMMENU(screen.Term, 1, 6, Term:width()-2, Term:height() -10)


screen.add_option=function(self, option)
local toks, id

toks=strutil.TOKENIZER(option, " ")
id=toks:next()
self.menu:add(option, id)
if strutil.strlen(self.curr)==0 then self.curr=id end
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
self.Term:puts("~G~nDEVICE: " .. self.device.addr .. " (" .. self.device.name .. ") ~w~eCONNECTED~>~0\n")
options=options .. "reconnect (disconnect then reconnect),disconnect,"
else
self.Term:puts("~B~wDEVICE: " .. self.device.addr .. " (" .. self.device.name .. ") " .. status .. "~>~0\n")
end


if self.device.audio_output == true then options=options .. "bluealsa set device," end

options=options .. "rename device,"


--if self.device.paired==true then options=options.."remove" end
options=options .. "remove" 

self.Term:puts("\n~eServices:~0 " .. self.device:get_uuids() .. "\n")
self.Term:puts("~eDisplay Name:~0 " .. device_names:get(self.device.addr) .. "\n")

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


self.curr=self.menu:curr()

self.menu:clear()
toks=strutil.TOKENIZER(options, ",")
str=toks:next()
while str ~= nil
do
self:add_option(str)
str=toks:next()
end

if strutil.strlen(self.curr) > 0 then self.menu:setpos(self.curr) end

self.menu:draw()
end


screen.done=function(self)
  self.curr="back"
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

if strutil.strlen(str) > 0
then
   if config.debug == true then io.stderr:write("DeviceScreen: [".. str .."]\n") end
   
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
   elseif str=="rename" then
     device_name_screen:run(self.device)
   	self.ui:draw()
   end

   self.curr="back"
end
end

return(screen)

end


