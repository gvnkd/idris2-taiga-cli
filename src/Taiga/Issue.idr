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

  ||| Build JSON body for creating an issue.
  buildCreateIssueBody :
       (project : String)
    -> (subject : String)
    -> (description : Maybe String)
    -> (priority : Maybe String)
    -> (severity : Maybe String)
    -> (issueType : Maybe String)
    -> String
  buildCreateIssueBody project subject desc prio sev itype =
    "{\"project\":" ++ show (parseBits64 project) ++
    ",\"subject\":" ++ encode subject ++
    case desc of { Nothing => ""; Just d => ",\"description\":" ++ encode d } ++
    case prio of { Nothing => ""; Just p => ",\"priority\":" ++ encode p } ++
    case sev of  { Nothing => ""; Just s => ",\"severity\":" ++ encode s } ++
    case itype of { Nothing => ""; Just t => ",\"issue_type\":" ++ encode t } ++
    "}"

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
  createIssue project subject desc prio sev itype = do
    let body := buildCreateIssueBody project subject desc prio sev itype
    resp <- authPost env (env.base ++ "/issues") body
    pure $ case resp.status.code of
             201 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right i   => Right i
             _     => Left ("create issue failed with status " ++ show resp.status.code)

  ||| Build JSON body for updating an issue.
  buildUpdateIssueBody :
       (subject : Maybe String)
    -> (description : Maybe String)
    -> (issueType : Maybe String)
    -> (version : Version)
    -> String
  buildUpdateIssueBody subj desc itype ver =
    "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"
    where
      fields : List String
      fields = catMaybes
        [ case subj  of { Nothing => Nothing; Just s => Just ("\"subject\":" ++ encode s) }
        , case desc  of { Nothing => Nothing; Just d => Just ("\"description\":" ++ encode d) }
        , case itype of { Nothing => Nothing; Just t => Just ("\"issue_type\":" ++ encode t) }
        ]
      joined : String
      joined = concat $ intersperse "," fields

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
  updateIssue id subj desc itype ver = do
    let body := buildUpdateIssueBody subj desc itype ver
    resp <- authPatch env (env.base ++ "/issues/" ++ show id.id) body
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right i   => Right i
             _     => Left ("update issue failed with status " ++ show resp.status.code)

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