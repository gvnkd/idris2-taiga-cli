||| Wiki page endpoints.
module Taiga.Wiki

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.WikiPage
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

parameters {auto env : ApiEnv}

  ||| List wiki pages in a project.
  public export
  listWiki :
       (project : String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List WikiPageSummary))
  listWiki project page pageSize = do
    let qs  := buildQueryString $
                  ("project", project) ::
                  catMaybes
                    [ map (\p => ("page", show p)) page
                    , map (\s => ("page_size", show s)) pageSize
                    ]
        url := env.base ++ "/wiki" ++ qs
    resp <- authGet env url
    expectJson resp 200 "list wiki"

  ||| Get a wiki page by its ID.
  public export
  getWiki :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  getWiki id = do
    let url := env.base ++ "/wiki/" ++ show id.id
    resp <- authGet env url
    expectJson resp 200 "get wiki"

  ||| Build JSON body for creating a wiki page.
  buildCreateWikiBody : String -> String -> String -> String
  buildCreateWikiBody project slug content =
    "{\"project\":" ++ show (parseBits64 project) ++
    ",\"slug\":" ++ encode slug ++
    ",\"content\":" ++ encode content ++ "}"

  ||| Create a new wiki page.
  public export
  createWiki :
       (project : String)
    -> (slug : String)
    -> (content : String)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  createWiki project slug content = do
    let body := buildCreateWikiBody project slug content
    resp <- authPost env (env.base ++ "/wiki") body
    expectJson resp 201 "create wiki"

  ||| Build JSON body for updating a wiki page.
  buildUpdateWikiBody : Maybe String -> Maybe String -> Version -> String
  buildUpdateWikiBody content slug ver =
    "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"
    where
      fields : List String
      fields = catMaybes
        [ map (\c => "\"content\":" ++ encode c) content
        , map (\s => "\"slug\":" ++ encode s) slug
        ]
      joined : String
      joined = concat $ intersperse "," fields

  ||| Update an existing wiki page (OCC-aware).
  public export
  updateWiki :
       (id : Nat64Id)
    -> (content : Maybe String)
    -> (slug : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  updateWiki id content slug ver = do
    let body := buildUpdateWikiBody content slug ver
    resp <- authPatch env (env.base ++ "/wiki/" ++ show id.id) body
    expectJson resp 200 "update wiki"

  ||| Delete a wiki page.
  public export
  deleteWiki :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteWiki id = do
    let url := env.base ++ "/wiki/" ++ show id.id
    resp <- authDelete env url
    expectOk resp 204 "delete wiki"