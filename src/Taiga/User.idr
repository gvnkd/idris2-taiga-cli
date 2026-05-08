module Taiga.User
import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.User
import Taiga.Api
import Taiga.Env

%language ElabReflection

parameters {auto env : ApiEnv}
  public export
  listUsers : (project : String) -> {auto _ : HasIO io} -> io (Either String (List UserSummary))
  listUsers project = do
    let url : _ = buildUrl ["users"] [("project", project)] env.base
    resp <- authGet env url
    expectJson resp 200 "list users"
  public export
  listMemberships : (project : String) -> {auto _ : HasIO io} -> io (Either String (List Model.User.Membership))
  listMemberships project = do
    let url : _ = buildUrl ["memberships"] [("project", project)] env.base
    resp <- authGet env url
    expectJson resp 200 "list memberships"
  public export
  listRoles : (project : String) -> {auto _ : HasIO io} -> io (Either String (List Model.User.Role))
  listRoles project = do
    let url : _ = buildUrl ["roles"] [("project", project)] env.base
    resp <- authGet env url
    expectJson resp 200 "list roles"
