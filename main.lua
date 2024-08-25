--[[pod_format="raw",created="2024-08-21 15:27:46",modified="2024-08-22 06:21:06",revision=1]]


include("utils.lua")
include("graphics_utils.lua")
include("raycasting.lua")

--
-- Data
--

ENEMY_SPRITE = --[[pod_type="gfx"]]unpod("b64:bHo0AGkCAAB5AgAA8BNweHUAQyAmNwSvHhVPFhX-Hg0PFQRFBA7-Hg0OHx8vDx8fCwBWBA8fDw8EAIYE-x4MDx8EDhQA8P0OBA8f-x4LDw8fHwgODQ4IHQ8P-x4LDQQPDw8ODQ8PDQ8ODw8EDf8eCwUPFAQNCQQJDQQM-x4KHxYFDAQJBQwFCQQMBQv-HgRbHgQPGUQOBTv-HgBrBR4MHxkEDB4FWwV-HhUaBXsFBB4gJQsFSwU6FS4aFSsFOxQMHgwEOwU7BRoFXhoeJQ4EKyQMNA4FCwUbBS8NBU46TgAOBUQMBAVOFQcbFz5KDBQdBB4FDAQcPgsVHgYbByUeag40DI4EDisOFQcVPnoOFAxOAB4MBAcbJS4FLgwEDHoFKwVeBxsHFR41LgwELFoFDhsEDAQuBwsHFS5VHgRMWg4MBB0EBgcLByUeRQ4FDgUeLBAMFQARNQ0A8EBVPgUKDhAcAGoORR51PgAbBRo_eiVuNW4FHtoFblWe6l4ADgwAvvoAXgwOHC4FTgUe_gFeAByeFQ76AR4lDAAMfhUOFQ76AgUOGwUEFQuuCgDwBhUEDAQFLgAFXgD6Aj4cTgAuDA4MDgwA8BMsLgAOEA4sDgD6Az4cLhAePB76BA4MHgxOXA76BA4cjkwAEADwTy4lPkwO_gUeBSsFLgwuHAD6BR41HgpuAPoGDkUOCm76Bz4cjvoHXgV__gcuJU4cHvoH3voILgUEHgpe_ggODA4VHgouDA76Cg4FBAUMDgpO_goOFQQeCk76Cw4cDhoHANAUDBpO_goFLB4KDgwEKwBABQwkBSkA8AAFDBQcBfoPBUwF_hBO_gc=")

--
-- Sectors
--

SECTORS = {
	[1] = {col=4, height=1},
	[2] = {col=8, height=3},
	[3] = {col=16, height=5},

	[RC_SECTOR_INF] = {col=nil},
}

--
-- Map
--

MAP_DATA = {
	{1, 1, 1, 1, 0, 1, 1, 1},
	{0, 0, 1, 0, 0, 0, 0, 1},
	{1, 0, 1, 0, 2, 0, 0, 1},
	{1, 0, 0, 0, 0, 2, 0, 1},
	{1, 0, 0, 0, 0, 0, 0, 1},
	{1, 0, 3, 3, 0, 0, 0, 0},
	{1, 0, 0, 0, 0, 0, 0, 1},
	{1, 1, 1, 0, 1, 1, 1, 1},
}

WIDTH = #MAP_DATA[1]
HEIGHT = #MAP_DATA

MAP_CELL_SIZE = 1
-- MAP_CELL_SIZE = 0.5
-- MAP_CELL_SIZE = 2
-- MAP_CELL_SIZE = 4

--
-- Rendering consts
--

-- SCREEN_WIDTH = 270
SCREEN_WIDTH = 320
-- SCREEN_WIDTH = 270 * 1.25
-- SCREEN_WIDTH = 270 * 4/3
-- SCREEN_WIDTH = 270 * 1.5

-- SCREEN_HEIGHT = 270
SCREEN_HEIGHT = 240

SCREEN_CX = SCREEN_WIDTH / 2
SCREEN_CY = SCREEN_HEIGHT / 2

FOV_DEGREES = 90
-- FOV_DEGREES = 110
-- FOV_DEGREES = 120

MAX_DISTANCE = max(WIDTH * SQRT_2, HEIGHT * SQRT_2)
-- MAX_DISTANCE = max(WIDTH, HEIGHT)
-- MAX_DISTANCE = 0.5 * max(WIDTH, HEIGHT)
-- MAX_DISTANCE = 2
-- MAX_DISTANCE = 8
-- MAX_DISTANCE = 16
-- MAX_DISTANCE = 48

DARKEN_DISTANCE = 8
-- DARKEN_DISTANCE = nil

MINIMAP_ENABLED = true
MINIMAP_DRAW_RAYCASTS = true
MINIMAP_COLOR = true
MINIMAP_SCALE = 8
MINIMAP_X_OFF = SCREEN_WIDTH + (480 - SCREEN_WIDTH)/2 - WIDTH*MINIMAP_SCALE/2
MINIMAP_Y_OFF = 135 - HEIGHT*MINIMAP_SCALE/2

FISHEYE = false
-- FISHEYE = true

--
-- Palette stuff
--


COLORS_DARKER = {
	[0]=0,
	[1]=0,
	[2]=0,
	[3]=3+16,
	[4]=4+16,
	[5]=0,
	[6]=5,
	[7]=6,
	[8]=8+16,
	[9]=9+16,
	[10]=9,
	[11]=11+16,
	[12]=16,
	[13]=5,
	[14]=8,
	[15]=15+16,

	[0 + 16]=1,

	[3 + 16]=1,
	[4 + 16]=21,
	[5 + 16]=0,

	[8 + 16]=2,
}

--
-- Gameplay Consts
--

PLAYER_SPEED = 1/(16 * MAP_CELL_SIZE)
PLAYER_ROTATE_RATE = 5
-- SPEED_SCALE_STRAFE_AND_MOVE = 0.7071
SPEED_SCALE_STRAFE_AND_MOVE = 0.65

--
-- Globals
--

player_x = WIDTH/ 2
player_y = HEIGHT / 2
player_angle_degrees = 90

debug_select_render_mode = 1

--
-- Logic
--

function get_map(x, y)

	x = flr(x)
	y = flr(y)

	if x < 1 or y < 1 or x > WIDTH or y > HEIGHT then
		return RC_SECTOR_INF
	end

	return MAP_DATA[y][x]
end

function _init()
	rc_set_map(MAP_DATA, SECTORS, MAP_CELL_SIZE)

	rc_set_minimap(
		MINIMAP_ENABLED,
		MINIMAP_DRAW_RAYCASTS,
		MINIMAP_COLOR,
		MINIMAP_SCALE,
		MINIMAP_X_OFF,
		MINIMAP_Y_OFF,
		1/MAP_CELL_SIZE)

	rc_set_render_info(
		FOV_DEGREES,
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		FISHEYE,
		MAX_DISTANCE,
		5,
		COLORS_DARKER,
		DARKEN_DISTANCE)
end

function _update()

	local x, y = player_x, player_y

	if (keyp("1")) debug_select_render_mode = 1
	if (keyp("2")) debug_select_render_mode = 2
	if (keyp("3")) debug_select_render_mode = 3
	if (keyp("4")) debug_select_render_mode = 4

	if (btn(0) or key("q")) player_angle_degrees += PLAYER_ROTATE_RATE
	if (btn(1) or key("e")) player_angle_degrees -= PLAYER_ROTATE_RATE
	player_angle_degrees %= 360

	local speed = PLAYER_SPEED

	local forward = btn(2) or key("w")
	local backward = btn(3) or key("s")
	local strafe_left = key("a")
	local strafe_right = key("d")

	if ((forward or backward) and (strafe_left or strafe_right)) speed *= SPEED_SCALE_STRAFE_AND_MOVE

	local dx = speed * cos(player_angle_degrees / 360)
	local dy = speed * sin(player_angle_degrees / 360)

	if strafe_left then
		x += dy
		y -= dx
	end

	if strafe_right then
		x -= dy
		y += dx
	end

	if forward then
		x += dx
		y += dy
	end

	if backward then
		x -= dx
		y -= dy
	end

	local map_x = flr(x) + 1
	local map_y = flr(y) + 1

	-- TODO: smarter clipping, i.e. slide along wall
	if get_map(map_x, map_y) == 0 then
		player_x, player_y = x, y
	end
end

function draw_hud()
	-- Crosshair
	rectfill(SCREEN_CX - 4, SCREEN_CY, SCREEN_CX + 4, SCREEN_CY, 8)
	rectfill(SCREEN_CX, SCREEN_CY - 4, SCREEN_CX, SCREEN_CY + 4, 8)

	-- TODO: more HUD
end

function _draw()

	cls()

	sprites = {
		{
			s=ENEMY_SPRITE, palt=30,
			x=1.5, y=4, h=1.5,
			minimap_col=8,
		},

		{
			s=ENEMY_SPRITE, palt=30,
			x=5, y=5, h=1.5,
			minimap_col=8,
		},

	}

	local num_rays, num_sprites_drawn = rc_draw(player_x, player_y, player_angle_degrees, sprites, debug_select_render_mode)

	draw_hud()

	-- DEBUG
	-- test_fillp_gradient(false)
	-- test_fillp_gradient(true)

	-- Debug stuff
	cursor(0, 0)
	color(7)
	print('CPU ' .. round(stat(1) * 1000) / 10)
	print('Render mode ' .. debug_select_render_mode)
	print('Rays: ' .. num_rays)
	print('Sprites: ' .. num_sprites_drawn)
end
