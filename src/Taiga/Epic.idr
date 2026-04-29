||| Epic endpoints and related user stories.
module Taiga.Epic

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Epic
import Taiga.Api
import Data.List

%language ElabReflection

||| Build a query string from key-value pairs.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| List epics in a project.
public export
listEpics :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List EpicSummary))
public export
fetchEpicList :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (url : String)
  -> io (Either String (List EpicSummary))
fetchEpicList base token url = do
  resp <- httpGet url (Just token)
  pure $ case resp.status.code of
           200 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right es  => Right es
           _     => Left ("list epics failed with status " ++ show resp.status.code)

listEpics base token project page pageSize =
  let qs := buildQueryString $
               ("project", project) ::
               catMaybes
                 [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                 , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                 ]
    in fetchEpicList base token (base ++ "/epics" ++ qs)

||| Get an epic by its ID.
public export
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

||| Format a description field for JSON.
public export
formatEpicDesc : Maybe String -> String
formatEpicDesc Nothing  = ""
formatEpicDesc (Just d) = ",\"description\":" ++ encode d

||| Parse string as Bits64 for JSON status field.
public export
parseStatusBits : String -> Bits64
parseStatusBits = cast

||| Format a status field for JSON.
public export
formatEpicStatus : Maybe String -> String
formatEpicStatus Nothing  = ""
formatEpicStatus (Just s) = ",\"status\":" ++ show (parseStatusBits s)

||| Build JSON body for creating an epic.
public export
buildCreateEpicBody :
     (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> String
buildCreateEpicBody project subject desc stat =
  "{\"project\":" ++ show (parseStatusBits project) ++
  ",\"subject\":" ++ encode subject ++
  formatEpicDesc desc ++
  formatEpicStatus stat ++ "}"

public export
postEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (body : String)
  -> io (Either String Epic)
postEpic base token body = do
  resp <- httpPost (base ++ "/epics") (Just token) body
  pure $ case resp.status.code of
           201 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right e   => Right e
           _     => Left ("create epic failed with status " ++ show resp.status.code)

||| Create a new epic.
public export
createEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> io (Either String Epic)
createEpic base token project subject desc stat =
  postEpic base token (buildCreateEpicBody project subject desc stat)

||| Build JSON body for updating an epic.
public export
buildUpdateEpicBody :
     (subject : Maybe String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> (version : Version)
  -> String
buildUpdateEpicBody subj desc stat ver =
  "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
  where
    fields : List String
    fields = catMaybes
      [ case subj of { Nothing => Nothing; Just s => Just (",\"subject\":" ++ encode s) }
      , case desc of { Nothing => Nothing; Just d => Just (",\"description\":" ++ encode d) }
      , case stat of { Nothing => Nothing; Just s => Just (",\"status\":" ++ show (parseStatusBits s)) }
      ]

public export
putEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (body : String)
  -> io (Either String Epic)
putEpic base token id body = do
  resp <- httpPut (base ++ "/epics/" ++ show id.id) (Just token) body
  pure $ case resp.status.code of
           200 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right e   => Right e
           _     => Left ("update epic failed with status " ++ show resp.status.code)

||| Update an existing epic (OCC-aware).
public export
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
updateEpic base token id subj desc stat ver =
  putEpic base token id (buildUpdateEpicBody subj desc stat ver)

||| Delete an epic.
public export
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