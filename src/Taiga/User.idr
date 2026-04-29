||| User and member endpoints.
module Taiga.User

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.User
import Taiga.Api

%language ElabReflection

||| List project members.
public export
listUsers :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> io (Either String (List UserSummary))
listUsers = ?rhs_listUsers

||| List memberships for a project.
public export
listMemberships :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> io (Either String (List UserSummary))
listMemberships = ?rhs_listMemberships

||| List roles for a project.
public export
listRoles :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> io (Either String (List String))
listRoles = ?rhs_listRoles
