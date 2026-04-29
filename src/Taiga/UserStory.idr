||| User story endpoints.
module Taiga.UserStory

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.UserStory
import Taiga.Api

%language ElabReflection

||| Build a query string from key-value pairs.
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| List user stories in a project.
listStories :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List UserStorySummary))
listStories base token project page pageSize = do
  let qs  := buildQueryString $
                "project" : project ::
                catMaybes
                  [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                  , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                  ]
      url := base ++ "/userstories" ++ qs
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right ss  => pure $ Right ss
     _     => pure $ Left ("list stories failed with status " ++ show resp.status.code)

||| Get a user story by its ID.
getStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String UserStory)
getStory base token id = do
  let url := base ++ "/userstories/" ++ show id.id
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right s   => pure $ Right s
     _     => pure $ Left ("get story failed with status " ++ show resp.status.code)

||| Create a new user story.
createStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (milestone : Maybe Nat64Id)
  -> io (Either String UserStory)
createStory base token project subject desc mstone = do
  let body := "{\"project\":" ++ show (cast (pack project) : Either String Bits64) ++
                    ",\"subject\":" ++ encode subject ++
                    case desc of
                      Nothing  => ""
                      Just d   => ",\"description\":" ++ encode d
                    ++
                    case mstone of
                      Nothing  => ""
                      Just m   => ",\"milestone\":" ++ show m.id
                    ++ "}"
  resp <- httpPost (base ++ "/userstories") (Just token) body
  case resp.status.code of
     201 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right s   => pure $ Right s
     _     => pure $ Left ("create story failed with status " ++ show resp.status.code)

||| Update an existing user story (OCC-aware).
updateStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (subject : Maybe String)
  -> (description : Maybe String)
  -> (milestone : Maybe String)
  -> (version : Version)
  -> io (Either String UserStory)
updateStory base token id subj desc mstone ver = do
  let fields := catMaybes
                  [ case subj of { Nothing => Nothing; Just s => Just (",\"subject\":" ++ encode s) }
                  , case desc of { Nothing => Nothing; Just d => Just (",\"description\":" ++ encode d) }
                  , case mstone of { Nothing => Nothing; Just m => Just (",\"milestone\":" ++ show (cast m : Either String Bits64)) }
                  ]
      body  := "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
  resp <- httpPut (base ++ "/userstories/" ++ show id.id) (Just token) body
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right s   => pure $ Right s
     _     => pure $ Left ("update story failed with status " ++ show resp.status.code)

||| Delete a user story.
deleteStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteStory base token id = do
  let url := base ++ "/userstories/" ++ show id.id
  resp <- httpDelete url (Just token)
  case resp.status.code of
     204 => pure $ Right ()
     _     => pure $ Left ("delete story failed with status " ++ show resp.status.code)