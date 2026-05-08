module State.Config
import JSON.Derive
import State.File

%language ElabReflection

public export
data OutputFormat : Type where
  TextFmt : OutputFormat
  JsonFmt : OutputFormat

%runElab derive "OutputFormat" [Show, Eq, ToJSON, FromJSON]

public export
record GlobalConfig where
  constructor MkGlobalConfig
  default_output_format : OutputFormat

%runElab derive "GlobalConfig" [Show, ToJSON, FromJSON]

public export
record WorkspaceConfig where
  constructor MkWorkspaceConfig
  output_format : Maybe OutputFormat

%runElab derive "WorkspaceConfig" [Show, ToJSON, FromJSON]

public export
defaultGlobalConfig : GlobalConfig
defaultGlobalConfig =
  MkGlobalConfig {default_output_format = TextFmt}

public export
defaultWorkspaceConfig : WorkspaceConfig
defaultWorkspaceConfig =
  MkWorkspaceConfig {output_format = Nothing}

public export
loadGlobalConfig : IO (Maybe GlobalConfig)
loadGlobalConfig =
  load GlobalConfigStore "config"

public export
saveGlobalConfig : GlobalConfig -> IO ()
saveGlobalConfig cfg =
  save GlobalConfigStore "config" cfg

public export
loadWorkspaceCfg : IO (Maybe WorkspaceConfig)
loadWorkspaceCfg =
  load WorkspaceStore "config"

public export
saveWorkspaceCfg : WorkspaceConfig -> IO ()
saveWorkspaceCfg cfg =
  save WorkspaceStore "config" cfg

public export
resolveOutputFormat : IO OutputFormat
resolveOutputFormat = do
  wcfg <- loadWorkspaceCfg
  gcfg <- loadGlobalConfig
  pure $ (case wcfg of
            Just (MkWorkspaceConfig (Just fmt)) => fmt
            _ => case gcfg of
                   Just (MkGlobalConfig fmt) => fmt
                   Nothing => TextFmt)
