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
  case story of
    Nothing  => ""
    Just s   => ",\"userstory\":" ++ show s.id
  ++
  case desc of
    Nothing  => ""
    Just d   => ",\"description\":" ++ encode d
  ++
  case stat of
    Nothing  => ""
    Just s   => ",\"status\":" ++ show (parseBits64 s)
  ++ "}"

||| Build JSON body for updating a task.
buildUpdateBody : Maybe String -> Maybe String -> Maybe String -> Version -> String
buildUpdateBody subj desc stat ver =
  "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"

  where
    fields : List String
    fields = catMaybes
      [ case subj of { Nothing => Nothing; Just s => Just ("\"subject\":" ++ encode s) }
      , case desc of { Nothing => Nothing; Just d => Just ("\"description\":" ++ encode d) }
      , case stat of { Nothing => Nothing; Just s => Just ("\"status\":" ++ show (parseBits64 s)) }
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
                    [ case project of { Nothing => Nothing; Just p => Just ("project", p) }
                    , case story of { Nothing => Nothing; Just s => Just ("userstory", show s.id) }
                    , case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                    , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                    ]
        url := env.base ++ "/tasks" ++ qs
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right ts  => Right ts
             _     => Left ("list tasks failed with status " ++ show resp.status.code)

  ||| Get a task by its ID.
  public export
  getTask :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Task)
  getTask id = do
    let url := env.base ++ "/tasks/" ++ show id.id
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right t   => Right t
             _     => Left ("get task failed with status " ++ show resp.status.code)

  ||| Build JSON body for creating a task.
  buildCreateTaskBody :
       String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Maybe Bits64 -> String
  buildCreateTaskBody project subject story desc stat ms =
    "{\"project\":" ++ show (parseBits64 project) ++
    ",\"subject\":" ++ encode subject ++
    case story of { Nothing => ""; Just s => ",\"userstory\":" ++ show s.id } ++
    case desc of  { Nothing => ""; Just d => ",\"description\":" ++ encode d } ++
    case stat of  { Nothing => ""; Just s => ",\"status\":" ++ show (parseBits64 s) } ++
    case ms of    { Nothing => ""; Just m => ",\"milestone\":" ++ show m } ++
    "}"

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
    pure $ case resp.status.code of
             201 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right t   => Right t
             _     => Left ("create task failed with status " ++ show resp.status.code)

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
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right t   => Right t
             _     => Left ("update task failed with status " ++ show resp.status.code)

  ||| Delete a task.
  public export
  deleteTask :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteTask id = do
    let url := env.base ++ "/tasks/" ++ show id.id
    resp <- authDelete env url
    pure $ case resp.status.code of
             204 => Right ()
             _     => Left ("delete task failed with status " ++ show resp.status.code)

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
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right t   => Right t
             _     => Left ("change task status failed with status " ++ show resp.status.code)

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
    pure $ case resp.status.code of
             200 => Right "comment added"
             _     => Left ("add task comment failed with status " ++ show resp.status.code)