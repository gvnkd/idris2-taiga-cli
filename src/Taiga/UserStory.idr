||| User story endpoints.
module Taiga.UserStory

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.UserStory
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

public export
fetchStoryList :
     HasIO io
  => (url : String)
  -> (token : String)
  -> io (Either String (List UserStorySummary))
fetchStoryList url token = do
  resp <- httpGet url (Just token)
  pure $ case resp.status.code of
           200 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right ss  => Right ss
           _     => Left ("list stories failed with status " ++ show resp.status.code)

||| List user stories in a project.
public export
listStories :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List UserStorySummary))
listStories base token project page pageSize =
  let qs := buildQueryString $
               ("project", project) ::
               catMaybes
                 [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                 , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                 ]
   in fetchStoryList (base ++ "/userstories" ++ qs) token

||| Get a user story by its ID.
public export
getStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String UserStory)
getStory base token id = do
  let url := base ++ "/userstories/" ++ show id.id
  resp <- httpGet url (Just token)
  pure $ case resp.status.code of
           200 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right s   => Right s
           _     => Left ("get story failed with status " ++ show resp.status.code)

||| Parse string as Bits64 for JSON project field.
public export
parseProjectBits : String -> Bits64
parseProjectBits = cast

public export
formatStoryDesc : Maybe String -> String
formatStoryDesc Nothing  = ""
formatStoryDesc (Just d) = ",\"description\":" ++ encode d

public export
formatStoryMilestone : Maybe Nat64Id -> String
formatStoryMilestone Nothing  = ""
formatStoryMilestone (Just m) = ",\"milestone\":" ++ show m.id

||| Build JSON body for creating a user story.
public export
buildCreateStoryBody :
     (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (milestone : Maybe Nat64Id)
  -> String
buildCreateStoryBody project subject desc mstone =
  "{\"project\":" ++ show (parseProjectBits project) ++
  ",\"subject\":" ++ encode subject ++
  formatStoryDesc desc ++
  formatStoryMilestone mstone ++ "}"

public export
postStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (body : String)
  -> io (Either String UserStory)
postStory base token body = do
  resp <- httpPost (base ++ "/userstories") (Just token) body
  pure $ case resp.status.code of
           201 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right s   => Right s
           _     => Left ("create story failed with status " ++ show resp.status.code)

||| Create a new user story.
public export
createStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (milestone : Maybe Nat64Id)
  -> io (Either String UserStory)
createStory base token project subject desc mstone =
  postStory base token (buildCreateStoryBody project subject desc mstone)

||| Build JSON body for updating a user story.
public export
buildUpdateStoryBody :
     (subject : Maybe String)
  -> (description : Maybe String)
  -> (milestone : Maybe String)
  -> (version : Version)
  -> String
buildUpdateStoryBody subj desc mstone ver =
  "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
  where
    fields : List String
    fields = catMaybes
      [ case subj of { Nothing => Nothing; Just s => Just (",\"subject\":" ++ encode s) }
      , case desc of { Nothing => Nothing; Just d => Just (",\"description\":" ++ encode d) }
      , case mstone of { Nothing => Nothing; Just m => Just (",\"milestone\":" ++ show (parseProjectBits m)) }
      ]

public export
putStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (body : String)
  -> io (Either String UserStory)
putStory base token id body = do
  resp <- httpPut (base ++ "/userstories/" ++ show id.id) (Just token) body
  pure $ case resp.status.code of
           200 => case decodeEither resp.body of
                    Left  err  => Left err
                    Right s   => Right s
           _     => Left ("update story failed with status " ++ show resp.status.code)

||| Update an existing user story (OCC-aware).
public export
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
updateStory base token id subj desc mstone ver =
  putStory base token id (buildUpdateStoryBody subj desc mstone ver)

||| Delete a user story.
public export
deleteStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteStory base token id = do
  let url := base ++ "/userstories/" ++ show id.id
  resp <- httpDelete url (Just token)
  pure $ case resp.status.code of
           204 => Right ()
           _     => Left ("delete story failed with status " ++ show resp.status.code)
