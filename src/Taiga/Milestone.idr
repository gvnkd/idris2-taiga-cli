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

public export
record CreateMilestoneBody where
  constructor MkCreateMilestoneBody
  project : Bits64
  name : String
  estimatedStart : Maybe String
  estimatedFinish : Maybe String

public export
implementation ToJSON CreateMilestoneBody where
  toJSON b =
    object $ catMaybes [Just $ jpair "project" b.project, Just $ jpair "name" b.name, omitNothing "estimated_start" b.estimatedStart, omitNothing "estimated_finish" b.estimatedFinish]

public export
record UpdateMilestoneBody where
  constructor MkUpdateMilestoneBody
  name : Maybe String
  estimatedStart : Maybe String
  estimatedFinish : Maybe String
  version : Version

public export
implementation ToJSON UpdateMilestoneBody where
  toJSON b =
    object $ catMaybes [omitNothing "name" b.name, omitNothing "estimated_start" b.estimatedStart, omitNothing "estimated_finish" b.estimatedFinish, Just $ jpair "version" b.version]

parameters {auto env : ApiEnv}
  public export
  listMilestones : (project : Maybe String) -> (page : Maybe Bits32) -> (pageSize : Maybe Bits32) -> {auto _ : HasIO io} -> io (Either String (List MilestoneSummary, PaginationMeta))
  listMilestones mproject page pageSize = do
    let opts : _ = concat $ catMaybes [map (\p => [("page", show p)]) page, map (\s => [("page_size", show s)]) pageSize, map (\p => [("project__id", p)]) mproject]
    let url : _ = buildUrl ["milestones"] opts env.base
    resp <- authGet env url
    expectJsonWithMeta resp 200 "list milestones"
  public export
  createMilestone : (project : String) -> (name : String) -> (estimatedStart : Maybe String) -> (estimatedFinish : Maybe String) -> {auto _ : HasIO io} -> io (Either String Milestone)
  createMilestone project name estStart estFinish = do
    let body : _ = encode $ MkCreateMilestoneBody (parseBits64 project) name estStart estFinish
    let url : _ = buildUrl ["milestones"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create milestone"
  public export
  updateMilestone : (id : Nat64Id) -> (name : Maybe String) -> (estimatedStart : Maybe String) -> (estimatedFinish : Maybe String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String Milestone)
  updateMilestone id name estStart estFinish ver = do
    let errMsg : _ = "milestone #" ++ showId id
    let body : _ = encode $ MkUpdateMilestoneBody name estStart estFinish ver
    let url : _ = buildUrl ["milestones", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  getMilestone : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String Milestone)
  getMilestone id = do
    let errMsg : _ = "milestone #" ++ showId id
    let url : _ = buildUrl ["milestones", showId id] [] env.base
    resp <- authGet env url
    expectJson resp 200 errMsg
  public export
  deleteMilestone : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String ())
  deleteMilestone id = do
    let errMsg : _ = "milestone #" ++ showId id
    let url : _ = buildUrl ["milestones", showId id] [] env.base
    resp <- authDelete env url
    expectOk resp 204 errMsg
