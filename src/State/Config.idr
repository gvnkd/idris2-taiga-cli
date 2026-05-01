||| Static Configuration.
|||
||| Split between global config (~/.local/share/taiga-cli/config.json)
||| and workspace config (./taiga/config.json).
module State.Config

import JSON.Derive
import State.File

%language ElabReflection

||| Output format preference.
public export
data OutputFormat = TextFmt | JsonFmt

%runElab derive "OutputFormat" [Show, Eq, ToJSON, FromJSON]

||| Global config stored in ~/.local/share/taiga-cli/config.json
public export
record GlobalConfig where
  constructor MkGlobalConfig
  default_output_format : OutputFormat
  default_base_url      : Maybe String

%runElab derive "GlobalConfig" [Show, ToJSON, FromJSON]

||| Per-project config stored in ./taiga/config.json
public export
record WorkspaceConfig where
  constructor MkWorkspaceConfig
  output_format : Maybe OutputFormat

%runElab derive "WorkspaceConfig" [Show, ToJSON, FromJSON]

||| Default configs.
public export
defaultGlobalConfig : GlobalConfig
defaultGlobalConfig =
  MkGlobalConfig { default_output_format = TextFmt
                 , default_base_url      = Just "http://localhost:8000"
                 }

public export
defaultWorkspaceConfig : WorkspaceConfig
defaultWorkspaceConfig =
  MkWorkspaceConfig { output_format = Nothing }

||| Load/save for global config.
public export
loadGlobalConfig : IO (Maybe GlobalConfig)
loadGlobalConfig = load GlobalConfigStore "config"

public export
saveGlobalConfig : GlobalConfig -> IO ()
saveGlobalConfig cfg = save GlobalConfigStore "config" cfg

||| Load/save for workspace config.
public export
loadWorkspaceCfg : IO (Maybe WorkspaceConfig)
loadWorkspaceCfg = load WorkspaceStore "config"

public export
saveWorkspaceCfg : WorkspaceConfig -> IO ()
saveWorkspaceCfg cfg = save WorkspaceStore "config" cfg

||| Resolve effective output format: workspace override > global
||| default > TextFmt.
public export
resolveOutputFormat : IO OutputFormat
resolveOutputFormat = do
  wcfg <- loadWorkspaceCfg
  gcfg <- loadGlobalConfig
  pure $ case wcfg of
    Just (MkWorkspaceConfig (Just fmt)) => fmt
    _ =>
      case gcfg of
        Just (MkGlobalConfig fmt _) => fmt
        Nothing                     => TextFmt
