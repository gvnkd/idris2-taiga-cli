||| Milestone / sprint endpoints.
module Taiga.Milestone

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Milestone
import Taiga.Api

%language ElabReflection

||| List milestones in a project.
listMilestones :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List MilestoneSummary))
listMilestones = ?rhs_listMilestones

||| Create a new milestone.
createMilestone :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (name : String)
  -> (estimatedStart : String)
  -> (estimatedFinish : String)
  -> io (Either String Milestone)
createMilestone = ?rhs_createMilestone

||| Update an existing milestone (OCC-aware).
updateMilestone :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (name : Maybe String)
  -> (estimatedStart : Maybe String)
  -> (estimatedFinish : Maybe String)
  -> (version : Version)
  -> io (Either String Milestone)
updateMilestone = ?rhs_updateMilestone
