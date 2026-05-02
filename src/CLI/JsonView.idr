||| JSON-to-Text View Layer.
|||
||| Text mode is a view over the JSON payload.  This module extracts
||| fields from JSON values and formats them as human-readable text.
||| Future: support `--fields` and `--filter` flags for user-defined
||| views.
module CLI.JsonView

import JSON.Parser
import JSON.FromJSON
import JSON.ToJSON
import Model.Status
import Data.List
import Data.Maybe
import Data.String

%language ElabReflection

-- ---------------------------------------------------------------------------
-- JSON navigation helpers
-- ---------------------------------------------------------------------------

||| Lookup a field in a JSON object.
public export
jsonField : String -> JSON -> Maybe JSON
jsonField key (JObject pairs) = lookup key pairs
jsonField _   _               = Nothing

||| Get string value from JSON.
public export
jsonString : JSON -> Maybe String
jsonString (JString s) = Just s
jsonString _           = Nothing

||| Get integer value from JSON.
public export
jsonInt : JSON -> Maybe Integer
jsonInt (JInteger n) = Just n
jsonInt _            = Nothing

||| Get bool value from JSON.
public export
jsonBool : JSON -> Maybe Bool
jsonBool (JBool b) = Just b
jsonBool _         = Nothing

||| Get array value from JSON.
public export
jsonArray : JSON -> Maybe (List JSON)
jsonArray (JArray xs) = Just xs
jsonArray _           = Nothing

||| Format a JSON value for display (primitive preview).
public export
jsonPreview : JSON -> String
jsonPreview JNull         = "-"
jsonPreview (JBool True)  = "Yes"
jsonPreview (JBool False) = "No"
jsonPreview (JString s)   = s
jsonPreview (JInteger n)  = show n
jsonPreview (JDouble d)   = show d
jsonPreview (JArray _)    = "[...]"
jsonPreview (JObject _)   = "{...}"

-- ---------------------------------------------------------------------------
-- Field extraction with status resolution
-- ---------------------------------------------------------------------------

||| Context for formatting: status name mappings and other enrichments.
public export
record FormatCtx where
  constructor MkFormatCtx
  taskStatuses  : List StatusInfo
  issueStatuses : List StatusInfo
  storyStatuses : List StatusInfo
  epicStatuses  : List StatusInfo

||| Empty context (no status mappings).
public export
emptyCtx : FormatCtx
emptyCtx = MkFormatCtx [] [] [] []

||| Look up a status name from an ID.
public export
lookupStatusName' : List StatusInfo -> Integer -> Maybe String
lookupStatusName' ss id = map (.name) $ find (\s => cast s.id == id) ss

||| Resolve a status field value using context.
public export
resolveStatus : FormatCtx -> String -> JSON -> String
resolveStatus ctx entityType j =
  case jsonInt j of
    Nothing  => jsonPreview j
    Just id  =>
      let statuses := case entityType of
                        "task"  => ctx.taskStatuses
                        "issue" => ctx.issueStatuses
                        "story" => ctx.storyStatuses
                        "epic"  => ctx.epicStatuses
                        _       => []
       in fromMaybe (show id) $ lookupStatusName' statuses id

-- ---------------------------------------------------------------------------
-- Entity formatting
-- ---------------------------------------------------------------------------

||| Format a single JSON object as key-value lines.
public export
formatJsonObject : List (String, JSON) -> String
formatJsonObject pairs =
  unlines $ map (\(k,v) => k ++ ": " ++ jsonPreview v) pairs

||| Format a JSON array of objects as a text table.
||| Shows selected fields; if none specified, shows all top-level fields.
public export
formatJsonArray : FormatCtx -> List String -> List JSON -> String
formatJsonArray ctx fields items =
  unlines $ map (formatJsonItem ctx fields) items

||| Format a single JSON item (object) showing selected fields.
public export
formatJsonItem : FormatCtx -> List String -> JSON -> String
formatJsonItem ctx fields (JObject pairs) =
  let showField : String -> String
      showField key =
        case lookup key pairs of
          Nothing => ""
          Just v  =>
            let val := case key of
                         "status" => resolveStatus ctx "task" v
                         _        => jsonPreview v
             in "[" ++ val ++ "]"
   in concat $ intersperse " " $ filter (\s => length s > 0) $ map showField fields
formatJsonItem _ _ _ = ""

-- ---------------------------------------------------------------------------
-- Default field sets for entity types
-- ---------------------------------------------------------------------------

||| Default fields to show for task list view.
public export
taskListFields : List String
taskListFields = ["ref", "status", "subject", "is_closed"]

||| Default fields to show for epic list view.
public export
epicListFields : List String
epicListFields = ["ref", "status", "subject"]

||| Default fields to show for issue list view.
public export
issueListFields : List String
issueListFields = ["ref", "status", "subject", "priority"]

||| Default fields to show for story list view.
public export
storyListFields : List String
storyListFields = ["ref", "status", "subject"]

||| Default fields to show for milestone list view.
public export
milestoneListFields : List String
milestoneListFields = ["name", "estimated_start", "estimated_finish"]

||| Default fields to show for wiki list view.
public export
wikiListFields : List String
wikiListFields = ["slug"]

||| Format any JSON value according to entity defaults.
public export
formatJsonByType : FormatCtx -> String -> JSON -> String
formatJsonByType ctx "task"     (JArray xs) = formatJsonArray ctx taskListFields xs
formatJsonByType ctx "epic"     (JArray xs) = formatJsonArray ctx epicListFields xs
formatJsonByType ctx "issue"    (JArray xs) = formatJsonArray ctx issueListFields xs
formatJsonByType ctx "story"    (JArray xs) = formatJsonArray ctx storyListFields xs
formatJsonByType ctx "milestone" (JArray xs) = formatJsonArray ctx milestoneListFields xs
formatJsonByType ctx "wiki"     (JArray xs) = formatJsonArray ctx wikiListFields xs
formatJsonByType _   _          json        = jsonPreview json
