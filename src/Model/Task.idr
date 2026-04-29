||| Taiga task record with FromJSON / ToJSON instances.
module Model.Task

import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Model.Common

%language ElabReflection

||| A task (unit of implementation work).
public export
record Task where
  constructor MkTask
  id : Nat64Id
  ref : Bits32
  subject : String
  description : String
  status : Maybe Bits64
  user_story : Maybe Nat64Id
  version : Version

%runElab derive "Task" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record TaskSummary where
  constructor MkTaskSummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : Maybe Bits64
  user_story : Maybe Nat64Id

%runElab derive "TaskSummary" [Show,Eq,ToJSON,FromJSON]
