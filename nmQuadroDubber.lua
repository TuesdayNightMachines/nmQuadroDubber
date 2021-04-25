-- nmQuadroDubber
-- 1.1.2 @NightMachines
-- llllllll.co/t/nmquadrodubber/
--
-- Overdub external audio
-- onto four tape loops
--
-- K1: hold for /alt menu
-- E1: current tape speed/
--     all tape speeds
-- K2: record to tape/
--     random modes
-- K3: record silence/
--     clear tape loop
-- E2: overdub level/
--     fade time
-- E3: select tape loop/s
--     monitor mix


  -- norns.script.load("code/nmQuadroDubber/nmQuadroDubber.lua")
local version = "1.1.2"
--adjust encoder settigns to your liking
norns.enc.sens(0,2)
norns.enc.accel(0,false)


-- LET'S GO!

local headPos = {0,0,0,0}
local posOffset = {0,20,40,60}
local tapeSpeeds = {1.0,1.0,1.0,1.0}
local strip = { --display colors for each of the 4 the tape loop strips 0-12
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
}
local color = 0 -- color for the record lines on the tape loop strips 0-12
local k1hold = 0 -- 1 = K1 is held
local currentTape = 1
local midi_signal_in
local actions = {"No", "Yes"}
local rndStates = {"rOff", "rRec", "rDel", "rAll"}
local tSpeeds = {"speed1", "speed2", "speed3", "speed4"}
local devices = {}

-- INIT
function init()
  for id,device in pairs(midi.vports) do
    devices[id] = device.name
  end
  params:add_group("nmQuadroDubber",24)
  params:add{type = "option", id = "midi_input", name = "Midi Input", options = devices, default = 1, action=set_midi_input}
  
  params:add_separator()
  params:add{type = "number", id = "tape", name = "Tape Loop #", min = 1, max = 4, default = 1, wrap = false, action=function(x) switchTape(x) end}
  params:add{type = "number", id = "rec", name = "OFF/REC/DEL", min = 0, max = 2, default = 0, wrap = false, action=function(x) recTape(params:get("tape"),x) end} -- 0=off 1=rec 2=del
  params:add{type = "number", id = "lvl", name = "Overdub Level", min = 0, max = 10, default = 10, action=function(x) lvl(x) end}
  params:add_control("mon","Input Monitor Level", controlspec.new(0,1,"lin",0.1,0.0,"",0.1,false))
  params:set_action("mon", function(x) mon(x) end)
  params:add_control("scLvl","Softcut Level", controlspec.new(0,1,"lin",0.1,0.0,"",0.1,false))
  params:set_action("scLvl", function(x) scLvl(x) end)
  params:add{type = "number", id = "fade", name = "Fade", min = 0, max = 5, default = 0, action=function(x) fade(x) end}
  
  params:add_separator()
  params:add{type = "number", id = "rnd", name = "rOFF/rREC/rDEL/rALL", min = 0, max = 3, default = 0, wrap = false, action=function(x) rndRecCheck() end}
  params:add{type = "number", id = "prob", name = "rProbability", min = 0, max = 10, default = 5}
  
  params:add_separator()
  params:add{type = "option", id = "clear", name = "Clear Current Loop", options = actions, default = 1, action=function(x) clear(x,params:get("tape")) end}
  params:add{type = "option", id = "clearall", name = "Clear All Loops", options = actions, default = 1, action=function(x) clear(x,5) end}
  
  params:add_separator()
  params:add_control("speed1", "Loop #1 Speed", controlspec.new(-8,8,"lin",0.1,1.0,"",0.00625,false))
  params:set_action("speed1", function(x) softcut.rate(1,x) end)
  params:add_control("speed2", "Loop #2 Speed", controlspec.new(-8,8,"lin",0.1,1.0,"",0.00625,false))
  params:set_action("speed2", function(x) softcut.rate(2,x) end)
  params:add_control("speed3", "Loop #3 Speed", controlspec.new(-8,8,"lin",0.1,1.0,"",0.00625,false))
  params:set_action("speed3", function(x) softcut.rate(3,x) end)
  params:add_control("speed4", "Loop #4 Speed", controlspec.new(-8,8,"lin",0.1,1.0,"",0.00625,false))
  params:set_action("speed4", function(x) softcut.rate(4,x) end)
  
  params:add_separator()
  params:add_control("pan1", "Loop #1 Pan", controlspec.new(1.0,-1.0,"lin",0.1,-1.0,"",0.05,false))
  params:set_action("pan1", function(x) panning(1,x) end)
  params:add_control("pan2", "Loop #2 Pan", controlspec.new(1.0,-1.0,"lin",0.1,-0.3,"",0.05,false))
  params:set_action("pan2", function(x) panning(2,x) end)
  params:add_control("pan3", "Loop #3 Pan", controlspec.new(1.0,-1.0,"lin",0.1,0.3,"",0.05,false))
  params:set_action("pan3", function(x) panning(3,x) end)
  params:add_control("pan4", "Loop #4 Pan", controlspec.new(1.0,-1.0,"lin",0.1,1.0,"",0.05,false))
  params:set_action("pan4", function(x) panning(4,x) end)
  
  softcut.buffer_clear()
  softcut.buffer_clear_region_channel(1,0,80) -- clear 80 seconds silence, probably not neccessary
  audio.level_adc_cut(1)

  softcut.loop_start(1,0) -- tape/voice 1 setup
  softcut.loop_end(1,20)
  softcut.position(1,0)
  softcut.pan(1,params:get("pan1")) -- pan hard left

  softcut.loop_start(2,20) -- tape/voice 2 setup
  softcut.loop_end(2,40)
  softcut.position(2,20)
  softcut.pan(2,params:get("pan2")) -- pan a little left
  
  softcut.loop_start(3,40)-- tape/voice 3 setup
  softcut.loop_end(3,60)
  softcut.position(3,40)
  softcut.pan(3,params:get("pan3"))  -- pan a little right
  
  softcut.loop_start(4,60)-- tape/voice 3 setup
  softcut.loop_end(4,80)
  softcut.position(4,60)
  softcut.pan(4,params:get("pan4"))  -- pan hard right
  
  
  for i=1,4 do -- more setup for the 4 voices
    softcut.enable(i,1)
    softcut.buffer(i,1)
    softcut.level(i,0.6)
    softcut.loop(i,1)
    softcut.play(i,1)
    softcut.rate(i,1.0)
    softcut.fade_time(i,0.0)
    --softcut.rec_offset(i,0.0)
    softcut.recpre_slew_time(i,0.0)
    softcut.pre_level(i,1.0)
    softcut.rec(i,1)
    softcut.phase_quant(i,0.4) -- send a counter message for voices every 0.4 seconds. 0.4*50=20 seconds, which is the loop length for each tape strip. there are 50 lines of pixels in each tape strip rectangle on screen, so this function is giving me a counter tick for each line that needs to be drawn on screen
  end
  
  redraw()
  
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
  print(version)
end


function set_midi_input(x)
  update_midi()
end

function update_midi()
  if midi_input and midi_input.event then
    midi_input.event = nil
  end
  midi_input = midi.connect(params:get("midi_input"))
  midi_input.event = midi_input_event
end

function midi_input_event(data)
  msg = midi.to_msg(data)
  -- do something if you want
end




-- SWITCH TAPE
function switchTape(t)
  recTape(currentTape,0)
  currentTape=t
  recTape(params:get("tape"),params:get("rec"))
end




-- RECORD + DELETE FUNCTION
function recTape(t,s) -- t=tape, s=state
  if s==2 then -- if DEL is active
    softcut.level_input_cut(1,t,0.0) -- turn external input volume to softcut down to 0
    softcut.level_input_cut(2,t,0.0)
    softcut.pre_level(t,0.0) -- turn overdub preserve to 0
    softcut.rec_level(t,1.0) -- record silence to softcut
  else
    softcut.level_input_cut(1,t,1.0) -- turn external input volume to softcut up to 1
    softcut.level_input_cut(2,t,1.0)
    if s==1 then -- if DEL is inactive
     softcut.pre_level(t,((params:get("lvl")-10.0)/10.0)*-1) -- set overdub preserve to inverse of "lvl" value
    else
      softcut.pre_level(t,1.0) -- set overdub preserve to 1, to keep audio on tape indefinitely
    end
    softcut.rec_level(t,s*(params:get("lvl")/10.0)) -- set record level according to "lvl" value    
  end
end




-- RANDOM RECORDING FEATURE
function rndRec(x)
  if x==1 then
    if math.random(0,10)<=params:get("prob") then
      params:set("tape",math.random(1,4))
      params:set("lvl",math.random(1,10))
      params:set("rec",math.random(0,1))
    end
  elseif x==2 then
    if math.random(0,10)<=params:get("prob") then
      if math.random(0,1)==1 then
        params:set("tape",math.random(1,4))
        params:set("rec",2)
      else
        params:set("rec",0)
      end
    end
  elseif x==3 then
    if math.random(0,10)<=params:get("prob") then
      params:set("tape",math.random(1,4))
      params:set("lvl",math.random(1,10))
      params:set("rec",math.random(0,3))
    end
  elseif x==0 then
    params:set("rec",0)
  end 
end

function rndRecCheck()
  if params:get("rnd")==0 then
    params:set("rec",0)
  end
end



function clear(i,x) -- i=2 clear, i=1 don't clear
  if i==2 and x==5 then -- clear all
    softcut.buffer_clear_region_channel(1,0,80)
    for i=1,4 do
      for j=1,50 do -- set all tape loop strip line colors to 0=black
        strip[i][j]=0
      end
    end
  elseif i==2 and x<5 then
    softcut.buffer_clear_region_channel(1,posOffset[x],20)
    for i=1,50 do -- set all tape loop strip line colors to 0=black
      strip[x][i]=0
    end
  end
end

function lvl(x)
  if params:get("rec")==1 then
    softcut.pre_level(params:get("tape"),((x-10.0)/10.0)*-1)
    softcut.rec_level(params:get("tape"),x/10.0)
  end
end

function mon(x)
  audio.level_monitor(x)
  audio.level_cut((x-1)*-1)
end

function fade(x)
  for i=1,4 do
    softcut.fade_time(i,x)
  end
end

function panning(t,p)
  softcut.pan(t,p)
end

function scLvl(x)
  for i=1,4 do
    softcut.level(i,x)
  end
end



-- BUTTONS
function key(id,st)
  if id==1 then -- K1
    if st==1 then
      k1hold=1 -- while K1 is held down, other functionality is available
    else
      k1hold=0
    end
  elseif id==2 and st==1 then -- K2
    if k1hold==0 then -- if K1 is not held, de/activate RECording
      if params:get("rec")==1 then
        params:set("rec",0)
      else
        params:set("rec",1)
      end
    else -- if K1 is held, K2 switches through random modes
      if params:get("rnd")==3 then
        params:set("rnd",0)
      else
        params:delta("rnd",1)
      end
    end
  elseif id==3 and st==1 then -- K3
    if k1hold==0 then -- if K1 is not held, de/activate deletion
      if params:get("rec")==2 then
        params:set("rec",0)
      else
        params:set("rec",2)
      end
    else -- if K1 is held, clear current tape loop strip
      params:set("clear",2)
      params:set("clear",1)
    end
  end
end




-- ENCODERS
function enc(id,delta)
  if id==1 then -- E1 changes softcut tape speed (rate) between -4.0 and 4.0
    if k1hold==0 then
        params:delta(tSpeeds[params:get("tape")],delta)
    else
      for i=1,4 do
        params:delta(tSpeeds[i],delta)
      end
    end
    
  elseif id==2 then -- E2
    if k1hold==0 then -- if K1 is not held, E2 changes overdub preserve + RECord level
      params:delta("lvl",delta)
    else -- if K1 is held, adjust softcut fade time parameter
      params:delta("fade",delta)
    end
    
  elseif id==3 then -- E3
    if k1hold==0 then -- switch tape loop
      if params:get("tape")==1 and delta<0 then
        params:set("tape",4)
      elseif params:get("tape")==4 and delta>0 then
        params:set("tape",1)
      else
        params:delta("tape",delta)
      end
      
    else -- fade between input monitor and softcut output
      params:delta("mon",delta)
    end
  end
end




-- POLL TAPE LOOP POSITIONS
function update_positions(v,p) -- v = voice, p = position
  headPos[v] = p - posOffset[v]
  
  if params:get("tape")==v then
    
    if params:get("rec")==1 then -- if RECording
      color = util.clamp(params:get("lvl")+2,0,12) -- set corrent positions color between 2-12
      strip[params:get("tape")][round(headPos[params:get("tape")]/0.4+1)] = color -- write color into array
    end
    
    if params:get("rec")==2 then -- id DELeting
      strip[params:get("tape")][round(headPos[params:get("tape")]/0.4+1)] = 0 -- write black to array
    end
    
    if params:get("rnd")~=0 then
      rndRec(params:get("rnd"))
    end
  end
end




-- DRAW THE SCREEN CONTENTS
function redraw()
  screen.clear()
  screen.line_width(1)

  -- draw tape strip rectangles
  
  for i=0,3 do
    if params:get("tape")==i+1 then
      screen.level(15)
      screen.rect(i*32+1,1,29,51)
      screen.stroke()
    else
      screen.level(1)
      screen.rect(i*32+1,1,29,51)
      screen.stroke()
    end
    
  end
  
  -- draw recorded tape strip lines inside rectangles
  for j=1,4 do
    for k=1,50 do
      screen.level(strip[j][k]) -- get color for current tape/voice position form array
      screen.move((j-1)*32+6, k+1)
      screen.line((j-1)*32+24, k+1)
      screen.stroke()
    end
  end
  
  -- draw moving playhead lines
  for i=1,4 do
    if params:get("tape")==i then
      screen.level(15)
      screen.move((i-1)*32+2,headPos[i]/0.4+2)
      screen.line((i-1)*32+28,headPos[i]/0.4+2)
      screen.stroke()
    else
      screen.level(3)
      screen.move((i-1)*32+2,headPos[i]/0.4+2)
      screen.line((i-1)*32+5,headPos[i]/0.4+2)
      screen.stroke()
      screen.move((i-1)*32+25,headPos[i]/0.4+2)
      screen.line((i-1)*32+28,headPos[i]/0.4+2)
      screen.stroke()
    end
    
  end
  
  --draw text
  screen.level(15)
  if k1hold==1 then
    screen.move(0,60)
    if params:get("rnd")==0 then
      screen.text("rOFF")
    elseif params:get("rnd")==1 then
      screen.text("rREC")
    elseif params:get("rnd")==2 then
      screen.text("rDEL")
    elseif params:get("rnd")==3 then
      screen.text("rALL")
    end
    
    screen.move(25,60)
    screen.text("clear")
    screen.move(65,60)
    screen.text("fade "..params:get("fade"))
    screen.move(99,60)
    screen.text("mon "..round(params:get("mon")*10))
  else
    screen.move(0,60)
    if params:get("rec")==1 then
      screen.text("REC!")
    else
      screen.text("rec")
    end
    screen.move(25,60)
    if params:get("rec")==2 then
      screen.text("DEL!")
    else
      screen.text("del")
    end
    screen.move(70,60)
    screen.text("lvl "..params:get("lvl"))
    screen.move(102,60)
    screen.text("t"..params:get("tape"))
    screen.move(128,60)
    screen.text_right(params:get(tSpeeds[params:get("tape")]))
  end

  screen.update()
end




-- timer to update the screen at 10 fps
re = metro.init()
re.time = 1.0 / 15
re.event = function()
  redraw()
end
re:start()




function round(n)
  return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end
