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

||| Attempt to parse a string as Bits64.  Returns Nothing on invalid input.
private
readNat : String -> Maybe Bits64
readNat s =
  let n := cast {to = Integer} s in
  if s == "0" then Just 0
  else if n == 0 then Nothing
  else if n < 0 then Nothing
  else Just $ cast n

||| Resolve a status text (name or slug) to a numeric ID for a given entity type.
||| The entity type should be one of: "task", "issue", "us", "epic".
public export
resolveStatusText :
     (env : ApiEnv)
  -> (project : Project)
  -> (entityType : String)
  -> (statusText : String)
  -> Either String Bits64
resolveStatusText env project entityType statusText =
  let statuses := case entityType of
                    "task"  => project.task_statuses
                    "issue" => project.issue_statuses
                    "us"    => project.us_statuses
                    "epic"  => project.epic_statuses
                    _       => []
      search := toLower statusText
   in case find (\s => toLower s.name == search || toLower s.slug == search) statuses of
        Just s  => Right s.id
        Nothing =>
          -- If the text is numeric, allow it as a raw ID
          case readNat statusText of
            Just n  => Right n
            Nothing => Left $ "Status '" ++ statusText ++ "' not found for " ++ entityType

||| Lookup a status name from an ID for display purposes.
public export
lookupStatusName :
     (project : Project)
  -> (entityType : String)
  -> (statusId : Bits64)
  -> Maybe String
lookupStatusName project entityType statusId =
  let statuses := case entityType of
                    "task"  => project.task_statuses
                    "issue" => project.issue_statuses
                    "us"    => project.us_statuses
                    "epic"  => project.epic_statuses
                    _       => []
   in map (.name) $ find (\s => s.id == statusId) statuses
