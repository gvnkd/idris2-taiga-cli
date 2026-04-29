||| Epic endpoints and related user stories.
module Taiga.Epic

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Epic
import Taiga.Api

%language ElabReflection

||| Build a query string from key-value pairs.
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| List epics in a project.
listEpics :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List EpicSummary))
listEpics base token project page pageSize = do
  let qs  := buildQueryString $
                "project" : project ::
                catMaybes
                  [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                  , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                  ]
      url := base ++ "/epics" ++ qs
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right es  => pure $ Right es
     _     => pure $ Left ("list epics failed with status " ++ show resp.status.code)

||| Get an epic by its ID.
getEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Epic)
getEpic base token id = do
  let url := base ++ "/epics/" ++ show id.id
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right e   => pure $ Right e
     _     => pure $ Left ("get epic failed with status " ++ show resp.status.code)

||| Create a new epic.
createEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> io (Either String Epic)
createEpic base token project subject desc stat = do
  let body := "{\"project\":" ++ show (cast (pack project) : Either String Bits64) ++
                    ",\"subject\":" ++ encode subject ++
                    case desc of
                      Nothing  => ""
                      Just d   => ",\"description\":" ++ encode d
                    ++
                    case stat of
                      Nothing  => ""
                      Just s   => ",\"status\":" ++ show (cast s : Either String Bits64)
                    ++ "}"
  resp <- httpPost (base ++ "/epics") (Just token) body
  case resp.status.code of
     201 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right e   => pure $ Right e
     _     => pure $ Left ("create epic failed with status " ++ show resp.status.code)

||| Update an existing epic (OCC-aware).
updateEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (subject : Maybe String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> (version : Version)
  -> io (Either String Epic)
updateEpic base token id subj desc stat ver = do
  let fields := catMaybes
                  [ case subj of { Nothing => Nothing; Just s => Just (",\"subject\":" ++ encode s) }
                  , case desc of { Nothing => Nothing; Just d => Just (",\"description\":" ++ encode d) }
                  , case stat of { Nothing => Nothing; Just s => Just (",\"status\":" ++ show (cast s : Either String Bits64)) }
                  ]
      body  := "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
  resp <- httpPut (base ++ "/epics/" ++ show id.id) (Just token) body
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right e   => pure $ Right e
     _     => pure $ Left ("update epic failed with status " ++ show resp.status.code)

||| Delete an epic.
deleteEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteEpic base token id = do
  let url := base ++ "/epics/" ++ show id.id
  resp <- httpDelete url (Just token)
  case resp.status.code of
     204 => pure $ Right ()
     _     => pure $ Left ("delete epic failed with status " ++ show resp.status.code)