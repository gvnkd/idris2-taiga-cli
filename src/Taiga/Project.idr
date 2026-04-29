||| Project endpoints.
module Taiga.Project

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Project
import Taiga.Api

%language ElabReflection

||| List visible projects.
listProjects :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (member : Maybe String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List ProjectSummary))
listProjects = ?rhs_listProjects

||| Get a project by its ID.
getProjectById :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Project)
getProjectById = ?rhs_getProjectById

||| Get a project by its slug.
getProjectBySlug :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (slug : Slug)
  -> io (Either String Project)
getProjectBySlug = ?rhs_getProjectBySlug
