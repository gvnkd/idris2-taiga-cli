module Model.Status
import JSON.Derive

%language ElabReflection

public export
record StatusInfo where
  constructor MkStatusInfo
  id : Bits64
  name : String
  slug : String

%runElab derive "StatusInfo" [Show, Eq, ToJSON, FromJSON]
