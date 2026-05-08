module Taiga.Epic
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Epic
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

public export
record CreateEpicBody where
  constructor MkCreateEpicBody
  project : Bits64
  subject : String
  description : Maybe String
  status : Maybe Bits64

public export
implementation ToJSON CreateEpicBody where
  toJSON b =
    object $ catMaybes [Just $ jpair "project" b.project, Just $ jpair "subject" b.subject, omitNothing "description" b.description, omitNothing "status" b.status]

public export
record UpdateEpicBody where
  constructor MkUpdateEpicBody
  subject : Maybe String
  description : Maybe String
  status : Maybe Bits64
  version : Version

public export
implementation ToJSON UpdateEpicBody where
  toJSON b =
    object $ catMaybes [omitNothing "subject" b.subject, omitNothing "description" b.description, omitNothing "status" b.status, Just $ jpair "version" b.version]

parameters {auto env : ApiEnv}
  public export
  listEpics : (project : Maybe String) -> (page : Maybe Bits32) -> (pageSize : Maybe Bits32) -> {auto _ : HasIO io} -> io (Either String (List EpicSummary, PaginationMeta))
  listEpics mproject page pageSize = do
    let opts : _ = concat $ catMaybes [map (\p => [("page", show p)]) page, map (\s => [("page_size", show s)]) pageSize, map (\p => [("project__id", p)]) mproject]
    let url : _ = buildUrl ["epics"] opts env.base
    resp <- authGet env url
    expectJsonWithMeta resp 200 "list epics"
  public export
  getEpic : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String Epic)
  getEpic id = do
    let errMsg : _ = "epic #" ++ showId id
    let url : _ = buildUrl ["epics", showId id] [] env.base
    resp <- authGet env url
    expectJson resp 200 errMsg
  public export
  createEpic : (project : String) -> (subject : String) -> (description : Maybe String) -> (status : Maybe String) -> {auto _ : HasIO io} -> io (Either String Epic)
  createEpic project subject desc stat = do
    let body : _ = encode $ MkCreateEpicBody (parseBits64 project) subject desc (map parseBits64 stat)
    let url : _ = buildUrl ["epics"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create epic"
  public export
  updateEpic : (id : Nat64Id) -> (subject : Maybe String) -> (description : Maybe String) -> (status : Maybe String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String Epic)
  updateEpic id subj desc stat ver = do
    let errMsg : _ = "epic #" ++ showId id
    let body : _ = encode $ MkUpdateEpicBody subj desc (map parseBits64 stat) ver
    let url : _ = buildUrl ["epics", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  deleteEpic : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String ())
  deleteEpic id = do
    let errMsg : _ = "epic #" ++ showId id
    let url : _ = buildUrl ["epics", showId id] [] env.base
    resp <- authDelete env url
    expectOk resp 204 errMsg
