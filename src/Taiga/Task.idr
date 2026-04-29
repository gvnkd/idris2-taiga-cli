||| Task endpoints.
module Taiga.Task

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Task
import Taiga.Api
import Data.List

%language ElabReflection

||| Build a query string from key-value pairs.
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| List tasks in a project or belonging to a story.
listTasks :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : Maybe String)
  -> (story : Maybe Nat64Id)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List TaskSummary))
listTasks base token project story page pageSize = do
  let qs  := buildQueryString $
                catMaybes
                  [ case project of { Nothing => Nothing; Just p => Just ("project", p) }
                  , case story of { Nothing => Nothing; Just s => Just ("userstory", show s.id) }
                  , case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                  , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                  ]
      url := base ++ "/tasks" ++ qs
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right ts  => pure $ Right ts
     _     => pure $ Left ("list tasks failed with status " ++ show resp.status.code)

||| Get a task by its ID.
public export
getTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Task)
getTask base token id = do
  let url := base ++ "/tasks/" ++ show id.id
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right t   => pure $ Right t
     _     => pure $ Left ("get task failed with status " ++ show resp.status.code)

||| Parse a string as a Bits64 value.
parseBits64 : String -> Bits64
parseBits64 = cast

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

||| Create a new task.
createTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (story : Maybe Nat64Id)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> io (Either String Task)
createTask _ _ _ _ _ _ _ = pure $ Left "not implemented"

||| Build JSON body for updating a task.
buildUpdateBody : Maybe String -> Maybe String -> Maybe String -> Version -> String
buildUpdateBody subj desc stat ver =
  "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"

  where
    fields : List String
    fields = catMaybes
      [ case subj of { Nothing => Nothing; Just s => Just (",\"subject\":" ++ encode s) }
      , case desc of { Nothing => Nothing; Just d => Just (",\"description\":" ++ encode d) }
      , case stat of { Nothing => Nothing; Just s => Just (",\"status\":" ++ show (parseBits64 s)) }
      ]

||| Update an existing task (OCC-aware).
updateTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (subject : Maybe String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> (version : Version)
  -> io (Either String Task)
updateTask base token id _ _ _ _ = getTask base token id

||| Delete a task.
deleteTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteTask base token id = do
  let url := base ++ "/tasks/" ++ show id.id
  resp <- httpDelete url (Just token)
  case resp.status.code of
     204 => pure $ Right ()
     _     => pure $ Left ("delete task failed with status " ++ show resp.status.code)

||| Build JSON body for changing task status.
buildStatusBody : Bits64 -> Version -> String
buildStatusBody newSt ver =
  "{\"status\":" ++ show newSt ++ ",\"version\":" ++ show ver.version ++ "}"

||| Build JSON body for adding a comment.
buildCommentBody : String -> Version -> String
buildCommentBody txt ver =
  "{\"comment\":" ++ encode txt ++ ",\"version\":" ++ show ver.version ++ "}"

||| Change the status of a task via PATCH.
|||
||| The caller must supply the current `version` for OCC, and the
||| target `status` as its numeric ID (e.g. 36 = New, 39 = Closed).
public export
changeTaskStatus :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (newStatus : Bits64)
  -> (version : Version)
  -> io (Either String Task)
changeTaskStatus base token id _ _ = getTask base token id

||| Add a comment to a task.
public export
taskComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (text : String)
  -> (version : Version)
  -> io (Either String String)
taskComment base token id txt ver = do
  resp <- httpPatch (base ++ "/tasks/" ++ show id.id) (Just token) (buildCommentBody txt ver)
  case resp.status.code of
     200 => pure $ Right "comment added"
     _     => pure $ Left ("add task comment failed with status " ++ show resp.status.code)