||| Task endpoints.
module Taiga.Task

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Task
import Taiga.Api

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
createTask base token project subject story desc stat = do
  let body := "{\"project\":" ++ show (cast (pack project) : Either String Bits64) ++
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
                      Just s   => ",\"status\":" ++ show (cast s : Either String Bits64)
                    ++ "}"
  resp <- httpPost (base ++ "/tasks") (Just token) body
  case resp.status.code of
     201 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right t   => pure $ Right t
     _     => pure $ Left ("create task failed with status " ++ show resp.status.code)

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
updateTask base token id subj desc stat ver = do
  let fields := catMaybes
                  [ case subj of { Nothing => Nothing; Just s => Just (",\"subject\":" ++ encode s) }
                  , case desc of { Nothing => Nothing; Just d => Just (",\"description\":" ++ encode d) }
                  , case stat of { Nothing => Nothing; Just s => Just (",\"status\":" ++ show (cast s : Either String Bits64)) }
                  ]
      body  := "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
  resp <- httpPut (base ++ "/tasks/" ++ show id.id) (Just token) body
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right t   => pure $ Right t
     _     => pure $ Left ("update task failed with status " ++ show resp.status.code)

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