||| Issue endpoints.
module Taiga.Issue

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Issue
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

  ||| List issues in a project.
  public export
  listIssues :
       (project : String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List IssueSummary))
  listIssues project page pageSize = do
    let qs  := buildQueryString $
                  ("project", project) ::
                  catMaybes
                    [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                    , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                    ]
        url := env.base ++ "/issues" ++ qs
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right is  => Right is
             _     => Left ("list issues failed with status " ++ show resp.status.code)

  ||| Get an issue by its ID.
  public export
  getIssue :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Issue)
  getIssue id = do
    let url := env.base ++ "/issues/" ++ show id.id
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right i   => Right i
             _     => Left ("get issue failed with status " ++ show resp.status.code)

  ||| Create a new issue.
  public export
  createIssue :
       (project : String)
    -> (subject : String)
    -> (description : Maybe String)
    -> (priority : Maybe String)
    -> (severity : Maybe String)
    -> (issueType : Maybe String)
    -> {auto _ : HasIO io}
    -> io (Either String Issue)
  createIssue = ?rhs_createIssue

  ||| Update an existing issue (OCC-aware).
  public export
  updateIssue :
       (id : Nat64Id)
    -> (subject : Maybe String)
    -> (description : Maybe String)
    -> (issueType : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String Issue)
  updateIssue = ?rhs_updateIssue

  ||| Delete an issue.
  public export
  deleteIssue :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteIssue id = do
    let url := env.base ++ "/issues/" ++ show id.id
    resp <- authDelete env url
    pure $ case resp.status.code of
             204 => Right ()
             _     => Left ("delete issue failed with status " ++ show resp.status.code)