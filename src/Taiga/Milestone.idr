||| Milestone / sprint endpoints.
module Taiga.Milestone

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Milestone
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Request body for creating a milestone.
public export
record CreateMilestoneBody where
  constructor MkCreateMilestoneBody
  project         : Bits64
  name            : String
  estimatedStart  : String
  estimatedFinish : String

public export
ToJSON CreateMilestoneBody where
  toJSON b =
    object
      [ jpair "project" b.project
      , jpair "name" b.name
      , jpair "estimated_start" b.estimatedStart
      , jpair "estimated_finish" b.estimatedFinish
      ]

||| Request body for updating a milestone.
public export
record UpdateMilestoneBody where
  constructor MkUpdateMilestoneBody
  name            : Maybe String
  estimatedStart  : Maybe String
  estimatedFinish : Maybe String
  version         : Version

public export
ToJSON UpdateMilestoneBody where
  toJSON b =
    object $ catMaybes
      [ omitNothing "name" b.name
      , omitNothing "estimated_start" b.estimatedStart
      , omitNothing "estimated_finish" b.estimatedFinish
      , Just $ jpair "version" b.version
      ]

parameters {auto env : ApiEnv}

  ||| List milestones in a project.
  public export
  listMilestones :
       (project : String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List MilestoneSummary))
  listMilestones project page pageSize = do
    let opts   := concat $ catMaybes
                     [ map (\p => [("page", show p)]) page
                     , map (\s => [("page_size", show s)]) pageSize ]
        params := [("project", project)] ++ opts
        url    := buildUrl ["milestones"] params env.base
    resp <- authGet env url
    expectJson resp 200 "list milestones"

  ||| Create a new milestone.
  public export
  createMilestone :
       (project : String)
    -> (name : String)
    -> (estimatedStart : String)
    -> (estimatedFinish : String)
    -> {auto _ : HasIO io}
    -> io (Either String Milestone)
  createMilestone project name estStart estFinish = do
    let body := encode $ MkCreateMilestoneBody (parseBits64 project) name estStart estFinish
        url  := buildUrl ["milestones"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create milestone"

  ||| Update an existing milestone (OCC-aware).
  public export
  updateMilestone :
       (id : Nat64Id)
    -> (name : Maybe String)
    -> (estimatedStart : Maybe String)
    -> (estimatedFinish : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String Milestone)
  updateMilestone id name estStart estFinish ver = do
    let body := encode $ MkUpdateMilestoneBody name estStart estFinish ver
        url  := buildUrl ["milestones", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 "update milestone"
