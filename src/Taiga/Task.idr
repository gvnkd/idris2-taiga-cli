module Taiga.Task
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Task
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

public export
record CreateTaskBody where
  constructor MkCreateTaskBody
  project : Bits64
  subject : String
  story : Maybe Nat64Id
  description : Maybe String
  status : Maybe Bits64
  milestone : Maybe Bits64

public export
implementation ToJSON CreateTaskBody where
  toJSON b =
    object $ catMaybes [Just $ jpair "project" b.project, Just $ jpair "subject" b.subject, omitNothing "userstory" b.story, omitNothing "description" b.description, omitNothing "status" b.status, omitNothing "milestone" b.milestone]

public export
record UpdateTaskBody where
  constructor MkUpdateTaskBody
  subject : Maybe String
  description : Maybe String
  status : Maybe Bits64
  version : Version

public export
implementation ToJSON UpdateTaskBody where
  toJSON b =
    object $ catMaybes [omitNothing "subject" b.subject, omitNothing "description" b.description, omitNothing "status" b.status, Just $ jpair "version" b.version]

public export
record UpdateTaskStoryBody where
  constructor MkUpdateTaskStoryBody
  userStory : Maybe Nat64Id
  version : Version

public export
implementation ToJSON UpdateTaskStoryBody where
  toJSON b =
    object $ catMaybes [omitNothing "user_story" b.userStory, Just $ jpair "version" b.version]

public export
record ChangeTaskStatusBody where
  constructor MkChangeTaskStatusBody
  status : Bits64
  version : Version

public export
implementation ToJSON ChangeTaskStatusBody where
  toJSON b =
    object [jpair "status" b.status, jpair "version" b.version]

public export
record TaskCommentBody where
  constructor MkTaskCommentBody
  comment : String
  version : Version

public export
implementation ToJSON TaskCommentBody where
  toJSON b =
    object [jpair "comment" b.comment, jpair "version" b.version]

parameters {auto env : ApiEnv}
  public export
  listTasks : (project : Maybe String) -> (story : Maybe Nat64Id) -> (status : Maybe String) -> (page : Maybe Bits32) -> (pageSize : Maybe Bits32) -> {auto _ : HasIO io} -> io (Either String (List TaskSummary, PaginationMeta))
  listTasks project story mstatus page pageSize = do
    let opts : _ = concat $ catMaybes [map (\p => [("project__id", p)]) project, map (\s => [("userstory", showId s)]) story, map (\s => [("status", s)]) mstatus, map (\p => [("page", show p)]) page, map (\s => [("page_size", show s)]) pageSize]
    let url : _ = buildUrl ["tasks"] opts env.base
    resp <- authGet env url
    expectJsonWithMeta resp 200 "list tasks"
  public export
  getTask : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String Task)
  getTask id = do
    let errMsg : _ = "task #" ++ showId id
    let url : _ = buildUrl ["tasks", showId id] [] env.base
    resp <- authGet env url
    expectJson resp 200 errMsg
  public export
  createTask : (project : String) -> (subject : String) -> (story : Maybe Nat64Id) -> (description : Maybe String) -> (status : Maybe String) -> (milestone : Maybe Bits64) -> {auto _ : HasIO io} -> io (Either String Task)
  createTask project subject story desc stat ms = do
    let body : _ = encode $ MkCreateTaskBody (parseBits64 project) subject story desc (map parseBits64 stat) ms
    let url : _ = buildUrl ["tasks"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create task"
  public export
  updateTask : (id : Nat64Id) -> (subject : Maybe String) -> (description : Maybe String) -> (status : Maybe String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String Task)
  updateTask id subj desc stat ver = do
    let errMsg : _ = "task #" ++ showId id
    let body : _ = encode $ MkUpdateTaskBody subj desc (map parseBits64 stat) ver
    let url : _ = buildUrl ["tasks", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  deleteTask : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String ())
  deleteTask id = do
    let errMsg : _ = "task #" ++ showId id
    let url : _ = buildUrl ["tasks", showId id] [] env.base
    resp <- authDelete env url
    expectOk resp 204 errMsg
  public export
  changeTaskStatus : (id : Nat64Id) -> (newStatus : Bits64) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String Task)
  changeTaskStatus id newSt ver = do
    let errMsg : _ = "task #" ++ showId id
    let body : _ = encode $ MkChangeTaskStatusBody newSt ver
    let url : _ = buildUrl ["tasks", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  taskComment : (id : Nat64Id) -> (text : String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String String)
  taskComment id txt ver = do
    let errMsg : _ = "task #" ++ showId id
    let url : _ = buildUrl ["tasks", showId id] [] env.base
    let body : _ = encode $ MkTaskCommentBody txt ver
    resp <- authPatch env url body
    expectRaw resp 200 errMsg
  public export
  assignTaskToStory : (id : Nat64Id) -> (story : Maybe Nat64Id) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String Task)
  assignTaskToStory id story ver = do
    let errMsg : _ = "task #" ++ showId id
    let body : _ = encode $ MkUpdateTaskStoryBody story ver
    let url : _ = buildUrl ["tasks", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
