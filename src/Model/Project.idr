||| Taiga project record with FromJSON / ToJSON instances.
module Model.Project

import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import JSON.Encoder
import Model.Common
import Model.Status
import Data.List

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
  task_statuses : List StatusInfo
  issue_statuses : List StatusInfo
  us_statuses : List StatusInfo
  epic_statuses : List StatusInfo

%runElab derive "Project" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record ProjectSummary where
  constructor MkProjectSummary
  id : Nat64Id
  slug : Slug
  name : String
  my_permissions : List String
  i_am_member : Bool
  i_am_admin : Bool
  i_am_owner : Bool

%runElab derive "ProjectSummary" [Show,Eq,ToJSON,FromJSON]
