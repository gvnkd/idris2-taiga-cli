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
    let url := env.base ++ "/users?project=" ++ project
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right us  => Right us
             _     => Left ("list users failed with status " ++ show resp.status.code)

  ||| List memberships for a project.
  public export
  listMemberships :
       (project : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List UserSummary))
  listMemberships project = do
    let url := env.base ++ "/memberships?project=" ++ project
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right ms  => Right ms
             _     => Left ("list memberships failed with status " ++ show resp.status.code)

  ||| List roles for a project.
  public export
  listRoles :
       (project : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List String))
  listRoles project = do
    let url := env.base ++ "/roles?project=" ++ project
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right rs  => Right rs
             _     => Left ("list roles failed with status " ++ show resp.status.code)