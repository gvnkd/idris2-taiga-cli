||| Project endpoints.
module Taiga.Project

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Project
import Taiga.Api

%language ElabReflection

||| Build a query string from key-value pairs.
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

||| List visible projects.
listProjects :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (member : Maybe String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List ProjectSummary))
listProjects base token member page pageSize = do
  let qs  := buildQueryString $
                catMaybes
                  [ case member of { Nothing => Nothing; Just m => Just ("member", m) }
                  , case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                  , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                  ]
      url := base ++ "/projects" ++ qs
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right ps  => pure $ Right ps
     _     => pure $ Left ("list projects failed with status " ++ show resp.status.code)

||| Get a project by its ID.
getProjectById :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Project)
getProjectById base token id = do
  let url := base ++ "/projects/" ++ show id.id
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right p   => pure $ Right p
     _     => pure $ Left ("get project failed with status " ++ show resp.status.code)

||| Get a project by its slug.
getProjectBySlug :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (slug : Slug)
  -> io (Either String Project)
getProjectBySlug base token slug = do
  let url := base ++ "/projects/" ++ slug.slug
  resp <- httpGet url (Just token)
  case resp.status.code of
     200 => case decodeEither resp.body of
              Left  err  => pure $ Left err
              Right p   => pure $ Right p
     _     => pure $ Left ("get project by slug failed with status " ++ show resp.status.code)