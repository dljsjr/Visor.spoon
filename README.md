# Visor.spoon

An unofficial [Spoon](https://www.hammerspoon.org/go/#spoonsintro) for [Hammerspoon](https://www.hammerspoon.org/) to create
iTerm 2 reminiscent hotkey windows (in the Linux tradition of Guake/Yakuake/etc.) for terminals that don't support it natively,
when possible.

Currently, `Visor.spoon` only supports the Kitty terminal, but Alacritty is next on the list.

## Usage

If Hammerspoon and [Kitty](https://sw.kovidgoyal.net/kitty/) are already installed, then setting up Visor is pretty straight forward:

1. Clone this repo in to your Hammerspoon Spoons folder
2. Load the spoon in your Hammerspoon `init.lua`
3. Call the configuration method on the spoon with your desired options
4. Call `:start()` on the spoon.

### Copy-paste instructions

First, we clone the repository:

```console
# Clone the repository in to your Spoons folder
$ mkdir -p "$HOME/.hammerspoon/Spoons"
$ git clone https://github.com/dljsjr/Visor.spoon.git "$HOME/.hammerspoon/Spoons/Visor.spoon"
```

Next, we need to add Visor to our Hammerspoon `init.lua`:

```lua
-- Add the following to $HOME/.hammerspoon/init.lua
hs.loadSpoon("Visor")

spoon.Visor:configureForKitty({
  height = 0.35, -- 1.0 is full height
  opacity = 0.9 -- 0.0 is fully invisible, 1.0 is no transparency
})

-- Currently the only action provided by Visor is toggling the terminal.
-- This example binds it to the `F12` key. See the Hammerspoon documentation
-- for more information on binding keys to understand e.g. using modifiers
-- like `ctrl` or `cmd` or `opt` or `shift`.
spoon.Visor:bindHotKeys {
  toggleTerminal = { {}, "f12" }
}

-- Use `spoon.Visor.DisplayOptions.PrimaryDisplay` to always show the window on the display
-- configured as the primary desktop display in System Settings.
--
-- Use `spoon.Visor.DisplayOptions.ActiveDisplay` to have the terminal window show on the
-- display that contains the currently focused window.
spoon.Visor:showOnDisplayBehavior(spoon.Visor.DisplayOptions.PrimaryDisplay)

-- `start()` must be called (using the colon syntax as a method) on the Spoon instance
-- to register the hotkey and set up the monitoring and introspection scaffolding for
-- spawning, reattaching to, and controlling the hotkey window.
spoon.Visor:start()
```
Reload your Hammerspoon config and you should be able to show/hide your new Kitty drop-down window with the hotkey you configured
in your `init.lua`.

## Known Limitations

Kitty does not currently provide an always-on-top window config. And Hammerspoon can't reliably provide a way to force an app's window to
remains always-on-top when not focused, without doing crazy things like injecting code. Similarly, interacting with Spaces requires either
code injection or private APIs, and the Hammerspoon support for this exists, but it's dicey.

So those features don't work in Visor right now. But I'll be on the lookout for ways to do it, if possible.

## License

MIT - <https://opensource.org/licenses/MIT>
