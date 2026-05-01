||| Dynamic status resolution.
|||
||| Fetches project metadata and resolves human-readable status names
||| to numeric IDs at runtime.  Handles custom statuses created by
||| users in the Taiga web UI.
module Taiga.Status

import JSON.FromJSON
import JSON.ToJSON
import JSON.Derive
import Model.Common
import Model.Project
import Model.Status
import Taiga.Api
import Taiga.Env
import Data.List
import Data.String

%language ElabReflection

||| Get the status list for a given entity kind from a project.
public export
statusesOf : Project -> EntityKind -> List StatusInfo
statusesOf p TaskK  = p.task_statuses
statusesOf p IssueK = p.issue_statuses
statusesOf p StoryK = p.us_statuses
statusesOf p EpicK  = p.epic_statuses
statusesOf _ _      = []

||| Resolve a status text (name or slug) to a numeric ID for a given entity type.
public export
resolveStatusText :
     (env : ApiEnv)
  -> (project : Project)
  -> (entityType : String)
  -> (statusText : String)
  -> Either String Bits64
resolveStatusText env project entityType statusText =
  case parseEntityKind entityType of
    Nothing =>
      Left $ "Unknown entity type: " ++ entityType
    Just kind =>
      let statuses := statusesOf project kind
          search := toLower statusText
       in case find (\s => toLower s.name == search || toLower s.slug == search) statuses of
           Just s  => Right s.id
           Nothing =>
             case readNat statusText of
               Just n  => Right n
               Nothing =>
                 Left $ "Status '" ++ statusText ++ "' not found for " ++ entityType

||| Lookup a status name from an ID for display purposes.
public export
lookupStatusName :
     (project : Project)
  -> (entityType : String)
  -> (statusId : Bits64)
  -> Maybe String
lookupStatusName project entityType statusId =
  case parseEntityKind entityType of
    Nothing => Nothing
    Just kind =>
      map (.name) $ find (\s => s.id == statusId) (statusesOf project kind)
