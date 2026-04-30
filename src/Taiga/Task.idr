||| Task endpoints.
module Taiga.Task

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Task
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Build JSON body for creating a task.
buildCreateBody :
     (project : String)
  -> (subject : String)
  -> (story : Maybe Nat64Id)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> String
buildCreateBody project subject story desc stat =
  "{\"project\":" ++ show (parseBits64 project) ++
  ",\"subject\":" ++ encode subject ++
  maybeStoryField story ++
  maybeDescField desc ++
  maybeStatusField stat ++ "}"

  where
    maybeStoryField : Maybe Nat64Id -> String
    maybeStoryField Nothing  = ""
    maybeStoryField (Just s) = ",\"userstory\":" ++ show s.id

    maybeDescField : Maybe String -> String
    maybeDescField Nothing  = ""
    maybeDescField (Just d) = ",\"description\":" ++ encode d

    maybeStatusField : Maybe String -> String
    maybeStatusField Nothing  = ""
    maybeStatusField (Just s) = ",\"status\":" ++ show (parseBits64 s)

||| Build JSON body for updating a task.
buildUpdateBody : Maybe String -> Maybe String -> Maybe String -> Version -> String
buildUpdateBody subj desc stat ver =
  "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"

  where
    fields : List String
    fields = catMaybes
      [ map (\s => "\"subject\":" ++ encode s) subj
      , map (\d => "\"description\":" ++ encode d) desc
      , map (\s => "\"status\":" ++ show (parseBits64 s)) stat
      ]
    joined : String
    joined = concat $ intersperse "," fields

||| Build JSON body for changing task status.
buildStatusBody : Bits64 -> Version -> String
buildStatusBody newSt ver =
  "{\"status\":" ++ show newSt ++ ",\"version\":" ++ show ver.version ++ "}"

||| Build JSON body for adding a comment.
buildCommentBody : String -> Version -> String
buildCommentBody txt ver =
  "{\"comment\":" ++ encode txt ++ ",\"version\":" ++ show ver.version ++ "}"

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
    let qs  := buildQueryString $
                  catMaybes
                    [ map (\p => ("project", p)) project
                    , map (\s => ("userstory", show s.id)) story
                    , map (\p => ("page", show p)) page
                    , map (\s => ("page_size", show s)) pageSize
                    ]
        url := env.base ++ "/tasks" ++ qs
    resp <- authGet env url
    expectJson resp 200 "list tasks"

  ||| Get a task by its ID.
  public export
  getTask :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Task)
  getTask id = do
    let url := env.base ++ "/tasks/" ++ show id.id
    resp <- authGet env url
    expectJson resp 200 "get task"

  ||| Build JSON body for creating a task.
  buildCreateTaskBody :
       String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Maybe Bits64 -> String
  buildCreateTaskBody project subject story desc stat ms =
    "{\"project\":" ++ show (parseBits64 project) ++
    ",\"subject\":" ++ encode subject ++
    maybeStoryField story ++
    maybeDescField desc ++
    maybeStatusField stat ++
    maybeMilestoneField ms ++ "}"

  where
    maybeStoryField : Maybe Nat64Id -> String
    maybeStoryField Nothing  = ""
    maybeStoryField (Just s) = ",\"userstory\":" ++ show s.id

    maybeDescField : Maybe String -> String
    maybeDescField Nothing  = ""
    maybeDescField (Just d) = ",\"description\":" ++ encode d

    maybeStatusField : Maybe String -> String
    maybeStatusField Nothing  = ""
    maybeStatusField (Just s) = ",\"status\":" ++ show (parseBits64 s)

    maybeMilestoneField : Maybe Bits64 -> String
    maybeMilestoneField Nothing   = ""
    maybeMilestoneField (Just m) = ",\"milestone\":" ++ show m

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
    let body := buildCreateTaskBody project subject story desc stat ms
    resp <- authPost env (env.base ++ "/tasks") body
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
    let body := buildUpdateBody subj desc stat ver
    resp <- authPatch env (env.base ++ "/tasks/" ++ show id.id) body
    expectJson resp 200 "update task"

  ||| Delete a task.
  public export
  deleteTask :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteTask id = do
    let url := env.base ++ "/tasks/" ++ show id.id
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
    let body := buildStatusBody newSt ver
    resp <- authPatch env (env.base ++ "/tasks/" ++ show id.id) body
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
    let url  := env.base ++ "/tasks/" ++ show id.id
        body := buildCommentBody txt ver
    resp <- authPatch env url body
    expectRaw resp 200 "add task comment"
