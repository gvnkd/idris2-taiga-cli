||| Epic endpoints and related user stories.
module Taiga.Epic

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Epic
import Taiga.Api

%language ElabReflection

||| List epics in a project.
listEpics :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List EpicSummary))
listEpics = ?rhs_listEpics

||| Get an epic by its ID.
getEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Epic)
getEpic = ?rhs_getEpic

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
createEpic = ?rhs_createEpic

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
updateEpic = ?rhs_updateEpic

||| Delete an epic.
deleteEpic :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteEpic = ?rhs_deleteEpic
