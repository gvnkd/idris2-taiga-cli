module Model.Task
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Model.Common

%language ElabReflection

public export
record Task where
  constructor MkTask
  id : Nat64Id
  ref : Bits32
  subject : String
  description : String
  status : Maybe Bits64
  user_story : Maybe Nat64Id
  is_closed : Bool
  version : Version

%runElab derive "Task" [Show, Eq, ToJSON, FromJSON]

public export
record TaskSummary where
  constructor MkTaskSummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : Maybe Bits64
  user_story : Maybe Nat64Id
  is_closed : Bool

%runElab derive "TaskSummary" [Show, Eq, ToJSON, FromJSON]
