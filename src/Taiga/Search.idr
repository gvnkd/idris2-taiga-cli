||| Resolver and search endpoints.
module Taiga.Search

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Taiga.Api
import Taiga.Env

%language ElabReflection

parameters {auto env : ApiEnv}

  ||| Global search within a project.
  public export
  search :
       (project : String)
    -> (text : String)
    -> {auto _ : HasIO io}
    -> io (Either String String)
  search project text = do
    let url := env.base ++ "/search?project=" ++ project ++ "&text=" ++ text
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => Right resp.body
             _     => Left ("search failed with status " ++ show resp.status.code)

  ||| Resolve an entity by its slug or ref.
  public export
  resolve :
       (project : String)
    -> (ref : String)
    -> {auto _ : HasIO io}
    -> io (Either String String)
  resolve project ref = do
    let url := env.base ++ "/resolver?project=" ++ project ++ "&ref=" ++ ref
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => Right resp.body
             _     => Left ("resolve failed with status " ++ show resp.status.code)