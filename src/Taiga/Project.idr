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

||| Build a query string from key-value pairs.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

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
    let qs  := buildQueryString $
                  catMaybes
                    [ case member of { Nothing => Nothing; Just m => Just ("member", m) }
                    , case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                    , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                    ]
        url := env.base ++ "/projects" ++ qs
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right ps  => Right ps
             _     => Left ("list projects failed with status " ++ show resp.status.code)

  ||| Get a project by its ID.
  public export
  getProjectById :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Project)
  getProjectById id = do
    let url := env.base ++ "/projects/" ++ show id.id
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right p   => Right p
             _     => Left ("get project failed with status " ++ show resp.status.code)

  ||| Get a project by its slug.
  public export
  getProjectBySlug :
       (slug : Slug)
    -> {auto _ : HasIO io}
    -> io (Either String Project)
  getProjectBySlug slug = do
    let url := env.base ++ "/projects/" ++ slug.slug
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right p   => Right p
             _     => Left ("get project by slug failed with status " ++ show resp.status.code)