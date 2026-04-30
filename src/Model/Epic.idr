||| Taiga epic record with FromJSON / ToJSON instances.
module Model.Epic

import JSON.Derive
import Model.Common

%language ElabReflection

||| An epic (large body of work spanning multiple sprints).
public export
record Epic where
  constructor MkEpic
  id : Nat64Id
  ref : Bits32
  subject : String
  description : String
  status : Maybe Bits64
  version : Maybe Version

%runElab derive "Epic" [Show,Eq,ToJSON,FromJSON]

||| Short representation of an epic returned by list endpoints.
public export
record EpicSummary where
  constructor MkEpicSummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : Maybe Bits64

%runElab derive "EpicSummary" [Show,Eq,ToJSON,FromJSON]
