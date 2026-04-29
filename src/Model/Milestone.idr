||| Taiga milestone (sprint) record with FromJSON / ToJSON instances.
module Model.Milestone

import JSON.Derive
import Model.Common

%language ElabReflection

||| A milestone / sprint (time-boxed iteration).
public export
record Milestone where
  constructor MkMilestone
  id : Nat64Id
  name : String
  slug : Slug
  estimatedStart : Maybe DateTime
  estimatedFinish : Maybe DateTime
  version : Version

%runElab derive "Milestone" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record MilestoneSummary where
  constructor MkMilestoneSummary
  id : Nat64Id
  name : String
  slug : Slug

%runElab derive "MilestoneSummary" [Show,Eq,ToJSON,FromJSON]
