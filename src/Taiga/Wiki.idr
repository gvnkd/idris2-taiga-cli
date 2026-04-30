||| Wiki page endpoints.
module Taiga.Wiki

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.WikiPage
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Request body for creating a wiki page.
public export
record CreateWikiBody where
  constructor MkCreateWikiBody
  project : Bits64
  slug    : String
  content : String

public export
ToJSON CreateWikiBody where
  toJSON b =
    object
      [ jpair "project" b.project
      , jpair "slug" b.slug
      , jpair "content" b.content
      ]

||| Request body for updating a wiki page.
public export
record UpdateWikiBody where
  constructor MkUpdateWikiBody
  content : Maybe String
  slug    : Maybe String
  version : Version

public export
ToJSON UpdateWikiBody where
  toJSON b =
    object $ catMaybes
      [ omitNothing "content" b.content
      , omitNothing "slug" b.slug
      , Just $ jpair "version" b.version
      ]

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

  ||| Create a new wiki page.
  public export
  createWiki :
       (project : String)
    -> (slug : String)
    -> (content : String)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  createWiki project slug content = do
    let body := encode $ MkCreateWikiBody (parseBits64 project) slug content
    resp <- authPost env (env.base ++ "/wiki") body
    expectJson resp 201 "create wiki"

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
    let body := encode $ MkUpdateWikiBody content slug ver
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