


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


