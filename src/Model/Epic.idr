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
  status : String
  version : Version

%runElab derive "Epic" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record EpicSummary where
  constructor MkEpicSummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : String

%runElab derive "EpicSummary" [Show,Eq,ToJSON,FromJSON]
