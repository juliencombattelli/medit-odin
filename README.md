# Medit

My meditation on what editing should be.

Medit is my personal text editor, built from the ground up for simplicity and
performance. It reflects my opinionated views on editing: minimalist, fast, and
tailored exactly to my workflow. No bloat, no compromise, just what I need.

## How to use

TODO

## How to build

### Install dependencies

#### Odin

Medit is written in Odin. Get the latest Odin toolchain for your platform at
https://odin-lang.org/docs/install/.

#### SDL

Medit uses the following external dependencies:
- SDL 3.4+ and SDL_ttf 3.2+

You can install them with your system package manager if it provides a
compatible version.

Alternatively, you can build them from source and install them locally.
If so, you may have to install additional software for your platform. You will
find the instructions to install all required dependencies here:
- Linux: https://github.com/libsdl-org/SDL/blob/release-3.4.2/docs/README-linux.md
- Windows: https://github.com/libsdl-org/SDL/blob/release-3.4.2/docs/README-windows.md
- Doc for other platforms at https://github.com/libsdl-org/SDL/blob/release-3.4.2/docs

### Building Medit

The build system itself is written in Odin, no other tool is required to build
(no Make, CMake, Ninja, Just, shell script, or whatever).

- First bootstrap the build system:
```shell
odin build build.odin -file
```
- Build the Medit application:
```shell
./build
```
- Run Medit:
```shell
./medit file.txt
```

