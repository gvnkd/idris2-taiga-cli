||| Issue endpoints.
module Taiga.Issue

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Issue
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Request body for creating an issue.
public export
record CreateIssueBody where
  constructor MkCreateIssueBody
  project     : Bits64
  subject     : String
  description : Maybe String
  priority    : Maybe String
  severity    : Maybe String
  issueType   : Maybe String

public export
ToJSON CreateIssueBody where
  toJSON b =
    object $ catMaybes
      [ Just $ jpair "project" b.project
      , Just $ jpair "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "priority" b.priority
      , omitNothing "severity" b.severity
      , omitNothing "issue_type" b.issueType
      ]

||| Request body for updating an issue.
public export
record UpdateIssueBody where
  constructor MkUpdateIssueBody
  subject     : Maybe String
  description : Maybe String
  issueType   : Maybe String
  version     : Version

public export
ToJSON UpdateIssueBody where
  toJSON b =
    object $ catMaybes
      [ omitNothing "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "issue_type" b.issueType
      , Just $ jpair "version" b.version
      ]

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
    let url := env.base ++ "/issues/" ++ showId id
    resp <- authGet env url
    expectJson resp 200 "get issue"

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
    let body := encode $ MkCreateIssueBody (parseBits64 project) subject desc prio sev itype
    resp <- authPost env (env.base ++ "/issues") body
    expectJson resp 201 "create issue"

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
    let body := encode $ MkUpdateIssueBody subj desc itype ver
    resp <- authPatch env (env.base ++ "/issues/" ++ showId id) body
    expectJson resp 200 "update issue"

  ||| Delete an issue.
  public export
  deleteIssue :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteIssue id = do
    let url := env.base ++ "/issues/" ++ showId id
    resp <- authDelete env url
    expectOk resp 204 "delete issue"