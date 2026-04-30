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

||| Format a description field for JSON.
public export
formatStoryDesc : Maybe String -> String
formatStoryDesc Nothing  = ""
formatStoryDesc (Just d) = ",\"description\":" ++ encode d

||| Format a milestone field for JSON.
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
  "{\"project\":" ++ show (parseBits64 project) ++
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
  "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"
  where
    fields : List String
    fields = catMaybes
      [ map (\s => "\"subject\":" ++ encode s) subj
      , map (\d => "\"description\":" ++ encode d) desc
      , map (\m => "\"milestone\":" ++ show (parseBits64 m)) mstone
      ]
    joined : String
    joined = concat $ intersperse "," fields

parameters {auto env : ApiEnv}

  ||| Fetch and parse a user story list from a URL.
  public export
  fetchStoryList :
       (url : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List UserStorySummary))
  fetchStoryList url = do
    resp <- authGet env url
    expectJson resp 200 "list stories"

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
                    [ map (\p => ("page", show p)) page
                    , map (\s => ("page_size", show s)) pageSize
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
    expectJson resp 200 "get story"

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
    expectJson resp 201 "create story"

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
    resp <- authPatch env (env.base ++ "/userstories/" ++ show id.id) body
    expectJson resp 200 "update story"

  ||| Delete a user story.
  public export
  deleteStory :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteStory id = do
    let url := env.base ++ "/userstories/" ++ show id.id
    resp <- authDelete env url
    expectOk resp 204 "delete story"