
### Top priority big things

1. Sprites for different angles
2. Textured walls
3. Textured floor/ceiling
4. Doors

### Small things

- Sprite improvements
  - Allow specifying different sprites for different angles
  - Darken in the distance using palettes
- Change hit direction flag from X/Y to N/S/E/W
- Have the sector specify its own per-direction color (or texture)
- Change darken table to "foggen" table so it can be used for gray fog in the distance, instead of making everything darker
  - Don't want to do this yet because it's also used for X/Y direction colors
- Minimap improvements - allow custom crop of it
- Support mget() for map
- max_distance is in map units, but darken_distance is in real space units, which is confusing when `_rc_map_cell_size != 1`
- Add minimum render distance

### Complicated big things

Diagonal sector type
- One tricky part: have to worry about rays that go through this sector at an angle (but miss the wall)

Don't only use sector 0 as empty space - allow other sector types to be empty (for different floors/ceilings)
- This means a ray has to be able to cross multiple sectors before hitting a wall

Sectors that can be directly adjacent with thin wall in between
- Not too difficult, but this depends on a ray being able to have multiple hit sectors (unless you don't need any way
  to enter said sectors...)

Variable ceiling & floor heights
- Again, this requires a ray crossing multiple sectors

### Known Bugs

When using sector heights, a short sector in front of a taller sector can cause the taller sector not to be drawn
- This is actually quite complicated to fix
- Once a ray can hit multiple sectors, this becomes easier to fix
