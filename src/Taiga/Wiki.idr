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
                    [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                    , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                    ]
        url := env.base ++ "/wiki" ++ qs
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right ws  => Right ws
             _     => Left ("list wiki failed with status " ++ show resp.status.code)

  ||| Get a wiki page by its ID.
  public export
  getWiki :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  getWiki id = do
    let url := env.base ++ "/wiki/" ++ show id.id
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right w   => Right w
             _     => Left ("get wiki failed with status " ++ show resp.status.code)

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
    pure $ case resp.status.code of
             201 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right w   => Right w
             _     => Left ("create wiki failed with status " ++ show resp.status.code)

  ||| Build JSON body for updating a wiki page.
  buildUpdateWikiBody : Maybe String -> Maybe String -> Version -> String
  buildUpdateWikiBody content slug ver =
    "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
    where
      fields : List String
      fields = catMaybes
        [ case content of { Nothing => Nothing; Just c => Just (",\"content\":" ++ encode c) }
        , case slug    of { Nothing => Nothing; Just s => Just (",\"slug\":" ++ encode s) }
        ]

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
    resp <- authPut env (env.base ++ "/wiki/" ++ show id.id) body
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right w   => Right w
             _     => Left ("update wiki failed with status " ++ show resp.status.code)

  ||| Delete a wiki page.
  public export
  deleteWiki :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteWiki id = do
    let url := env.base ++ "/wiki/" ++ show id.id
    resp <- authDelete env url
    pure $ case resp.status.code of
             204 => Right ()
             _     => Left ("delete wiki failed with status " ++ show resp.status.code)