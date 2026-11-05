# FishingToggle

A lightweight equipment-switching addon for **World of Warcraft**.

**FishingToggle** lets you switch between your fishing pole and your previously equipped weapons, without manually configuring equipment sets.

## Usage

Use the following chat command to switch equipment:

```text
/fishingtoggle
```

To create a general macro available to all characters:

```text
/fishingtoggle macro
```

To create a character-specific macro instead:

```text
/fishingtoggle macro character
```

Both commands accept an optional custom name:

```text
/fishingtoggle macro Fishing Gear
/fishingtoggle macro character Fishing Gear
```

Existing macros are never overwritten, and action bars are not modified. Open `/macro` to place the created macro on your action bar.

### Manual Macro

Alternatively, create a macro manually:

```lua
/run FishingToggle.Toggle()
```

## License

This project is under the [MIT license](https://github.com/m4jr0/gameengine/blob/master/LICENSE).