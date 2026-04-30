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
    let qs := buildQueryString [("project", project), ("text", text)]
        url := env.base ++ "/search" ++ qs
    resp <- authGet env url
    expectRaw resp 200 "search"

  ||| Resolve an entity by its slug or ref.
  public export
  resolve :
       (project : String)
    -> (ref : String)
    -> {auto _ : HasIO io}
    -> io (Either String String)
  resolve project ref = do
    let qs := buildQueryString [("project", project), ("ref", ref)]
        url := env.base ++ "/resolver" ++ qs
    resp <- authGet env url
    expectRaw resp 200 "resolve"
