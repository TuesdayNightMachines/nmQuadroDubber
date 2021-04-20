-- nmQuadroDubber
-- 1.0.5 @NightMachines
-- llllllll.co/t/nmquadrodubber/
--
-- Overdub external audio
-- onto four tape loops
--
-- K1: hold for /alt menu
-- E1: tape speed
-- K2: record to tape/
--     random modes
-- K3: record silence/
--     clear tape loop
-- E2: overdub level/
--     fade time
-- E3: select tape loop/s
--     monitor mix


-- norns.script.load("code/nmQuadroDubber/nmQuadroDubber.lua")

--adjust encoder settigns to your liking
--norns.enc.sens(0,2)
norns.enc.accel(0,false)


-- LET'S GO!
rndProb = 5 -- probability of change happening in random modes 0-10 (0-100%)


headPos = {0,0,0,0}
posOffset = {0,20,40,60}
tapeSpeeds = {1.0,1.0,1.0,1.0}
pPos = 1 --playhead position 1-50
tape = 1 --tape loop strips 1-4
tapeSpeed = 1.0 --current tape speed -4.0 to 4.0
strip = { --display colors for each of the 4 the tape loop strips 0-12
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
}
state = 0 --0 play, 1 record/overdub (rec/REC on screen) 
overStr = 10 -- 0-10 overdub strength, "lvl" value on screen
color = 0 -- color for the record lines on the tape loop strips 0-12
k1hold = 0 -- 1 = K1 is held
fadeTime = 0 -- softcut fade time parameter
del = 0 -- 0 play, 1 delete (del/DEL on screen) 
mon = 0.0 --monitor volume 0-1 (mon on screen)

rndState = 0 -- random modes: 0=off, 1=random rec, 2=random del, 3=random all


-- INIT
function init()
  softcut.buffer_clear()
  softcut.buffer_clear_region_channel(1,0,80) -- clear 80 seconds silence, probably not neccessary
  audio.level_adc_cut(1)

  softcut.loop_start(1,0) -- tape/voice 1 setup
  softcut.loop_end(1,20)
  softcut.position(1,0)
  softcut.pan(1,1) -- pan hard left

  softcut.loop_start(2,20) -- tape/voice 2 setup
  softcut.loop_end(2,40)
  softcut.position(2,20)
  softcut.pan(2,0.3) -- pan a little left
  
  softcut.loop_start(3,40)-- tape/voice 3 setup
  softcut.loop_end(3,60)
  softcut.position(3,40)
  softcut.pan(3,-0.3)  -- pan a little right
  
  softcut.loop_start(4,60)-- tape/voice 3 setup
  softcut.loop_end(4,80)
  softcut.position(4,60)
  softcut.pan(4,-1)  -- pan hard right
  
  
  for i=1,4 do -- more setup for the 4 voices
    softcut.enable(i,1)
    softcut.buffer(i,1)
    softcut.level(i,0.4)
    softcut.loop(i,1)
    softcut.play(i,1)
    softcut.rate(i,1.0)
    softcut.fade_time(i,0.0)
    softcut.rec_offset(i,0.0)
    softcut.recpre_slew_time(i,0.0)
    softcut.pre_level(i,1.0)
    softcut.rec(i,1)
    softcut.phase_quant(i,0.4) -- send a counter message for voices every 0.4 seconds. 0.4*50=20 seconds, which is the loop length for each tape strip. there are 50 lines of pixels in each tape strip rectangle on screen, so this function is giving me a counter tick for each line that needs to be drawn on screen
  end
  
  redraw()
  
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
end


-- BUTTONS
function key(id,st)
  if id==2 and st==1 then -- K2
    if k1hold==1 then -- if K1 is held, K2 switches through random modes
      rndState = rndState+1
      if rndState>3 then
        rndState=0
      end

      else -- if K1 is not held, de/activate RECording
      if state==1 then 
        state = 0
        recTape(tape,state)
      else 
        del=0
        state = 1
        recTape(tape,state)
      end
    end
  elseif id==1 then -- K1
    if st==1 then
      k1hold=1 -- while K1 is held down, other functionality is available
    else
      k1hold=0
    end
  elseif id==3 and st==1 then -- K3
    if k1hold==1 then -- if K1 is held, clear current tape loop strip
      if tape==1 then 
        softcut.buffer_clear_region_channel(1,0,20)
      elseif tape==2 then
        softcut.buffer_clear_region_channel(1,20,20)
      elseif tape==3 then
        softcut.buffer_clear_region_channel(1,40,20)
      elseif tape==4 then
        softcut.buffer_clear_region_channel(1,60,20)
      end
      for i=1,50 do -- set all tape loop strip line colors to 0=black
        strip[tape][i]=0
      end

    else -- if K1 is not held, de/activate deletion
      if del==0 then
        state=0 -- disable RECording in case it's actiue
        del=1
        recTape(tape,state)
      else
        del=0
        recTape(tape,state)
      end
      
    end
  end
end


-- ENCODERS
function enc(id,delta)
  if id==3 then -- E3
    if k1hold==1 then -- fade between input monitor and softcut output
      mon = util.clamp(mon+delta/10,0.0,1.0)
      audio.level_monitor(mon)
      audio.level_cut((mon-1)*-1)
    else -- switch tape loop
      if del==1 then
        del=0
        recTape(tape,0)
        del=1
      else
        recTape(tape,0) --turn off previous recording
      end
      tape = util.clamp(tape+delta,1,4)
      recTape(tape,state)
    end
    
  elseif id==2 then -- E2
    if k1hold==0 then -- if K1 is not held, E2 changes overdub preserve + RECord level
      overStr = util.clamp(overStr+delta,0,10)
      if state==1 then
        softcut.pre_level(tape,((overStr-10.0)/10.0)*-1) -- turn pre_level down to overdub
        softcut.rec_level(tape,overStr/10.0) -- turn rec_level up
      end

    else -- if K1 is held, adjust softcut fade time parameter
      fadeTime = util.clamp(fadeTime+delta,0,5)
      for i=1,4 do
        softcut.fade_time(i,fadeTime)
      end
    end
    
  elseif id==1 then -- E1 changes softcut tape speed (rate) between -4.0 and 4.0
    tapeSpeeds[tape] = util.clamp(tapeSpeeds[tape]+delta/10,-4.0,4.0)
    if tapeSpeeds[tape]<0.1 and tapeSpeeds[tape]>-0.1 then
      tapeSpeeds[tape]=0.0
    end
    softcut.rate(tape,tapeSpeeds[tape])
  end
end



function update_positions(v,p) -- v = voice, p = position
  headPos[v] = p - posOffset[v]
  
  if tape==v then
    
  if state==1 then -- if RECording
      color = util.clamp(overStr+2,0,12) -- set corrent positions color between 2-12
      strip[tape][round(headPos[v]/0.4+1)] = color -- write color into array
    end
    
    if del==1 then -- id DELeting
      strip[tape][round(headPos[v]/0.4+1)] = 0 -- write black to array
    end
    
    if rndState==0 then -- Random rec/del off
      --do nothing
    elseif rndState==1 then -- random rec on
      rndRec()
    elseif rndState==2 then -- random del on
      rndDel()
    elseif rndState==3 then -- both random rec and del on
      local x = math.random(0,10) 
      if x<5 then -- 50/50 chance for REC or DEL switch
        rndRec()
      else
        rndDel()
      end
    end
  end
  --redraw()
end



-- RECORD + DELETE FUNCTION
function recTape(t,s) -- t=tape, s=state
  if del==1 then -- if DEL is active
    softcut.level_input_cut(1,t,0.0) -- turn external input volume to softcut down to 0
    softcut.level_input_cut(2,t,0.0)
    softcut.pre_level(t,0.0) -- turn overdub preserve to 0
    softcut.rec_level(t,1.0) -- record silence to softcut

  else -- if DEL is inactive
    softcut.level_input_cut(1,t,1.0) -- turn external input volume to softcut up to 1
    softcut.level_input_cut(2,t,1.0)
    if s==1 then -- if state == 1 i.e. REC is active
      softcut.pre_level(t,((overStr-10.0)/10.0)*-1) -- set overdub preserve to inverse of "lvl" value 
    else -- if REC is inactive, so it's just playing back the tapes
      softcut.pre_level(t,1.0) -- set overdub preserve to 1, to keep audio on tape indefinitely
    end
    softcut.rec_level(t,s*(overStr/10.0)) -- set record level according to "lvl" value
  end
end


-- RANDOM RECORDING FEATURE
function rndRec()
  if math.random(0,10)<=rndProb then
    if state==1 then 
      state = 0
      recTape(tape,0)
    else 
      del=0
      recTape(tape,0)
      tape = math.random(1,4) -- randomly jump to tape loop
      state = 1
      overStr = math.random(0,10)
      softcut.pre_level(tape,((overStr-10.0)/10.0)*-1)
      softcut.rec_level(tape,overStr/10.0)
      recTape(tape,state)
    end
  end      
end


-- RANDOM DELETE FEATURE
function rndDel()
  if math.random(0,10)<=rndProb then
    if del==0 then
      del=0
      state=0
      recTape(tape,state)
      del=1
      tape = math.random(1,4)
      recTape(tape,state)
    else
      recTape(tape,0)
      del=0
      recTape(tape,state)
    end
  end
end


-- DRAW THE SCREEN CONTENTS
function redraw()
  screen.clear()
  screen.line_width(1)

  -- draw tape strip rectangles
  
  for i=0,3 do
    if tape==i+1 then
      screen.level(15)
      screen.rect(i*32+1,1,29,51)
      screen.stroke()
    else
      screen.level(5)
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
    if tape==i then
      screen.level(15)
      screen.move((i-1)*32+2,headPos[i]/0.4+2)
      screen.line((i-1)*32+28,headPos[i]/0.4+2)
      screen.stroke()
    else
      screen.level(5)
      screen.move((i-1)*32+2,headPos[i]/0.4+2)
      screen.line((i-1)*32+4,headPos[i]/0.4+2)
      screen.stroke()
      screen.move((i-1)*32+26,headPos[i]/0.4+2)
      screen.line((i-1)*32+28,headPos[i]/0.4+2)
      screen.stroke()
    end
    
  end
  
  --draw text
  screen.level(15)
  if k1hold==1 then
    screen.move(0,60)
    if rndState==0 then
      screen.text("rOFF")
    elseif rndState==1 then
      screen.text("rREC")
    elseif rndState==2 then
      screen.text("rDEL")
    elseif rndState==3 then
      screen.text("rALL")
    end
    
    screen.move(25,60)
    screen.text("clear")
    screen.move(65,60)
    screen.text("fade "..fadeTime)
    screen.move(100,60)
    screen.text("mon "..math.floor(mon*10))
  else
    screen.move(0,60)
    if state==0 then
      screen.text("rec")
    else
      screen.text("REC!")
    end
    screen.move(25,60)
    if del==0 then
      screen.text("del")
    else
      screen.text("DEL!")
    end
    screen.move(70,60)
    screen.text("lvl "..overStr)
    screen.move(102,60)
    screen.text("t"..tape)
--    screen.move(108,60)
--    screen.text("s")
    screen.move(128,60)
    screen.text_right(tapeSpeeds[tape])
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
