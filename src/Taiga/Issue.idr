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

public export
record CreateIssueBody where
  constructor MkCreateIssueBody
  project : Bits64
  subject : String
  description : Maybe String
  priority : Maybe String
  severity : Maybe String
  issueType : Maybe String

public export
implementation ToJSON CreateIssueBody where
  toJSON b =
    object $ catMaybes [Just $ jpair "project" b.project, Just $ jpair "subject" b.subject, omitNothing "description" b.description, omitNothing "priority" b.priority, omitNothing "severity" b.severity, omitNothing "issue_type" b.issueType]

public export
record UpdateIssueBody where
  constructor MkUpdateIssueBody
  subject : Maybe String
  description : Maybe String
  issueType : Maybe String
  status : Maybe Bits64
  version : Version

public export
implementation ToJSON UpdateIssueBody where
  toJSON b =
    object $ catMaybes [omitNothing "subject" b.subject, omitNothing "description" b.description, omitNothing "issue_type" b.issueType, omitNothing "status" b.status, Just $ jpair "version" b.version]

parameters {auto env : ApiEnv}
  public export
  listIssues : (project : Maybe String) -> (page : Maybe Bits32) -> (pageSize : Maybe Bits32) -> {auto _ : HasIO io} -> io (Either String (List IssueSummary, PaginationMeta))
  listIssues mproject page pageSize = do
    let opts : _ = concat $ catMaybes [map (\p => [("page", show p)]) page, map (\s => [("page_size", show s)]) pageSize, map (\p => [("project__id", p)]) mproject]
    let url : _ = buildUrl ["issues"] opts env.base
    resp <- authGet env url
    expectJsonWithMeta resp 200 "list issues"
  public export
  getIssue : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String Issue)
  getIssue id = do
    let errMsg : _ = "issue #" ++ showId id
    let url : _ = buildUrl ["issues", showId id] [] env.base
    resp <- authGet env url
    expectJson resp 200 errMsg
  public export
  createIssue : (project : String) -> (subject : String) -> (description : Maybe String) -> (priority : Maybe String) -> (severity : Maybe String) -> (issueType : Maybe String) -> {auto _ : HasIO io} -> io (Either String Issue)
  createIssue project subject desc prio sev itype = do
    let body : _ = encode $ MkCreateIssueBody (parseBits64 project) subject desc prio sev itype
    let url : _ = buildUrl ["issues"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create issue"
  public export
  updateIssue : (id : Nat64Id) -> (subject : Maybe String) -> (description : Maybe String) -> (issueType : Maybe String) -> (status : Maybe String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String Issue)
  updateIssue id subj desc itype stat ver = do
    let errMsg : _ = "issue #" ++ showId id
    let body : _ = encode $ MkUpdateIssueBody subj desc itype (map parseBits64 stat) ver
    let url : _ = buildUrl ["issues", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  deleteIssue : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String ())
  deleteIssue id = do
    let errMsg : _ = "issue #" ++ showId id
    let url : _ = buildUrl ["issues", showId id] [] env.base
    resp <- authDelete env url
    expectOk resp 204 errMsg
