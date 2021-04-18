-- nmQuadroDubber
-- 1.0 @NightMachines
-- llllllll.co/t/nmquadrodubber/
--
-- Overdub external audio
-- onto four tape loops
--
-- K1: hold for /alt menu
-- E1: tape speed
-- K2: record to tape
-- K3: record silence/
--     clear tape loop
-- E2: overdub level/
--     fade time
-- E3: select tape loop/
--     monitor mix


--adjust encoder settigns to your liking
--norns.enc.sens(0,2)
norns.enc.accel(0,false)

pPos = 1 --playhead position
tape = 1 --tape strips 1-4
tapeSpeed = 1.0 --current tape speed
strip = {
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
} --tape strip colors, 4 arrays of 50 pixels each
state = 0 --0 play, 1 overdub
overStr = 10 -- 1-10 overdub strength (1-100%)
color = 0 -- screen.level 0-15
k1hold = 0 -- hold K2
fadeTime = 0 -- softcut fade time
del = 0 -- delete active 
mon = 0.0 --monitor volume 0-1



-- SOFTCUT POSITION
function update_positions(v,p)
  if v==1 then
    pPos = pPos+1
    if pPos>50 then
      softcut.position(1,0)
      softcut.position(2,20)
      softcut.position(3,40)
      softcut.position(4,60)
      pPos = 1
    end

    if state==1 then
      color = util.clamp(overStr+2,0,12)
      strip[tape][pPos] = color
    end
    
    if del==1 then
      strip[tape][pPos] = 0
    end

  end
end



-- INIT
function init()
  softcut.buffer_clear()
  softcut.buffer_clear_region_channel(1,0,80)
  audio.level_adc_cut(1)

  softcut.loop_start(1,0)
  softcut.loop_end(1,20)
  softcut.position(1,0)
  softcut.pan(1,1)

  softcut.loop_start(2,20)
  softcut.loop_end(2,40)
  softcut.position(2,20)
  softcut.pan(2,0.3)
  
  softcut.loop_start(3,40)
  softcut.loop_end(3,60)
  softcut.position(3,40)
  softcut.pan(3,-0.3)
  
  softcut.loop_start(4,60)
  softcut.loop_end(4,80)
  softcut.position(4,60)
  softcut.pan(4,-1)
  
  
  for i=1,4 do
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
  end
  
  redraw()
  
  softcut.phase_quant(1,0.4)
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()
  
end



-- BUTTONS
function key(id,st)
  if id==2 and st==1 then
    if k1hold==1 then
      
    else
      if state==1 then
        state = 0
        recTape(tape,state)
      else
        del=0
        state = 1
        recTape(tape,state)
      end
    end
  elseif id==1 then
    if st==1 then
      k1hold=1
    else
      k1hold=0
    end
  elseif id==3 and st==1 then
    if k1hold==1 then
      if tape==1 then
        softcut.buffer_clear_region_channel(1,0,20)
      elseif tape==2 then
        softcut.buffer_clear_region_channel(1,20,20)
      elseif tape==3 then
        softcut.buffer_clear_region_channel(1,40,20)
      elseif tape==4 then
        softcut.buffer_clear_region_channel(1,60,20)
      end
      for i=1,50 do
        strip[tape][i]=0
      end

    else
      if del==0 then
        state=0
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
  if id==3 then
    if k1hold==1 then
      mon = util.clamp(mon+delta/10,0.0,1.0)
      audio.level_monitor(mon)
      audio.level_cut((mon-1)*-1)
    else
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
  elseif id==2 then
    if k1hold==0 then
      
      overStr = util.clamp(overStr+delta,0,10)
      
      if state==1 then
        softcut.pre_level(tape,((overStr-10.0)/10.0)*-1)
        softcut.rec_level(tape,overStr/10.0)
      end

    else
      fadeTime = util.clamp(fadeTime+delta,0,5)
      for i=1,4 do
        softcut.fade_time(i,fadeTime)
      end
    end
    
  elseif id==1 then
    tapeSpeed = util.clamp(tapeSpeed+delta/10,0.1,4.0)
    for i=1,4 do
      softcut.rate(i,tapeSpeed)
    end
  end
  
end




function recTape(t,s)
  if del==1 then
    softcut.level_input_cut(1,t,0.0)
    softcut.level_input_cut(2,t,0.0)
    softcut.pre_level(t,0.0)
    softcut.rec_level(t,1.0)
  else
    softcut.level_input_cut(1,t,1.0)
    softcut.level_input_cut(2,t,1.0)
    if s==1 then
      softcut.pre_level(t,((overStr-10.0)/10.0)*-1)
    else
      softcut.pre_level(t,1.0)
    end
    softcut.rec_level(t,s*(overStr/10.0))
  end
end




function redraw()
  screen.clear()
  screen.line_width(1)
  
  -- draw half-width lines inside rectangles
  for j=1,4 do
    for k=1,50 do
      screen.level(strip[j][k])
      screen.move((j-1)*32+4, k+1)
      screen.line((j-1)*32+26, k+1)
      screen.stroke()
    end
  end
  
  -- draw moving playhead line
  screen.level(15)
  screen.move((tape-1)*32+2, pPos+1)
  screen.line((tape-1)*32+28, pPos+1)
  screen.stroke()
  
  --draw text
  screen.level(15)
  
  if k1hold==1 then
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
    screen.move(101,60)
    screen.text("tape "..tape)
  end
  
  -- draw rectangles
  screen.level(5)
  for i=0,3 do
    screen.rect(i*32+1,1,29,51)
    screen.stroke()
  end

  screen.update()
end




re = metro.init()
re.time = 1.0 / 10
re.event = function()
  redraw()
end
re:start()