||| Taiga issue record with FromJSON / ToJSON instances.
module Model.Issue

import JSON.Derive
import Model.Common

%language ElabReflection

||| An issue (bug report or problem tracking item).
public export
record Issue where
  constructor MkIssue
  id : Nat64Id
  ref : Bits32
  subject : String
  description : String
  status : Maybe Bits64
  priority : Maybe Bits64
  severity : Maybe Bits64
  version : Version

%runElab derive "Issue" [Show,Eq,ToJSON,FromJSON]

||| Short representation of an issue returned by list endpoints.
public export
record IssueSummary where
  constructor MkIssueSummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : Maybe Bits64
  priority : Maybe Bits64

%runElab derive "IssueSummary" [Show,Eq,ToJSON,FromJSON]
