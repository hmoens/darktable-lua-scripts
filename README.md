# darktable-lua-scripts

A collection of Lua utility scripts for [darktable](https://www.darktable.org/) that extend or simplify functionality for specific workflows. These scripts are made to support my own Darktable workflows and are provided as-is. They have only been tested on Linux, but may work on other operating systems.

## Requirements

These scripts depend on the [darktable-org/lua-scripts](https://github.com/darktable-org/lua-scripts) infrastructure. Make sure it is installed and configured correctly.

## Installation

### Linux

```bash
cd ~/.config/darktable/lua
git clone https://github.com/hmoens/darktable-lua-scripts hmoens
```

If you're using script_manager, you'll find a new category hmoens where you can toggle scripts.

## Scripts

### Lighttable exposure controls

This script adds a set of buttons in the lighttable UI, allowing quick bulk exposure adjustments to selected images (±1/3 EV and ±1 EV). An equalize exposure button equalizes the exposure of a set of images relative to the first selected one, based on their aperture, shutter speed, and ISO. This is useful when dealing with bracketed or unevenly exposed series.

Since Darktable does not allow direct editing of modules from the lighttable view, exposure adjustments are applied via temporary styles that are generated and applied behind the scenes. This requires Darktable to have write access to temporary files and to be configured to write XMP sidecars.
