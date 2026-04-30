||| User and member endpoints.
module Taiga.User

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.User
import Taiga.Api
import Taiga.Env

%language ElabReflection

parameters {auto env : ApiEnv}

  ||| List project members.
  public export
  listUsers :
       (project : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List UserSummary))
  listUsers project = do
    let url := env.base ++ "/users" ++ buildQueryString [("project", project)]
    resp <- authGet env url
    expectJson resp 200 "list users"

  ||| List memberships for a project.
  public export
  listMemberships :
       (project : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List Model.User.Membership))
  listMemberships project = do
    let url := env.base ++ "/memberships" ++ buildQueryString [("project", project)]
    resp <- authGet env url
    expectJson resp 200 "list memberships"

  ||| List roles for a project.
  public export
  listRoles :
       (project : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List Model.User.Role))
  listRoles project = do
    let url := env.base ++ "/roles" ++ buildQueryString [("project", project)]
    resp <- authGet env url
    expectJson resp 200 "list roles"
