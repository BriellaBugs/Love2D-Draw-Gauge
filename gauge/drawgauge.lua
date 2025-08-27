local Gauge = {}
Gauge.__index = Gauge

local gaugeImages = {}
local gaugeFonts =     setmetatable({}, { __mode = "kv" }) -- weak keys/values, auto garbage collects
local gaugeGradients = setmetatable({}, { __mode = "" }) -- {color1 = {r,g,b[,a]}, color2 = {r,g,b[,a]}}
-- gaugeGradients[r..g..b..a..r..g..b..a..radius..startLoop..endLoop] = gradientCanvas

gaugeImages["gauge"] = love.graphics.newImage("gauge/img/gauge-highres.png")

function Gauge:new(updateFunction, x, y, radius, valueLimits, loopLimits, major, minor, factor, limits, options)
	if type(updateFunction) ~= "function" then error("Invalid update function") end
	
	if not x then error("Missing x value") end
	if not y then error("Missing y value") end
	if not radius then error("Missing y radius") end
	if type(x) ~= "number" then error("Invalid x value type: "..type(x)) end
	if type(y) ~= "number" then error("Invalid y value type: "..type(y)) end
	if type(radius) ~= "number" then error("Invalid radius value type: "..type(radius)) end
	
	if type(valueLimits) == "table" then
		for i=1,2 do
			local v = valueLimits[i]
			if type(v) ~= "number" then error("Invalid value limits component #"..tostring(i).." type, got "..type(valueLimits[i])) end
		end
	else
		error("Invalid value limits type, got "..type(valueLimits))
	end
	
	if type(loopLimits) == "table" then
		for i=1,2 do
			local v = loopLimits[i]
			if type(v) ~= "number" then error("Invalid loop limits component #"..tostring(i).." type, got "..type(v)) end
		end
	else
		error("Invalid loop limits type, got "..type(loopLimits))
	end
	
	major = major or 1
	minor = minor or 0
	factor = factor or 1
	if type(major)  ~= "number" then error("Invalid major tick value type: ".. type(major))  end
	if type(minor)  ~= "number" then error("Invalid minor tick value type: ".. type(minor))  end
	if type(factor) ~= "number" then error("Invalid tick factor value type: "..type(factor)) end
	
	options = options or {}
	if options.allowOverflow == nil then
		options.allowOverflow = false
	end
	if options.gradient == nil then
		options.gradient = {color1 = {0.2,0.2,0.2,1}, color2 = {0,0,0,0}}
	end
	if options.stickTint == nil then
		options.stickTint = {0.7,0,0}
	end
	
	limits = limits or {}
	for i,limit in ipairs(limits) do
		if limit.color then
			for j=1,3 do
				local c = limit.color[j]
				if type(c) ~= "number" then
					error("Invalid color value type in limit #"..tostring(i).." , got "..type(c))
				end
			end
			limit.color[4] = limit.color[4] or 1
			if type(limit.color[4]) ~= "number" then error("Invalid alpha value type: "..type(limit.color[4])) end
		else error("No color given for limit #"..tostring(i)) end
		if limit.range then
			for j=1,2 do
				local r = limit.range[j]
				if type(r) ~= "number" then
					error("Invalid range value type in limit #"..tostring(i).." , got "..type(r))
				end
			end
		else error("No range given for limit #"..tostring(i)) end
	end
	
	local self = {
		updateFunction = updateFunction,
		x = x,
		y = y,
		value = nil,
		radius = radius,
		valueLimits = valueLimits,
		loopLimits = loopLimits,
		major = major,
		minor = minor,
		factor = factor,
		limits = limits,
		options = options
	}
	
	setmetatable(self, {__index = Gauge}) -- important fix
	return self -- return the instance, not the class
end

local function lerp(a,b,t)
	return a * (1.0 - t) + b * t
end

local function lerpColor(a,b,t)
	return {
		lerp(a[1], b[1], t),
		lerp(a[2], b[2], t),
		lerp(a[3], b[3], t),
		lerp(a[4] or 1, b[4] or 1, t)
	}
end

local function drawDonutArc(drawMode, x, y, innerR, outerR, angle1, angle2, segments)
	local sin, cos = math.sin, math.cos
	angle2 = angle1 + math.max(-math.pi*2, math.min(angle2 - angle1, math.pi*2))
	segments = segments or 64
	local step = (angle2 - angle1) / segments

	for i = 0, segments - 1 do
		local a1 = angle1 + step * i
		local a2 = angle1 + step * (i + 1)
		local a1cos = cos(a1)
		local a1sin = sin(a1)
		local a2cos = cos(a2)
		local a2sin = sin(a2)
		
		local x1_outer = x + a1cos * outerR
		local y1_outer = y + a1sin * outerR
		local x2_outer = x + a2cos * outerR
		local y2_outer = y + a2sin * outerR

		local x1_inner = x + a1cos * innerR
		local y1_inner = y + a1sin * innerR
		local x2_inner = x + a2cos * innerR
		local y2_inner = y + a2sin * innerR

		-- Draw two triangles forming a quad slice
		love.graphics.polygon(drawMode,
			x1_outer, y1_outer,
			x2_outer, y2_outer,
			x2_inner, y2_inner,
			x2_inner, y2_inner,
			x1_inner, y1_inner,
			x1_outer, y1_outer
		)
	end
end

function Gauge:update(dt)
	self.updateFunction(self, dt)
end

local function stringconcat(tbl, sep)
	local t = {}
	for i, v in ipairs(tbl) do
		t[i] = tostring(v)
	end
	return table.concat(t, sep or "")
end

local function mathsign(x)
	if x > 0 then return 1
	elseif x < 0 then return -1
	else return 0 end
end

local function createPalette(colors, resolution)
	local palette = {}
	for i=1, #colors-1 do
		local color1 = colors[i]
		local color2 = colors[i+1]
		for i=1, resolution/(#colors-1) do
			table.insert(palette, lerpColor(
				color1, color2,
				(i-1)/(resolution-1)))
		end
	end
	return palette
end

function Gauge:createGradient()
	local gradient = love.graphics.newCanvas(self.radius*2,self.radius*2)
	local increment = math.rad(1/(self.radius*0.25))
	local gradientResolution = self.radius
	
	local palette = createPalette({self.options.gradient.color1,self.options.gradient.color2},gradientResolution)

	love.graphics.setCanvas(gradient)
	love.graphics.push()
	love.graphics.translate(self.radius,self.radius)
	
	local startRad = self.loopLimits[1]
	local endRad = self.loopLimits[2]
	love.graphics.rotate(startRad)
	
	local sign = mathsign(endRad - startRad)
	local step = sign * increment
	
	local currentAng = startRad
	local function drawpalette(palette)
		love.graphics.rotate(step)
		local prevX = nil
		for i,color in ipairs(palette) do
			local x = ((i-1)/(#palette-1))*self.radius
			love.graphics.setColor(color)
			if prevX then
				love.graphics.line(prevX,0,x,0)
			end
			prevX = x
		end
		currentAng = currentAng + step
	end
	
	local edge = createPalette({{1,1,1,0.5},{0,0,0,0}},gradientResolution)
	if sign == -1 then
		while currentAng > endRad do
			drawpalette(palette)
		end
	elseif sign == 1 then
		while currentAng < endRad do
			drawpalette(palette)
		end
	elseif sign == 0 then
		print("No difference in loopLimits, gradient empty")
	end
	drawpalette(edge)
	love.graphics.pop()
	love.graphics.push()
	love.graphics.translate(self.radius,self.radius)
	love.graphics.rotate(startRad)
	
	drawpalette(edge)
	
	love.graphics.pop()
	love.graphics.setCanvas()
	
	return gradient
end

function Gauge:draw()
	love.graphics.setColor(1,1,1,1)
	local font = gaugeFonts[self.radius]
	if not gaugeFonts[self.radius] then
		font = love.graphics.newFont(self.radius * 0.12)
		gaugeFonts[self.radius] = font
	end
	love.graphics.setFont(font)
	
	--r..g..b..a..r..g..b..a..radius..startLoop..endLoop
	local gradient
	if self.options.gradient then
		local color1 = self.options.gradient.color1
		local color2 = self.options.gradient.color2
		local gradkey = stringconcat({color1[1],color1[2],color1[3],color1[4],color2[1],color2[2],color2[3],color2[4],self.radius,self.loopLimits[1],self.loopLimits[2]},"-")
		gradient = gaugeGradients[gradkey]
		if not gaugeGradients[gradkey] then
			gradient = self:createGradient()
			-- print("Created unexistent gradient: "..gradkey)
			gaugeGradients[gradkey] = gradient
		end
	end
	
	local allowOverflow = self.options.allowOverflow
	
	love.graphics.push()
	love.graphics.translate(self.x,self.y)
	
	love.graphics.draw(gradient,-self.radius,-self.radius)
	
	for _,limit in ipairs(self.limits) do
		love.graphics.setColor(limit.color)
		local startLimit = lerp(self.loopLimits[1],self.loopLimits[2],(limit.range[1]-self.valueLimits[1])/(self.valueLimits[2]-self.valueLimits[1]))
		local endLimit   = lerp(self.loopLimits[1],self.loopLimits[2],(limit.range[2]-self.valueLimits[1])/(self.valueLimits[2]-self.valueLimits[1]))
		drawDonutArc("fill",0,0,self.radius*0.95,self.radius,startLimit,endLimit,64)
	end
	love.graphics.setColor(1,1,1,1)
	
	love.graphics.push()
	love.graphics.rotate(self.loopLimits[1]-(self.loopLimits[2]-self.loopLimits[1])/self.major)
	for i = 0, self.major do
		love.graphics.rotate((self.loopLimits[2]-self.loopLimits[1])/self.major)
		love.graphics.line(self.radius*0.9,0,self.radius,0)
		
		if self.factor ~= -1 then
			local str = string.format("%d", self.factor * lerp(self.valueLimits[1], self.valueLimits[2], i / self.major))
			local angle = self.loopLimits[1] + (self.loopLimits[2] - self.loopLimits[1]) * (i / self.major)
			local labelX = math.cos(angle) * self.radius * 0.75
			local labelY = math.sin(angle) * self.radius * 0.75
			
			love.graphics.push()
				love.graphics.origin()
				love.graphics.print(str, self.x + labelX - font:getWidth(str)/2, self.y + labelY - font:getHeight()/2)
			love.graphics.pop()
		end
		
		for j = 1, self.minor do
			if i ~= self.major then
				love.graphics.push()
				love.graphics.rotate(j * (self.loopLimits[2] - self.loopLimits[1]) / self.major / (self.minor + 1))
				love.graphics.line(self.radius * 0.95, 0, self.radius, 0)
				love.graphics.pop()
			end
		end
	end
	love.graphics.pop()
	
	local normalValue
	if self.value then
		normalValue = (self.value-self.valueLimits[1])/(self.valueLimits[2]-self.valueLimits[1])
		if not allowOverflow then normalValue = math.min(math.max(normalValue,0),1) end
	end
	local imgW, imgH = gaugeImages["gauge"]:getWidth(), gaugeImages["gauge"]:getHeight()
	
	love.graphics.setColor(0.19,0.19,0.19,1)
	love.graphics.circle("fill",0,0,self.radius*0.12)
	love.graphics.setColor(0.15,0.15,0.15,1)
	love.graphics.circle("fill",0,0,self.radius*0.10)
	
	love.graphics.setColor(1,1,1,1)
	if self.value then
		love.graphics.setColor(self.options.stickTint)
		love.graphics.draw(gaugeImages["gauge"],0,0,lerp(self.loopLimits[1],self.loopLimits[2],normalValue),self.radius*1.9/imgW,self.radius*1.9/imgW,imgW/2,imgH/2)
	end

	love.graphics.pop()
end

return Gauge

