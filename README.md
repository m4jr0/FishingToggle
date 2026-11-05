# FishingToggle

A lightweight equipment-switching addon for **World of Warcraft**.

**FishingToggle** lets you switch between your fishing pole and your previously equipped weapons, without manually configuring equipment sets.

## Usage

Use the following chat command to switch equipment:

```text
/fishingtoggle
```

FishingToggle selects the fishing pole with the highest available item level. It remembers your previous main-hand and off-hand equipment, including empty slots. Equipment changes are not automated during combat.

To create a general macro available to all characters:

```text
/fishingtoggle macro
```

To create a character-specific macro instead:

```text
/fishingtoggle macro character
```

Both commands accept an optional custom name (up to 16 bytes):

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

### Reset

To clear saved equipment information without changing your currently equipped items:

```text
/fishingtoggle reset
```

If an equipment request fails, FishingToggle stops the operation and preserves saved equipment when necessary. Fix the cause and toggle again to retry, or use `reset` to discard the old loadout. An interrupted restoration is also retained across reloads.

## License

This project is under the [MIT license](https://github.com/m4jr0/gameengine/blob/master/LICENSE).
