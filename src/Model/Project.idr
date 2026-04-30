||| Taiga project record with FromJSON / ToJSON instances.
module Model.Project

import JSON.Derive
import Model.Common

%language ElabReflection

||| A Taiga project.
public export
record Project where
  constructor MkProject
  id : Nat64Id
  slug : Slug
  name : String
  description : String
  is_private : Bool
  created_date : DateTime

%runElab derive "Project" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record ProjectSummary where
  constructor MkProjectSummary
  id : Nat64Id
  slug : Slug
  name : String

%runElab derive "ProjectSummary" [Show,Eq,ToJSON,FromJSON]
