||| User story endpoints.
module Taiga.UserStory

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.UserStory
import Taiga.Api

%language ElabReflection

||| List user stories in a project.
listStories :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List UserStorySummary))
listStories = ?rhs_listStories

||| Get a user story by its ID.
getStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String UserStory)
getStory = ?rhs_getStory

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
createStory = ?rhs_createStory

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
updateStory = ?rhs_updateStory

||| Delete a user story.
deleteStory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteStory = ?rhs_deleteStory
