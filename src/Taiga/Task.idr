||| Task endpoints.
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

||| Request body for creating a task.
public export
record CreateTaskBody where
  constructor MkCreateTaskBody
  project     : Bits64
  subject     : String
  story       : Maybe Nat64Id
  description : Maybe String
  status      : Maybe Bits64
  milestone   : Maybe Bits64

public export
ToJSON CreateTaskBody where
  toJSON b =
    object $ catMaybes
      [ Just $ jpair "project" b.project
      , Just $ jpair "subject" b.subject
      , omitNothing "userstory" b.story
      , omitNothing "description" b.description
      , omitNothing "status" b.status
      , omitNothing "milestone" b.milestone
      ]

||| Request body for updating a task.
public export
record UpdateTaskBody where
  constructor MkUpdateTaskBody
  subject     : Maybe String
  description : Maybe String
  status      : Maybe Bits64
  version     : Version

public export
ToJSON UpdateTaskBody where
  toJSON b =
    object $ catMaybes
      [ omitNothing "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "status" b.status
      , Just $ jpair "version" b.version
      ]

||| Request body for changing task status.
public export
record ChangeTaskStatusBody where
  constructor MkChangeTaskStatusBody
  status  : Bits64
  version : Version

public export
ToJSON ChangeTaskStatusBody where
  toJSON b =
    object
      [ jpair "status" b.status
      , jpair "version" b.version
      ]

||| Request body for adding a comment to a task.
public export
record TaskCommentBody where
  constructor MkTaskCommentBody
  comment : String
  version : Version

public export
ToJSON TaskCommentBody where
  toJSON b =
    object
      [ jpair "comment" b.comment
      , jpair "version" b.version
      ]

parameters {auto env : ApiEnv}

   ||| List tasks in a project or belonging to a story.
   public export
   listTasks :
        (project : Maybe String)
     -> (story : Maybe Nat64Id)
     -> (page : Maybe Bits32)
     -> (pageSize : Maybe Bits32)
     -> {auto _ : HasIO io}
     -> io (Either String (List TaskSummary))
   listTasks project story page pageSize = do
     let opts := concat $ catMaybes
                    [ map (\p => [("project", p)]) project
                    , map (\s => [("userstory", showId s)]) story
                    , map (\p => [("page", show p)]) page
                    , map (\s => [("page_size", show s)]) pageSize ]
         url  := buildUrl ["tasks"] opts env.base
     resp <- authGet env url
     expectJson resp 200 "list tasks"

   ||| Get a task by its ID.
   public export
   getTask :
        (id : Nat64Id)
     -> {auto _ : HasIO io}
     -> io (Either String Task)
   getTask id = do
     let url := buildUrl ["tasks", showId id] [] env.base
     resp <- authGet env url
     expectJson resp 200 "get task"

   ||| Create a new task.
   public export
   createTask :
        (project : String)
     -> (subject : String)
     -> (story : Maybe Nat64Id)
     -> (description : Maybe String)
     -> (status : Maybe String)
     -> (milestone : Maybe Bits64)
     -> {auto _ : HasIO io}
     -> io (Either String Task)
   createTask project subject story desc stat ms = do
     let body := encode $ MkCreateTaskBody (parseBits64 project) subject story desc (map parseBits64 stat) ms
         url  := buildUrl ["tasks"] [] env.base
     resp <- authPost env url body
     expectJson resp 201 "create task"

   ||| Update an existing task (OCC-aware).
   public export
   updateTask :
        (id : Nat64Id)
     -> (subject : Maybe String)
     -> (description : Maybe String)
     -> (status : Maybe String)
     -> (version : Version)
     -> {auto _ : HasIO io}
     -> io (Either String Task)
   updateTask id subj desc stat ver = do
     let body := encode $ MkUpdateTaskBody subj desc (map parseBits64 stat) ver
         url  := buildUrl ["tasks", showId id] [] env.base
     resp <- authPatch env url body
     expectJson resp 200 "update task"

   ||| Delete a task.
   public export
   deleteTask :
        (id : Nat64Id)
     -> {auto _ : HasIO io}
     -> io (Either String ())
   deleteTask id = do
     let url := buildUrl ["tasks", showId id] [] env.base
     resp <- authDelete env url
     expectOk resp 204 "delete task"

   ||| Change the status of a task via PATCH.
   |||
   ||| The caller must supply the current `version` for OCC, and the
   ||| target `status` as its numeric ID (e.g. 36 = New, 39 = Closed).
   public export
   changeTaskStatus :
        (id : Nat64Id)
     -> (newStatus : Bits64)
     -> (version : Version)
     -> {auto _ : HasIO io}
     -> io (Either String Task)
   changeTaskStatus id newSt ver = do
     let body := encode $ MkChangeTaskStatusBody newSt ver
         url  := buildUrl ["tasks", showId id] [] env.base
     resp <- authPatch env url body
     expectJson resp 200 "change task status"

   ||| Add a comment to a task.
   public export
   taskComment :
        (id : Nat64Id)
     -> (text : String)
     -> (version : Version)
     -> {auto _ : HasIO io}
     -> io (Either String String)
   taskComment id txt ver = do
     let url  := buildUrl ["tasks", showId id] [] env.base
         body := encode $ MkTaskCommentBody txt ver
     resp <- authPatch env url body
     expectRaw resp 200 "add task comment"
