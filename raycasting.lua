

--
-- Module public consts
--

RC_SECTOR_INF = 32767

--
-- Module globals, and the public functions to set them
--

_rc_fisheye = false
_rc_half_fov = nil
_rc_asin_fov = nil
_rc_screen_width = 480
_rc_screen_height = 270

_rc_max_distance = 32767
_rc_distance_fog_color = 5

_rc_darkening_table = {}
_rc_darken_distance = nil

_rc_floor_col = 3
_rc_floor_darken = true
_rc_ceil_col = 12
_rc_ceil_darken = false

_rc_screen_cx = _rc_screen_width / 2
_rc_screen_cy = _rc_screen_height / 2

_rc_map = nil
_rc_sectors = nil
_rc_map_cell_size = 1
_rc_map_width = 0
_rc_map_height = 0

_rc_minimap_enabled = false
_rc_minimap_draw_raycasts = false
_rc_minimap_color = false
_rc_minimap_scale = 8
_rc_minimap_x_off = 240
_rc_minimap_y_off = 135
_rc_minimap_player_size = 1

_rc_num_raycasts = nil
_rc_depth_table = nil

function rc_set_map(map_data, sectors, map_cell_size)

	-- TODO: have an option to use mget()

	_rc_map = map_data
	_rc_map_width = #map_data[1]
	_rc_map_height = #map_data

	_rc_sectors = sectors or _rc_sectors

	_rc_map_cell_size = map_cell_size or 1
end

function rc_set_minimap(enabled, draw_raycasts, color, minimap_scale, x_off, y_off, player_size)
	_rc_minimap_enabled = enabled
	_rc_minimap_draw_raycasts = _rc_minimap_enabled and (draw_raycasts or _rc_minimap_draw_raycasts)
	_rc_minimap_color = color or _rc_minimap_color
	_rc_minimap_scale = minimap_scale or _rc_minimap_scale
	_rc_minimap_x_off = x_off or _rc_minimap_x_off
	_rc_minimap_y_off = y_off or _rc_minimap_y_off
	_rc_minimap_player_size = player_size or _rc_minimap_player_size
end

function rc_set_render_info(
		fov_degrees,
		screen_width,
		screen_height,
		fisheye,
		max_distance,
		distance_fog_color,
		darkening_table,
		darken_distance)

	-- TODO: when _rc_map_cell_size != 1, max_distance is in map units, but darken_distance is in real space units

	fov_degrees = fov_degrees or 90

	_rc_half_fov = fov_degrees / 720
	_rc_asin_fov = masin(fov_degrees * PI / 360)

	_rc_screen_width = screen_width or 480
	_rc_screen_height = screen_height or 270
	_rc_screen_cx = _rc_screen_width / 2
	_rc_screen_cy = _rc_screen_height / 2

	_rc_fisheye = fisheye or false

	_rc_max_distance = max_distance or 32768

	_rc_distance_fog_color = distance_fog_color or _rc_distance_fog_color

	_rc_darkening_table = darkening_table or _rc_darkening_table

	if ((darken_distance or 0) <= 0) darken_distance = nil
	_rc_darken_distance = darken_distance
end

function rc_set_floor(col, darken)
	_rc_floor_col = col
	_rc_floor_darken = true
end

function rc_set_ceil(col, darken)
	-- TODO: support skybox
	_rc_ceil_col = col
	_rc_ceil_darken = darken
end

--
-- Module private utility functions
--

function _rc_darken(col)
	local col_darker = _rc_darkening_table[col]
	-- assert(col_darker, '' .. col)
	return col_darker or col
end

function _rc_get_draw_color(sector, hit_dir)

	if (hit_dir == 'd') return _rc_distance_fog_color

	local col = sector.col

	if (not col) return nil

	if (hit_dir == 'x') col = _rc_darken(col)

	return col
end

function _rc_darken_fillp_col(col, d, double)

	if not _rc_darken_distance then
		fillp()
		return col
	end

	local val = d / _rc_darken_distance

	-- num_darken = max(1, flr(num_darken))

	-- val *= num_darken
	-- while num_darken > 1 do
	-- 	if val > 1 then
	-- 		col = _rc_darken(col)
	-- 		val -= 1
	-- 	end
	-- 	num_darken -= 1
	-- end

	if double then
		val *= 2
		if val > 1 then
			col = _rc_darken(col)
			val -= 1
		end
	end

	col += _rc_darken(col) << 8
	-- fillp_gradient(val - 1/32)
	fillp_gradient(val - 1/16)
	return col
end

function _rc_get_map(x, y)

	x = flr(x)
	y = flr(y)

	if x < 1 or y < 1 or x > _rc_map_width or y > _rc_map_height then
		return RC_SECTOR_INF
	end

	ret = _rc_map[y][x]
	assert(ret, 'x=' .. x .. ', y=' .. y)
	return ret
end

function _rc_angle_from_center(screen_x)
	if _rc_fisheye then
		return scale(screen_x, 0, _rc_screen_width, _rc_half_fov, -_rc_half_fov)
	else
		-- TODO: it should be possible to do this without needing to take sine, see https://lodev.org/cgtutor/raycasting.html
		return msin(scale(screen_x, 0, _rc_screen_width, _rc_asin_fov, -_rc_asin_fov)) / TWO_PI
	end
end

function _rc_screen_x_from_angle(angle_from_center)
	if _rc_fisheye then
		return scale(angle_from_center, _rc_half_fov, -_rc_half_fov, 0, _rc_screen_width)
	else
		return scale(masin(angle_from_center * TWO_PI), _rc_asin_fov, -_rc_asin_fov, 0, _rc_screen_width)
	end
end

--
-- Main raycast functions
--

_RC_DEBUG_MARK_RAYCASTS = true

function _rc_cast_ray(cam_x, cam_y, angle)

	_rc_num_raycasts += 1

	local dx = cos(angle)
	local dy = sin(angle)

	-- Optimal is very slightly less than 1
	-- At 1, there are rare cases it can skip 1 tile
	-- But too close to 1, can hit numeric precision problems when multiplying by d_step
	local d_step = 1 - 1/64

	dx *= d_step
	dy *= d_step

	local x = cam_x
	local y = cam_y
	local d = 0

	-- TODO: use DDA algorithm
	-- https://lodev.org/cgtutor/raycasting.html
	-- Although I'm not convinced this will be a big difference, as we're already skiping ahead (almost) 1 tile at a time
	-- That might be slightly more optimized

	local map_x = flr(x) + 1
	local map_y = flr(y) + 1

	local hit_sector = 0
	local hit_dir

	while true do
		local x_prev, y_prev, d_prev, map_x_prev, map_y_prev = x, y, d, map_x, map_y

		x += dx
		y += dy
		d += d_step

		if (d >= _rc_max_distance) then
			assert(d_prev < _rc_max_distance)
			local t = inv_lerp(d_prev, d, _rc_max_distance)
			x = x_prev + t*dx
			y = y_prev + t*dy
			d = d_prev + t*d_step
			hit_dir = 'd'
			break
		end

		map_x = flr(x) + 1
		map_y = flr(y) + 1

		-- Did we hit an x edge and/or a y edge, and if so, how far away was it?
		local t_x, t_y
		if flr(x) != flr(x_prev) then
			if dx < 0 then
				t_x = inv_lerp(x_prev, x, ceil(x))
			else
				t_x = inv_lerp(x_prev, x, flr(x))
			end
		end
		if flr(y) != flr(y_prev) then
			if dy < 0 then
				t_y = inv_lerp(y_prev, y, ceil(y))
			else
				t_y = inv_lerp(y_prev, y, flr(y))
			end
		end

		local t
		if t_x and t_y then

			if t_x <= t_y then
				-- Hit X boundary, then Y boundary

				hit_sector = _rc_get_map(map_x, map_y_prev)
				if hit_sector > 0 then
					t, hit_dir = t_x, 'x'
				else
					hit_sector = _rc_get_map(map_x, map_y)
					t, hit_dir = t_y, 'y'
				end

			else
				-- Hit Y boundary, then X boundary

				hit_sector = _rc_get_map(map_x_prev, map_y)
				if hit_sector > 0 then
					t, hit_dir = t_y, 'y'
				else
					hit_sector = _rc_get_map(map_x, map_y)
					t, hit_dir = t_x, 'x'
				end
			end

		elseif t_x then
			-- Hit X boundary
			t = t_x
			hit_sector = _rc_get_map(map_x, map_y)
			hit_dir = 'x'

		elseif t_y then
			-- Hit Y boundary
			t = t_y
			hit_sector = _rc_get_map(map_x, map_y)
			hit_dir = 'y'

		end

		if hit_sector > 0 then
			x = x_prev + t*dx
			y = y_prev + t*dy
			d = d_prev + t*d_step
			break
		end
	end

	assert(hit_sector)
	assert(hit_dir)

	return x, y, d, hit_sector, hit_dir
end

function _rc_column(screen_x, cam_x, cam_y, cam_angle_degrees)

	local angle_from_center = _rc_angle_from_center(screen_x)

	local angle = cam_angle_degrees/360 + angle_from_center

	local hit_x, hit_y, hit_d, hit_sector, hit_dir = _rc_cast_ray(cam_x, cam_y, angle)

	if (_RC_DEBUG_MARK_RAYCASTS) pset(screen_x, _rc_screen_height, 8)

	hit_d *= _rc_map_cell_size

	local height = 32767
	if hit_d > 0 then
		if _rc_fisheye then
			height = 64 / hit_d
		else
			height = 64 / (hit_d * cos(angle_from_center))
		end
	end

	return hit_x, hit_y, hit_d, height, hit_sector, hit_dir
end

--
-- Minimap
--

function _rc_draw_map()

	-- local x_off, y_off = map_x_off, map_y_off

	for y = 1,_rc_map_height do
		for x = 1,_rc_map_width do

			local x1, x2 = _rc_minimap_x_off + _rc_minimap_scale * (x - 1), _rc_minimap_x_off + _rc_minimap_scale * x
			local y1, y2 = _rc_minimap_y_off + _rc_minimap_scale * (y - 1), _rc_minimap_y_off + _rc_minimap_scale * y

			local solid = (_rc_map[y][x] > 0)
			-- local solid = (_rc_get_map(x, y) > 0)

			local col

			if _rc_minimap_color then
				col = 3
				if (solid) col = 4
			else
				col = 0
				if (solid) col = 5
			end

			rectfill(x1, y1, x2, y2, col)
		end
	end
end

function _rc_draw_raycast_on_map(cam_x, cam_y, hit_x, hit_y, col)

	-- TODO: use blend table to only draw onto black pixels

	-- FIXME: the scaling by _rc_map_cell_size is incorrect

	hit_x = _rc_minimap_x_off + _rc_minimap_scale * hit_x
	hit_y = _rc_minimap_y_off + _rc_minimap_scale * hit_y

	line(
		_rc_minimap_x_off + _rc_minimap_scale * cam_x,
		_rc_minimap_y_off + _rc_minimap_scale * cam_y,
		hit_x, hit_y, 6)

	if (col) pset(hit_x, hit_y, col)
end

function _rc_draw_fov_on_map(cam_x, cam_y, cam_angle_degrees)

	local cam_angle = cam_angle_degrees / 360

	local a = cam_angle
	local dx, dy = cos(a), sin(a)
	line(
		_rc_minimap_x_off + _rc_minimap_scale * cam_x,
		_rc_minimap_y_off + _rc_minimap_scale * cam_y,
		_rc_minimap_x_off + _rc_minimap_scale * (cam_x + dx * _rc_minimap_player_size),
		_rc_minimap_y_off + _rc_minimap_scale * (cam_y + dy * _rc_minimap_player_size),
		8)

	a = cam_angle + _rc_half_fov
	dx, dy = cos(a), sin(a)
	line(
		_rc_minimap_x_off + _rc_minimap_scale * cam_x,
		_rc_minimap_y_off + _rc_minimap_scale * cam_y,
		_rc_minimap_x_off + _rc_minimap_scale * (cam_x + dx * _rc_minimap_player_size),
		_rc_minimap_y_off + _rc_minimap_scale * (cam_y + dy * _rc_minimap_player_size),
		8)

	a = cam_angle - _rc_half_fov
	dx, dy = cos(a), sin(a)
	line(
		_rc_minimap_x_off + _rc_minimap_scale * cam_x,
		_rc_minimap_y_off + _rc_minimap_scale * cam_y,
		_rc_minimap_x_off + _rc_minimap_scale * (cam_x + dx * _rc_minimap_player_size),
		_rc_minimap_y_off + _rc_minimap_scale * (cam_y + dy * _rc_minimap_player_size),
		8)
end

function _rc_draw_sprites_on_map(player_x, player_y, sprites)

	-- Sprites
	for sprite in all(sprites) do
		-- if sprite.minimap_col and (sprite.drawn or sprite.d < 1) then
		if sprite.minimap_col then
			circfill(
				_rc_minimap_x_off + _rc_minimap_scale * sprite.x,
				_rc_minimap_y_off + _rc_minimap_scale * sprite.y,
				0.125 * _rc_minimap_scale * _rc_minimap_player_size,
				sprite.minimap_col)
		end
	end

	-- Player
	circfill(
		_rc_minimap_x_off + _rc_minimap_scale * player_x,
		_rc_minimap_y_off + _rc_minimap_scale * player_y,
		0.125 * _rc_minimap_scale * _rc_minimap_player_size,
		12)
end

--
-- Sprites
--

function _rc_sort_compare_sprites(a, b)
	-- TODO: or do I want > ?
	return a.d > b.d
end

function _rc_prepare_sprites(sprites, cam_x, cam_y, cam_angle_degrees)

	local sprites_to_draw = {}

	for sprite in all(sprites) do
		local sprite_draw = _rc_prepare_sprite(sprite, cam_x, cam_y, cam_angle_degrees)
		if (sprite_draw) add(sprites_to_draw, sprite_draw)
	end

	-- Sort in distance order
	-- heapsort(sprites_draw, _rc_sort_compare_sprites)
	qsort(sprites_to_draw, _rc_sort_compare_sprites)

	return sprites_to_draw
end

function _rc_prepare_sprite(sprite, cam_x, cam_y, cam_angle_degrees)

	local dx = sprite.x - cam_x
	local dy = sprite.y - cam_y
	local d = sqrt(dx*dx + dy*dy)

	if (d > _rc_max_distance * _rc_map_cell_size) return nil

	local angle = atan2(dx, dy)
	local angle_from_center = (angle - cam_angle_degrees/360 + 0.5) % 1.0 - 0.5

	if (angle_from_center <= -0.25 or angle_from_center >= 0.25) return nil

	local screen_x = _rc_screen_x_from_angle(angle_from_center)

	local height_scale
	if _rc_fisheye then
		height_scale = 64 / d
	else
		height_scale = 64 / (d * cos(angle_from_center))
	end

	local h = height_scale*sprite.h
	local w = h * sprite.s:width() / sprite.s:height()
	local x = screen_x - w/2

	-- TODO: technically, they should get stretched horizontally at edges of screen

	if (x + w < 0 or x >= _rc_screen_width) return nil

	local y = _rc_screen_cy + height_scale - h

	return {
		s=sprite.s, palt=sprite.palt, x=sprite.x, y=sprite.y, minimap_col=sprite.minimap_col,
		screen_x=x, screen_y=y, screen_w=w, screen_h=h,
		d=d,
	}
end

function _rc_draw_sprite(cam_x, cam_y, cam_angle_degrees, sprite)

	local x1 = max(flr(sprite.screen_x), 0)
	local x2 = min(ceil(sprite.screen_x + sprite.screen_w), _rc_screen_width - 1)

	local d1 = _rc_depth_table[x1] or 32767
	while (sprite.d > d1) do
		x1 += 1
		d1 = _rc_depth_table[x1] or 32767
		if (x1 > x2) return false
	end

	local d2 = _rc_depth_table[x2] or 32767
	while (sprite.d > d2) do
		x2 -= 1
		d2 = _rc_depth_table[x2] or 32767
		if (x1 > x2) return false
	end

	clip(x1, 0, x2-x1+1, _rc_screen_height)
	palt(0, false)
	palt(sprite.palt, true)
	sspr(sprite.s, nil, nil, nil, nil, sprite.screen_x, sprite.screen_y, sprite.screen_w, sprite.screen_h)
	palt()
	clip()

	return true
end

--
-- Raycast column drawing
--

function _rc_draw_main_column_from_raycast(screen_x, hit_d, height, hit_sector, hit_dir)

	_rc_depth_table[screen_x] = hit_d

	local col = _rc_get_draw_color(hit_sector, hit_dir)
	if (not col) return nil


	if hit_dir == 'd' then
		local y1 = _rc_screen_cy - min(_rc_screen_cy, height)
		local y2 = _rc_screen_cy + min(_rc_screen_cy, height)
		rectfill(screen_x, y1, screen_x, y2, col)

	else
		local y1 = _rc_screen_cy - min(_rc_screen_cy, height * (hit_sector.height or 1))
		local y2 = min(_rc_screen_cy + height, _rc_screen_height-1)
	
		local col_darkened = _rc_darken_fillp_col(col, hit_d, true)

		rectfill(screen_x, y1, screen_x, y2, col_darkened)
		fillp()
	end

	return col
end

function _rc_draw_wide_column_from_raycast(x1, x2, hit_d, height, hit_sector, hit_dir)

	for x=x1,x2 do
		_rc_depth_table[x] = hit_d
	end

	local col = _rc_get_draw_color(hit_sector, hit_dir)
	if (not col) return nil

	local col_darkened = _rc_darken_fillp_col(col, hit_d, true)

	local y1 = _rc_screen_cy - min(_rc_screen_cy, height * (hit_sector.height or 1))
	local y2 = min(_rc_screen_cy + height, _rc_screen_height-1)

	rectfill(x1, y1, x2, y2, col_darkened)
	fillp()

	return col
end

function _rc_draw_ray_full(screen_x, cam_x, cam_y, cam_angle_degrees)
	local hit_x, hit_y, hit_d, height, hit_sector_id, hit_dir = _rc_column(screen_x, cam_x, cam_y, cam_angle_degrees)
	local col = _rc_draw_main_column_from_raycast(screen_x, hit_d, height, _rc_sectors[hit_sector_id], hit_dir)
	if (_rc_minimap_draw_raycasts) _rc_draw_raycast_on_map(cam_x, cam_y, hit_x, hit_y, col)
end

--
-- Main screen rendering functions
--

function _rc_draw_main_chunked_bisection(cam_x, cam_y, cam_angle_degrees)

	local screen_x_1 = 0
	local screen_x_2 = _rc_screen_width - 1

	local hit_x_1, hit_y_1, hit_d_1, height_1, hit_sector_id_1, hit_dir_1 = _rc_column(screen_x_1, cam_x, cam_y, cam_angle_degrees)
	local hit_x_2, hit_y_2, hit_d_2, height_2, hit_sector_id_2, hit_dir_2 = _rc_column(screen_x_2, cam_x, cam_y, cam_angle_degrees)

	if _rc_minimap_draw_raycasts then
		_rc_draw_raycast_on_map(cam_x, cam_y, hit_x_1, hit_y_1)
		_rc_draw_raycast_on_map(cam_x, cam_y, hit_x_2, hit_y_2)
	end

	-- The inner loop only draws the left column
	_rc_draw_main_column_from_raycast(screen_x_2, hit_d_2, height_2, _rc_sectors[hit_sector_id_2], hit_dir_2)

	_rc_draw_main_chunked_bisection_inner(
		cam_x, cam_y, cam_angle_degrees,
		screen_x_1, hit_x_1, hit_y_1, hit_d_1, height_1, hit_sector_id_1, hit_dir_1,
		screen_x_2, hit_x_2, hit_y_2, hit_d_2, height_2, hit_sector_id_2, hit_dir_2)
end

function _rc_draw_main_chunked_bisection_inner(
		cam_x, cam_y, cam_angle_degrees,
		screen_x_1, hit_x_1, hit_y_1, hit_d_1, height_1, hit_sector_id_1, hit_dir_1,
		screen_x_2, hit_x_2, hit_y_2, hit_d_2, height_2, hit_sector_id_2, hit_dir_2
	)
	assert(screen_x_1 < screen_x_2, 'screen_x_1=' .. screen_x_1 .. ', screen_x_2=' .. screen_x_2)

	local sector_1 = _rc_sectors[hit_sector_id_1]

	if screen_x_2 <= screen_x_1 + 1 then
		-- These are adjacent columns, render the left one
		_rc_draw_main_column_from_raycast(screen_x_1, hit_d_1, height_1, sector_1, hit_dir_1)
		return
	end

	local hit_map_x_1, hit_map_y_1 = flr(hit_x_1), flr(hit_y_1)
	local hit_map_x_2, hit_map_y_2 = flr(hit_x_2), flr(hit_y_2)

	if hit_map_x_1 == hit_map_x_2 and hit_map_y_1 == hit_map_y_2 and hit_sector_id_1 == hit_sector_id_2 and hit_dir_1 == hit_dir_2 then
		-- Interpolate

		local col = _rc_get_draw_color(sector_1, hit_dir_1)
		if col then

			-- for x=screen_x_1,screen_x_2 do
			for x=screen_x_1,screen_x_2-1 do

				local t = (x - screen_x_1) / (screen_x_2 - screen_x_1)

				local this_hit_x = lerp(hit_x_1, hit_x_2, t)
				local this_hit_y = lerp(hit_y_1, hit_y_2, t)
				local this_hit_d = 1/lerp(1/hit_d_1, 1/hit_d_2, t)  -- TODO: lerp isn't right for d
				local this_height = lerp(height_1, height_2, t)

				_rc_draw_main_column_from_raycast(x, this_hit_d, this_height, sector_1, hit_dir_1)
			end
		end

	else
		-- Bisect

		local screen_x_c = round(0.5 * (screen_x_1 + screen_x_2))

		local hit_x_c, hit_y_c, hit_d_c, height_c, hit_sector_id_c, hit_dir_c = _rc_column(screen_x_c, cam_x, cam_y, cam_angle_degrees)

		if (_rc_minimap_draw_raycasts) _rc_draw_raycast_on_map(cam_x, cam_y, hit_x_c, hit_y_c)

		_rc_draw_main_chunked_bisection_inner(
			cam_x, cam_y, cam_angle_degrees,
			screen_x_1, hit_x_1, hit_y_1, hit_d_1, height_1, hit_sector_id_1, hit_dir_1,
			screen_x_c, hit_x_c, hit_y_c, hit_d_c, height_c, hit_sector_id_c, hit_dir_c)
		_rc_draw_main_chunked_bisection_inner(
			cam_x, cam_y, cam_angle_degrees,
			screen_x_c, hit_x_c, hit_y_c, hit_d_c, height_c, hit_sector_id_c, hit_dir_c,
			screen_x_2, hit_x_2, hit_y_2, hit_d_2, height_2, hit_sector_id_2, hit_dir_2)
	end
end

function _rc_draw_main_every_column(cam_x, cam_y, cam_angle_degrees)
	for screen_x=0,_rc_screen_width-1 do
		_rc_draw_ray_full(screen_x, cam_x, cam_y, cam_angle_degrees)
	end
end

function _rc_draw_main_chunked_2(cam_x, cam_y, cam_angle_degrees)

	local prev_hit_map_x, prev_hit_map_y, prev_hit_x, prev_hit_y, prev_hit_d, prev_height, prev_hit_dir

	-- TODO: make the chunk size bigger than 2 - try 4, 8, 16...
	-- Logic to fill in previous columns will be more complicated (needs to become generic bisection)

	_rc_draw_ray_full(_rc_screen_width-1, cam_x, cam_y, cam_angle_degrees)

	for screen_x=0,_rc_screen_width-1,2 do

		local hit_x, hit_y, hit_d, height, hit_sector_id, hit_dir = _rc_column(screen_x, cam_x, cam_y, cam_angle_degrees)

		local hit_map_x = flr(hit_x) + 1
		local hit_map_y = flr(hit_y) + 1

		local col = nil

		local hit_sector = _rc_sectors[hit_sector_id]

		if hit_sector_id != RC_SECTOR_INF then
			col = _rc_draw_main_column_from_raycast(screen_x, hit_d, height, hit_sector, hit_dir)
		end

		if (_rc_minimap_draw_raycasts) _rc_draw_raycast_on_map(cam_x, cam_y, hit_x, hit_y, col)

		if screen_x > 0 then
			-- We skipped the previous column - figure out what to do with it

			-- If we hit the same map tile as previous, then can just interpolate the previous instead of needing another raycast
			local do_interpolate = hit_map_x == prev_hit_map_x and hit_map_y == prev_hit_map_y and hit_dir == prev_hit_dir
			-- local do_interpolate = false
			-- local do_interpolate = true

			if do_interpolate then

				local this_hit_x = 0.5*(hit_x + prev_hit_x)
				local this_hit_y = 0.5*(hit_y + prev_hit_y)
				-- TODO: lerp isn't right for d - really this is barely noticeable though
				local this_hit_d = 0.5*(hit_d + prev_hit_d)
				local this_height = min(0.5*(height + prev_height), _rc_screen_cy)

				if col then
					_rc_draw_main_column_from_raycast(screen_x - 1, this_hit_d, this_height, hit_sector, hit_dir)
				end
			else
				-- Can't interpolate, need middle value
				_rc_draw_ray_full(screen_x - 1, cam_x, cam_y, cam_angle_degrees)
			end
		end

		prev_hit_map_x, prev_hit_map_y, prev_hit_x, prev_hit_y, prev_hit_d, prev_height, prev_hit_dir = hit_map_x, hit_map_y, hit_x, hit_y, hit_d, height, hit_dir
	end
end

function _rc_draw_main_chunked_3(cam_x, cam_y, cam_angle_degrees)
	for screen_x=1,_rc_screen_width,3 do

		local hit_x, hit_y, hit_d, height, hit_sector_id, hit_dir = _rc_column(screen_x, cam_x, cam_y, cam_angle_degrees)

		local col = _rc_draw_wide_column_from_raycast(
			screen_x-1,
			min(screen_x+1, _rc_screen_width-1),
			hit_d,
			height,
			_rc_sectors[hit_sector_id],
			hit_dir)

		if (_rc_minimap_draw_raycasts) _rc_draw_raycast_on_map(cam_x, cam_y, hit_x, hit_y, col)
	end
end

--
-- Ground & Sky
--

function _rc_draw_skybox(cam_angle_degrees)
	-- TODO: support skybox
	rectfill(0, 0, _rc_screen_width - 1, _rc_screen_cy, 12)
end

function _rc_draw_ceiling()
	if _rc_darken_distance and _rc_ceil_darken then

		-- Sections of 4 rows
		for screen_y=0,_rc_screen_cy-5,4 do

			-- local t = inv_lerp(_rc_screen_cy, 0, screen_y + 2)
			-- local d = (1 / t) - 0.75
			local d = _rc_screen_cy / (_rc_screen_cy - screen_y - 2) - 0.75

			local col = _rc_darken_fillp_col(_rc_ceil_col, d, false)
			rectfill(0, screen_y, _rc_screen_width - 1, screen_y + 3, col)
		end
		fillp()
		rectfill(0, _rc_screen_cy-4, _rc_screen_width - 1, _rc_screen_cy-1, _rc_darken(_rc_ceil_col))

	else
		rectfill(
			0, 0,
			_rc_screen_width - 1, _rc_screen_cy,
			_rc_ceil_col)
	end
end

function _rc_draw_ground()
	if _rc_darken_distance and _rc_floor_darken then

		-- Sections of 4 rows
		for screen_y=_rc_screen_cy,_rc_screen_height-4,4 do

			-- local t = inv_lerp(_rc_screen_cy, _rc_screen_height, screen_y + 2)
			-- local d = (1 / t) - 0.75
			local d = _rc_screen_height / (2 * screen_y + 2 - _rc_screen_height) - 0.75

			local col = _rc_darken_fillp_col(_rc_floor_col, d, false)
			rectfill(0, screen_y, _rc_screen_width - 1, screen_y + 3, col)
		end
		fillp()
		rectfill(0, _rc_screen_height-1, _rc_screen_width-1, _rc_screen_height-1, _rc_floor_col)
	else
		rectfill(
			0, _rc_screen_cy,
			_rc_screen_width-1, _rc_screen_height-1,
			_rc_floor_col)
	end
end

--
-- Main render function
--

function rc_draw(cam_x, cam_y, cam_angle_degrees, sprites, debug_render_mode)

	_rc_num_raycasts = 0
	_rc_depth_table = {}

	local sprites_to_draw = _rc_prepare_sprites(sprites, cam_x, cam_y, cam_angle_degrees)

	if false then
		-- TODO: support skybox
		_rc_draw_skybox(cam_angle_degrees)
	else
		_rc_draw_ceiling()
	end
	_rc_draw_ground()

	if (_rc_minimap_enabled and _rc_minimap_draw_raycasts) _rc_draw_map()

	if (debug_render_mode == 2) then
		_rc_draw_main_chunked_2(cam_x, cam_y, cam_angle_degrees)
	elseif (debug_render_mode == 3) then
		_rc_draw_main_chunked_3(cam_x, cam_y, cam_angle_degrees)
	elseif (debug_render_mode == 4) then
		_rc_draw_main_every_column(cam_x, cam_y, cam_angle_degrees)
	else
		_rc_draw_main_chunked_bisection(cam_x, cam_y, cam_angle_degrees)
	end

	for sprite in all(sprites_to_draw) do
		sprite.drawn = _rc_draw_sprite(cam_x, cam_y, cam_angle_degrees, sprite)
	end

	if (_rc_minimap_enabled and not _rc_minimap_draw_raycasts) _rc_draw_map()

	if (_rc_minimap_enabled) _rc_draw_fov_on_map(cam_x, cam_y, cam_angle_degrees)

	-- TODO: option to only draw sprites that are visible, or are close to the player
	if (_rc_minimap_enabled) _rc_draw_sprites_on_map(cam_x, cam_y, sprites)
	-- if (_rc_minimap_enabled) _rc_draw_sprites_on_map(cam_x, cam_y, sprites_to_draw)

	return _rc_num_raycasts, #sprites_to_draw
end
