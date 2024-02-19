---@meta

---@class Spoon
---@field public name string
---@field public version string
---@field public author string
---@field public license string
---@field public homepage string?
---@field public start fun(self: Spoon)?
---@field public stop fun(self: Spoon)?
---@field public init fun(self: Spoon)

---@class LaunchCommandLine
---@field public executable string
---@field public nohup boolean
---@field public background boolean
---@field public args table

---@class TerminalTemplate
---@field public macApp string
---@field public bundleId string
---@field public windowIdentifier string
---@field public launchCmdLine LaunchCommandLine

---@class Terminal
---@field public fromTemplate fun(template: TerminalTemplate): Terminal
---@field public init fun(self: Terminal, display: hs.screen)
---@field public startVisorWindow fun(self: Terminal, display: hs.screen): hs.window?
---@field public hideVisorWindow fun(self: Terminal, window: hs.window, display: hs.screen): hs.window
---@field public showVisorWindow fun(self: Terminal, window: hs.window, display: hs.screen): hs.window
---@field public isShowing fun(self: Terminal, window: hs.window): boolean
---@field public getTerminalAppAndVisor fun(self: Terminal, maybeVisorWindow: hs.window?): hs.application, hs.window
---@field public macApp string
---@field public bundleId string
---@field public windowIdentifier string
---@field public launchCmdLine LaunchCommandLine
