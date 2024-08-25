
PI = 3.14159265359
TWO_PI = 6.28318530718
SQRT_2 = 1.41421356237
INV_SQRT_2 = 0.70710678118

msin = math.sin
mcos = math.cos
mtan = math.tan
masin = math.asin

function round(val)
	return flr(val + 0.5)
end

function inv_lerp(x1, x2, x)
	return (x - x1) / (x2 - x1)
end

function lerp(y1, y2, t)
	return y1 + t * (y2 - y1)
end

function rescale(val, x1, x2, y1, y2)
	return lerp(y1, y2, inv_lerp(x1, x2, val))
end

function clip_num(val, minval, maxval)
	return max(minval, min(maxval, val))
end

function tan(angle)
	-- return sin(angle) / cos(angle)
	return mtan(angle / TWO_PI)
end

function atan(val)
	return atan2(1, val)
end

function wrap05(val)
	return (val + 0.5) % 1.0 - 0.5
end

-- https://www.lexaloffle.com/bbs/?tid=2477
-- MIT licenced
function heapsort(t, cmp)
	local n = #t
	local i, j, temp
	local lower = flr(n / 2) + 1
	local upper = n
	while 1 do
		if lower > 1 then
			lower -= 1
			temp = t[lower]
		else
			temp = t[upper]
			t[upper] = t[1]
			upper -= 1
			if upper == 1 then
				t[1] = temp
				return
			end
		end

		i = lower
		j = lower * 2
		while j <= upper do
			if j < upper and cmp(t[j], t[j+1]) then
				j += 1
			end
			if cmp(temp, t[j]) then
				t[i] = t[j]
				i = j
				j += i
			else
				j = upper + 1
			end
		end
		t[i] = temp
	end
end

-- https://www.lexaloffle.com/bbs/?tid=2477
function qsort(t, cmp, i, j)
	i = i or 1
	j = j or #t
	if i < j then
		local p = i
		for k = i, j - 1 do
			if cmp(t[k], t[j]) then
				t[p], t[k] = t[k], t[p]
				p = p + 1
			end
		end
		t[p], t[j] = t[j], t[p]
		qsort(t, cmp, i, p - 1)
		qsort(t, cmp, p + 1, j)
	end
end

