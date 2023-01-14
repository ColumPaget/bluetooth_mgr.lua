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
