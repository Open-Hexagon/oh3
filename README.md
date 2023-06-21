# Open Hexagon 3

A potential rewrite for Open Hexagon by Vittorio Romeo using Love2D.

*(omg it's finally happening)*

## External dependencies
Apart from the pure lua dependencies that are present in the repository, the game relies on:
- Love2D
- SQLite
- Luv
- luasodium (only required for compat server)

Luv and luasodium can be installed with luarocks. The lua version has to be specified as 5.1 in the luarocks command for luajit to find the libraries.
```
luarocks --lua-version 5.1 luv luasodium
```

## Tests
Run tests with `luajit test/main.lua` in the source directory.
Generate coverage statistics with `luajit test/main.lua --coverage`
