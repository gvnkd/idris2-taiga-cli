module Model.UserStory
import JSON.Derive
import Model.Common

%language ElabReflection

public export
record UserStory where
  constructor MkUserStory
  id : Nat64Id
  ref : Bits32
  subject : String
  description : String
  status : Maybe Bits64
  milestone : Maybe Nat64Id
  version : Version

%runElab derive "UserStory" [Show, Eq, ToJSON, FromJSON]

public export
record UserStorySummary where
  constructor MkUserStorySummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : Maybe Bits64
  milestone : Maybe Nat64Id

%runElab derive "UserStorySummary" [Show, Eq, ToJSON, FromJSON]
