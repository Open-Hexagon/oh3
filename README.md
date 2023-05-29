# Open Hexagon 3

A potential rewrite for Open Hexagon by Vittorio Romeo using Love2D.

*(omg it's finally happening)*

## External dependencies
Apart from the pure lua dependencies that are present in the repository, the game relies on:
- Love2D
- SQLite
- Luv (this one can be installed with luarocks)

## Video Export
You need to compile `game_handler/video/encode.c` for this to work.
```
gcc encode.c -shared -fPIC -o libencode.so -lavformat -lavcodec -lavutil -lm -lswresample -lswscale
```
Then run the game with the right `LD_LIBRARY_PATH` to find the lib.

## Tests
Run tests with `luajit test/main.lua` in the source directory.
Generate coverage statistics with `luajit test/main.lua --coverage`
