||| Project endpoints.
module Taiga.Project

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Project
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

parameters {auto env : ApiEnv}

  ||| List visible projects.
  public export
  listProjects :
       (member : Maybe String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List ProjectSummary))
  listProjects member page pageSize = do
   let params := concat $ catMaybes
                     [ map (\m => [("member", m)]) member
                     , map (\p => [("page", show p)]) page
                     , map (\s => [("page_size", show s)]) pageSize ]
       url  := buildUrl ["projects"] params env.base
   resp <- authGet env url
   expectJson resp 200 "list projects"

  ||| Get a project by its ID.
  public export
  getProjectById :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Project)
  getProjectById id = do
   let url := buildUrl ["projects", showId id] [] env.base
   resp <- authGet env url
   expectJson resp 200 "get project"

  ||| Get a project by its slug.
  public export
  getProjectBySlug :
       (slug : Slug)
    -> {auto _ : HasIO io}
    -> io (Either String Project)
  getProjectBySlug slug = do
   let url := buildUrl ["projects", slug.slug] [] env.base
   resp <- authGet env url
   expectJson resp 200 "get project by slug"