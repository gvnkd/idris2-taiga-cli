||| Command sum type, parsing, and dispatch table.
|||
||| Each constructor corresponds to one agent-visible operation,
||| which maps to one HTTP call (or a short sequence). This module
||| re-exports from three submodules:
|||
|||   - Command.Types    : argument records + `Command` sum type
|||   - Command.Parse    : `parseCommand` — string name + JSON args → Command
|||   - Command.Dispatch : `dispatchCommand` — Command + auth → Response
module Command

import public Command.Types
import public Command.Parse
import public Command.Dispatch
