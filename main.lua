

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
		elseif key=="ESC" then break
		else
		str=ui:onkey(key) 
		if str == "exit" then break end
		end
  end
end

bt:stopscan() 
Term:clear()
Term:reset()
