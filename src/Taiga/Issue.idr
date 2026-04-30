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
                    [ map (\p => ("page", show p)) page
                    , map (\s => ("page_size", show s)) pageSize
                    ]
        url := env.base ++ "/issues" ++ qs
    resp <- authGet env url
    expectJson resp 200 "list issues"

  ||| Get an issue by its ID.
  public export
  getIssue :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Issue)
  getIssue id = do
    let url := env.base ++ "/issues/" ++ show id.id
    resp <- authGet env url
    expectJson resp 200 "get issue"

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
    maybeField "description" desc ++
    maybeField "priority" prio ++
    maybeField "severity" sev ++
    maybeField "issue_type" itype ++ "}"

  where
    maybeField : String -> Maybe String -> String
    maybeField _ Nothing   = ""
    maybeField key (Just v) = ",\"" ++ key ++ "\":" ++ encode v

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
    expectJson resp 201 "create issue"

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
        [ map (\s => "\"subject\":" ++ encode s) subj
        , map (\d => "\"description\":" ++ encode d) desc
        , map (\t => "\"issue_type\":" ++ encode t) itype
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
    expectJson resp 200 "update issue"

  ||| Delete an issue.
  public export
  deleteIssue :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteIssue id = do
    let url := env.base ++ "/issues/" ++ show id.id
    resp <- authDelete env url
    expectOk resp 204 "delete issue"