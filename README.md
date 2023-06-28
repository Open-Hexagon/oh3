# Open Hexagon 3

A potential rewrite for Open Hexagon by Vittorio Romeo using Love2D.

*(omg it's finally happening)*

## External dependencies
Apart from the pure lua dependencies that are present in the repository, the game relies on:
- Love2D
- SQLite
- Luv
- luasodium (for compat server)
- ffmpeg (for video export)

These dependencies may have dependencies of their own.

## Building
There is a `CMakeLists.txt` for installing most of the dependencies and building the c code for the video export. It requires the following dependencies to work:
- cmake
- make
- gcc
- git
- libsodium
- pkg config
- lua 5.1
- ffmpeg

On debian-based distributions they can be installed with this command:
```
apt install \
    cmake \
    make \
    g++ \
    git \
    libsodium-dev \
    pkg-config \
    liblua5.1-dev \
    libavformat-dev \
    libavcodec-dev \
    libswresample-dev \
    libswscale-dev \
    libavutil-dev
```
(Keep in mind that the packages should not be too outdated for the code to compile.)

On arch based distributions they can be installed with this line:
```
sudo pacman -S cmake make gcc git libsodium pkgconf lua51 ffmpeg
```
Then you can proceed with building
```
mkdir build && cd build
cmake ..
make
make install
```
The last command will put the libraries inside the repository folder where the game will find them (it will not attempt to put files in standard system directories).

## Tests
Run tests with `luajit test/main.lua` in the source directory.
Generate coverage statistics with `luajit test/main.lua --coverage`
