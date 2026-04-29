||| User story endpoints.
module Taiga.UserStory

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.UserStory
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Build a query string from key-value pairs.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

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

parameters {auto env : ApiEnv}

  ||| Fetch and parse a user story list from a URL.
  public export
  fetchStoryList :
       (url : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List UserStorySummary))
  fetchStoryList url = do
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right ss  => Right ss
             _     => Left ("list stories failed with status " ++ show resp.status.code)

  ||| List user stories in a project.
  public export
  listStories :
       (project : String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List UserStorySummary))
  listStories project page pageSize =
    let qs := buildQueryString $
                 ("project", project) ::
                 catMaybes
                   [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                   , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                   ]
     in fetchStoryList (env.base ++ "/userstories" ++ qs)

  ||| Get a user story by its ID.
  public export
  getStory :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String UserStory)
  getStory id = do
    let url := env.base ++ "/userstories/" ++ show id.id
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right s   => Right s
             _     => Left ("get story failed with status " ++ show resp.status.code)

  ||| Create a new user story.
  public export
  createStory :
       (project : String)
    -> (subject : String)
    -> (description : Maybe String)
    -> (milestone : Maybe Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String UserStory)
  createStory project subject desc mstone = do
    let body := buildCreateStoryBody project subject desc mstone
    resp <- authPost env (env.base ++ "/userstories") body
    pure $ case resp.status.code of
             201 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right s   => Right s
             _     => Left ("create story failed with status " ++ show resp.status.code)

  ||| Update an existing user story (OCC-aware).
  public export
  updateStory :
       (id : Nat64Id)
    -> (subject : Maybe String)
    -> (description : Maybe String)
    -> (milestone : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String UserStory)
  updateStory id subj desc mstone ver = do
    let body := buildUpdateStoryBody subj desc mstone ver
    resp <- authPut env (env.base ++ "/userstories/" ++ show id.id) body
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right s   => Right s
             _     => Left ("update story failed with status " ++ show resp.status.code)

  ||| Delete a user story.
  public export
  deleteStory :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteStory id = do
    let url := env.base ++ "/userstories/" ++ show id.id
    resp <- authDelete env url
    pure $ case resp.status.code of
             204 => Right ()
             _     => Left ("delete story failed with status " ++ show resp.status.code)