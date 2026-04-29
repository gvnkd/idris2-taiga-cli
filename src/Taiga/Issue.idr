||| Issue endpoints.
module Taiga.Issue

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Issue
import Taiga.Api

%language ElabReflection

||| List issues in a project.
listIssues :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List IssueSummary))
listIssues = ?rhs_listIssues

||| Get an issue by its ID.
getIssue :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Issue)
getIssue = ?rhs_getIssue

||| Create a new issue.
createIssue :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (priority : Maybe String)
  -> (severity : Maybe String)
  -> (issueType : Maybe String)
  -> io (Either String Issue)
createIssue = ?rhs_createIssue

||| Update an existing issue (OCC-aware).
updateIssue :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (subject : Maybe String)
  -> (description : Maybe String)
  -> (issueType : Maybe String)
  -> (version : Version)
  -> io (Either String Issue)
updateIssue = ?rhs_updateIssue

||| Delete an issue.
deleteIssue :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteIssue = ?rhs_deleteIssue
