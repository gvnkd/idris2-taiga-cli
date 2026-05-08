module Taiga.UserStory
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.UserStory
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

public export
record CreateStoryBody where
  constructor MkCreateStoryBody
  project : Bits64
  subject : String
  description : Maybe String
  milestone : Maybe Nat64Id

public export
implementation ToJSON CreateStoryBody where
  toJSON b =
    object $ catMaybes [Just $ jpair "project" b.project, Just $ jpair "subject" b.subject, omitNothing "description" b.description, omitNothing "milestone" b.milestone]

public export
record UpdateStoryBody where
  constructor MkUpdateStoryBody
  subject : Maybe String
  description : Maybe String
  milestone : Maybe Bits64
  status : Maybe Bits64
  version : Version

public export
implementation ToJSON UpdateStoryBody where
  toJSON b =
    object $ catMaybes [omitNothing "subject" b.subject, omitNothing "description" b.description, omitNothing "milestone" b.milestone, omitNothing "status" b.status, Just $ jpair "version" b.version]

parameters {auto env : ApiEnv}
  public export
  fetchStoryList : (url : String) -> {auto _ : HasIO io} -> io (Either String (List UserStorySummary, PaginationMeta))
  fetchStoryList url = do
    resp <- authGet env url
    expectJsonWithMeta resp 200 "list stories"
  public export
  listStories : (project : Maybe String) -> (page : Maybe Bits32) -> (pageSize : Maybe Bits32) -> {auto _ : HasIO io} -> io (Either String (List UserStorySummary, PaginationMeta))
  listStories mproject page pageSize =
    let opts = concat $ catMaybes [map (\p => [("page", show p)]) page, map (\s => [("page_size", show s)]) pageSize, map (\p => [("project__id", p)]) mproject] in fetchStoryList (buildUrl ["userstories"] opts env.base)
  public export
  getStory : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String UserStory)
  getStory id = do
    let errMsg : _ = "story #" ++ showId id
    let url : _ = buildUrl ["userstories", showId id] [] env.base
    resp <- authGet env url
    expectJson resp 200 errMsg
  public export
  createStory : (project : String) -> (subject : String) -> (description : Maybe String) -> (milestone : Maybe Nat64Id) -> {auto _ : HasIO io} -> io (Either String UserStory)
  createStory project subject desc mstone = do
    let body : _ = encode $ MkCreateStoryBody (parseBits64 project) subject desc mstone
    let url : _ = buildUrl ["userstories"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create story"
  public export
  updateStory : (id : Nat64Id) -> (subject : Maybe String) -> (description : Maybe String) -> (milestone : Maybe String) -> (status : Maybe String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String UserStory)
  updateStory id subj desc mstone stat ver = do
    let errMsg : _ = "story #" ++ showId id
    let body : _ = encode $ MkUpdateStoryBody subj desc (map parseBits64 mstone) (map parseBits64 stat) ver
    let url : _ = buildUrl ["userstories", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  deleteStory : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String ())
  deleteStory id = do
    let errMsg : _ = "story #" ++ showId id
    let url : _ = buildUrl ["userstories", showId id] [] env.base
    resp <- authDelete env url
    expectOk resp 204 errMsg
