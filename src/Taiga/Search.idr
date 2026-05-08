module Taiga.Search
import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Taiga.Api
import Taiga.Env

%language ElabReflection

parameters {auto env : ApiEnv}
  public export
  search : (project : String) -> (text : String) -> {auto _ : HasIO io} -> io (Either String String)
  search project text = do
    let params : _ = [("project", project), ("text", text)]
    let url : _ = buildUrl ["search"] params env.base
    resp <- authGet env url
    expectRaw resp 200 "search"
  public export
  resolve : (project : String) -> (ref : String) -> {auto _ : HasIO io} -> io (Either String String)
  resolve project ref = do
    let params : _ = [("project", project), ("ref", ref)]
    let url : _ = buildUrl ["resolver"] params env.base
    resp <- authGet env url
    expectRaw resp 200 "resolve"
