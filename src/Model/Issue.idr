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
  status : String
  priority : Maybe String
  severity : Maybe String
  issueType : Maybe String
  version : Version

%runElab derive "Issue" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record IssueSummary where
  constructor MkIssueSummary
  id : Nat64Id
  ref : Bits32
  subject : String
  status : String
  priority : Maybe String

%runElab derive "IssueSummary" [Show,Eq,ToJSON,FromJSON]
