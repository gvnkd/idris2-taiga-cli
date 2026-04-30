||| User story endpoints.
module Taiga.UserStory

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.UserStory
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Request body for creating a user story.
public export
record CreateStoryBody where
  constructor MkCreateStoryBody
  project     : Bits64
  subject     : String
  description : Maybe String
  milestone   : Maybe Nat64Id

public export
ToJSON CreateStoryBody where
  toJSON b =
    object $ catMaybes
      [ Just $ jpair "project" b.project
      , Just $ jpair "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "milestone" b.milestone
      ]

||| Request body for updating a user story.
public export
record UpdateStoryBody where
  constructor MkUpdateStoryBody
  subject     : Maybe String
  description : Maybe String
  milestone   : Maybe Bits64
  version     : Version

public export
ToJSON UpdateStoryBody where
  toJSON b =
    object $ catMaybes
      [ omitNothing "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "milestone" b.milestone
      , Just $ jpair "version" b.version
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
   let opts   := concat $ catMaybes
                    [ map (\p => [("page", show p)]) page
                    , map (\s => [("page_size", show s)]) pageSize ]
       params := [("project", project)] ++ opts
    in fetchStoryList (buildUrl ["userstories"] params env.base)

  ||| Get a user story by its ID.
  public export
  getStory :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String UserStory)
  getStory id = do
   let url := buildUrl ["userstories", showId id] [] env.base
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
   let body := encode $ MkCreateStoryBody (parseBits64 project) subject desc mstone
       url  := buildUrl ["userstories"] [] env.base
   resp <- authPost env url body
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
   let body := encode $ MkUpdateStoryBody subj desc (map parseBits64 mstone) ver
       url  := buildUrl ["userstories", showId id] [] env.base
   resp <- authPatch env url body
   expectJson resp 200 "update story"

  ||| Delete a user story.
  public export
  deleteStory :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteStory id = do
   let url := buildUrl ["userstories", showId id] [] env.base
   resp <- authDelete env url
   expectOk resp 204 "delete story"