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
