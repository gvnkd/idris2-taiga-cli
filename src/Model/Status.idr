||| Status metadata for Taiga entities.
module Model.Status

import JSON.Derive

%language ElabReflection

||| A single status definition from the project endpoint.
public export
record StatusInfo where
  constructor MkStatusInfo
  id   : Bits64
  name : String
  slug : String

%runElab derive "StatusInfo" [Show, Eq, ToJSON, FromJSON]
