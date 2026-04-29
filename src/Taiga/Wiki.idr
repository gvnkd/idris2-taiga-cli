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

||| Build a query string from key-value pairs.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

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

  ||| Create a new wiki page.
  public export
  createWiki :
       (project : String)
    -> (slug : String)
    -> (content : String)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  createWiki = ?rhs_createWiki

  ||| Update an existing wiki page (OCC-aware).
  public export
  updateWiki :
       (id : Nat64Id)
    -> (content : Maybe String)
    -> (slug : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String WikiPage)
  updateWiki = ?rhs_updateWiki

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