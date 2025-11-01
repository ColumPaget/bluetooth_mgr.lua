
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

