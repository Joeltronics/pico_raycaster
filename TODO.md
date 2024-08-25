
### Top priority big things

1. Textured walls
2. Textured floor/ceiling
3. Doors

### Small things

- Darken sprites in the distance using palettes
- Sprites that are floating above the ground
- Have the sector specify its own per-direction color (or texture)
- Change darken table to "foggen" table so it can be used for gray fog in the distance, instead of making everything darker
  - Don't want to do this yet because it's also used for X/Y direction colors
- Minimap improvements
  - Allow custom crop
  - Draw it onto a sprite and then blit at the end
- Support mget() for map
- max_distance is in map units, but darken_distance is in real space units, which is confusing when `_rc_map_cell_size != 1`
- Add minimum render distance
- API cleanups

### Complicated big things

More raycasting optimizations
- The bisection alrogithm could be optimized further, particularly with long walls. Right now it always tries to find the edges of every single map cell, but if 2 map cells are the same contiguous sector and direction then this isn't necessary. But that "contiguous" part is important - without it, a hallway with the same sector type on each side could get filled in. The best way around this is probably to have the raycaster pre-process the map to split into contiguous sectors.
- Also, once a ray hits a sector, we could find the angles to the edges of this sector, and use that as the next ray, rather than needing to hunt for edges
- Sprite drawing could probably be optimized too, it seems to be slow

Diagonal sector type
- A tricky part: have to worry about rays that go through this sector at an angle (but miss the wall)

Don't only use sector 0 as empty space - allow other sector types to be empty (for different floors/ceilings)
- This means a ray has to be able to cross multiple sectors before hitting a wall

Sectors that can be directly adjacent with thin wall in between
- Not too difficult, but this depends on a ray being able to have multiple hit sectors (unless you don't need any way
  to enter said sectors...)

Variable ceiling & floor heights
- Again, this requires a ray crossing multiple sectors

### Known Bugs

max_distance is not respected with the "infinity" distance at the edge of the map

When using sector heights, a short sector in front of a taller sector can cause the taller sector not to be drawn
- This is actually quite complicated to fix
- Once a ray can hit multiple sectors, this becomes easier to fix
