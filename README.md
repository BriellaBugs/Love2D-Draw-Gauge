[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Car Gauge style module for Love2D

<img width="602" height="332" alt="image" src="https://github.com/user-attachments/assets/8d5b2ff8-1690-431b-bd21-29684e2316a7" />

Example gauge cluster
<details>
<summary>Layout</summary>
  
```lua
local Gauge = require('gauge/drawgauge')
local gauges = {}
local car = {
  rpm = 3700,
  maxrpm = 8000,
  speed = 72.5/3.6,
  engTemp = 34,
  fuel = 0.9998
}

function love.load()
  local gradientcolor = {color1 = {0.5,0,0,1}, color2 = {0,0,0,0}}
  
  table.insert(gauges,Gauge:new(function(gauge) if car.rpm then gauge.value = car.rpm else gauge.value = nil end if car.maxrpm then gauge.valueLimits[2] = math.ceil((car.maxrpm + 501) / 1000) * 1000; gauge.major = math.ceil((car.maxrpm + 501) / 1000); gauge.limits[1].range = {car.maxrpm,math.ceil((car.maxrpm + 501) / 1000) * 1000} end end, 120,120,100,{0,8000},{-math.pi*1.10,lerp(-math.pi*0.25,-math.pi*0.5,0.5)},8,0,1/1000,{{color={1,0,0},range={6000,8000}}},{gradient = gradientcolor}))
  table.insert(gauges,Gauge:new(function(gauge) if car.fuel then gauge.value = car.fuel else gauge.value = nil end end, 480,200,100,{0,1},{math.pi*0.20,-math.pi*0.20},4,1,-1,nil,{}))
  table.insert(gauges,Gauge:new(function(gauge) if car.engTemp then gauge.value = car.engTemp else gauge.value = nil end end, 360, 260, 80, {45,115}, {-math.pi,0}, 2,3,1, {{color={1,0,0},range={109,115}}}, {allowOverflow = false}))
  table.insert(gauges,Gauge:new(function(gauge) if car.speed then gauge.value = car.speed*3.6; gauge.valueLimits = {math.floor((car.speed*3.6)/180)*180, math.floor((car.speed*3.6)/180+1)*180} end end, 300,150,140,{0,180},{-math.pi*1.25,0},9,3,1,nil,{allowOverflow = false,gradient = gradientcolor}))
end

function love.update(dt)
  for _,gauge in ipairs(gauges) do
    gauge:update(dt)
  end
end

function love.draw()
  for _,gauge in ipairs(gauges) do
    gauge:draw()
  end
end

function lerp(a,b,t)
	return a * (1.0 - t) + b * t
end
```
</details>

# How to use

```lua
Gauge = require("gauge/drawgauge")
yourgauge = Gauge:new(updateFunction, x, y, radius, valueLimits, loopLimits, major, minor, factor, limits, options)

function love.draw()
  yourgauge:draw()
end

function love.update(dt)
  yourgauge:update(dt)
end
```
## updateFunction(gauge, dt)

It is called every time Gauge:update(dt) is called

While the module is dynamic allowing you to edit any of the values at any time, most times you only need to edit gauge.value

For Example:
```lua
function(gauge, dt) gauge.value = math.sin(love.timer.getTime()) end
```

## x, y

represent the center of the gauge

## radius

represents the radius of the gauge from the center in pixels

## valueLimits {start, end}
represent the start and end limit values for the gauge

For example a speedometer would use ``{0, 180}``

and an RPM gauge would use ``{0,8200}``

## loopLimits {start, end}
represent the start and end of the gauge sweep, in radians

full loop ``{-math.pi*1.5, math.pi*0.5}``

partial loop ``{-math.pi*1.25, math.pi*0.25}``

## major
represents how many major ticks there are along the gauge
## minor
represents how many minor ticks there are along the gauge

<img width="333" height="287" alt="image" src="https://github.com/user-attachments/assets/f3b435fc-7b74-4876-8a7f-74f080a2aef5" />

4 major ticks, 3 minor ticks

<img width="314" height="282" alt="image" src="https://github.com/user-attachments/assets/884692ea-cc0c-479e-95ec-1149c825b43c" />

1 major tick, 8 minor ticks

## factor
represents by how much the numbers will be multiplied by when showing on the gauge

if factor is -1, no numbers will be displayed

<img width="364" height="253" alt="image" src="https://github.com/user-attachments/assets/42df50fa-92e2-4427-aed4-ce341a135790" />

``{0,9000}`` valueLimits, 9 major ticks, 2 minor ticks, 1/1000 factor

## limits
These define the colored ranges, like the redline,

It's used in this format:
```lua
{
  {color = {r, g, b [,a]}, range = {startValue, endValue}},
  {color = {r, g, b [,a]}, range = {startValue, endValue}},
  {...}
}
```

<img width="360" height="266" alt="image" src="https://github.com/user-attachments/assets/4860f48b-29d1-4105-a409-b43e5a3a8bbe" />

``{{color = {1,0,0}, range = {45,50}},
   {color = {1,1,0}, range = {30,45}}}``

## options {}
Other settings to change to your liking, current options are
```lua
options = {
  allowOverflow = false -- Whether the gauge can leave the loopLimits boundaries
  gradient = {color1 = {0.2,0.2,0.2,1}, color2 = {0,0,0,0}} -- Gradient colors inside the gauge, gray by default
  stickTint = {0.7,0,0,1} -- Color of the gauge stick, red by default
}
```

## Limitations and Issues
Changing `radius`, `loopLimits`, or `options.gradient` at runtime forces the gauge to regenerate its gradient canvas. This is an expensive operation and should not be done every frame, as it may cause performance issues.  
See [love.graphics.newCanvas](https://love2d.org/wiki/love.graphics.newCanvas) for more details.

# License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Real world use
While I haven't tried it (yet), you could implement this in a real car dashboard if you really wanted to
