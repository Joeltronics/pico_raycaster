

-- TODO: move fillp_gradient into raycasting.lua

-- TODO: this could be improved slightly for smoother transitions
FILLP_GRADIENT_TABLE = {
	[0]=0x0000, -- 0
	0b0000000001000000, -- 1
	0b0000000100000100, -- 2
	0b0000000100000100, -- 3 (2)
	0b0000010100001010, -- 4
	0b0000010100001010, -- 5 (4)
	0b0000010100001010, -- 6 (4)
	0b0101101001011010, -- 7 (8)
	0b0101101001011010, -- 8
	0b0101101001011010, -- 9 (8)
	~0b0000101000000101, -- 10 (12)
	~0b0000101000000101, -- 11 (12)
	~0b0000101000000101, -- 12
	~0b0000000100000100, -- 13 (14)
	~0b0000000100000100, -- 14
	~0b0000000001000000, -- 15
	0xFFFF, -- 16
}


function fillp_gradient(level)

	level = clip_num(round(level * 16), 0, 16)

	-- TODO: use unpack for this

	-- fillp(FILLP_GRADIENT_TABLE[level])

	if level == 1 then
		fillp(
			0b00000000,
			0b01000100,
			0b00000000,
			0b00000000,
			0b00000000,
			0b00010001,
			0b00000000,
			0b00000000
		)
	elseif level == 15 then
		fillp(
			0b11111111,
			0b11111111,
			0b11111111,
			0b11101110,
			0b11111111,
			0b11111111,
			0b11111111,
			0b10111011
		)
	else
		fillp(FILLP_GRADIENT_TABLE[level])
	end

	
end

function test_fillp_gradient(diagonal)

	if diagonal then
		cls(4)
		for y=0,16 do
			for x=0,16 do
				local level = x/32 + y/32
				fillp_gradient(level)
				rectfill(
					96 + x * 16,
					y * 16,
					96 + (x + 1) * 16,
					(y + 1) * 16,
					(20 << 8) + 4)
			end
		end
	else
		rectfill(0, 0, 240, 135, 4)
		rectfill(240, 135, 480, 270, 20)
		fillp_gradient(0.5)
		rectfill(240, 0, 480, 135, (20 << 8) + 4)
		rectfill(0, 135, 240, 270, (20 << 8) + 4)


		for val=0,16 do
			fillp_gradient(val/16)

			local x = 240 + (val - 8) * 16
			local y = 135

			rectfill(x - 8, y - 8, x + 8, y + 8, (20 << 8) + 4)

			x = 240
			y = 135 + (val - 8) * 16

			rectfill(x - 8, y - 8, x + 8, y + 8, (20 << 8) + 4)

		end
	end

	fillp()
end
