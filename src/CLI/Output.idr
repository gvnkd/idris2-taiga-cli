||| Dual-Format Output.
|||
||| Format any result as human-readable text or JSON.
||| Text mode prints formatted plain-text details.
||| JSON mode prints a single valid JSON object with no extra text.
module CLI.Output

import State.Config
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import JSON.Encoder
import Model.Common
import Model.Project
import Model.Task
import Model.Epic
import Model.Issue
import Model.UserStory
import Model.Milestone
import Model.WikiPage
import Model.Comment
import Model.Status
import Data.List
import Data.Maybe
import Data.String

%language ElabReflection

||| A unified result that carries both human-readable text content and
||| a JSON payload. The renderer picks the appropriate field based on
||| the output format.
public export
record CmdResult where
  constructor MkCmdResult
  text     : String   -- plain text for text mode
  payload  : String   -- JSON payload for JSON mode

||| Convenience constructor for success with a JSON-serialisable value.
public export
cmdOk : ToJSON a => (text : String) -> (payload : a) -> CmdResult
cmdOk txt val = MkCmdResult txt (encode val)

||| Convenience constructor for success with a raw (already-JSON) payload.
public export
cmdOkRaw : (text : String) -> (payload : String) -> CmdResult
cmdOkRaw txt raw = MkCmdResult txt raw

||| Convenience constructor for error.
public export
cmdError : String -> CmdResult
cmdError err = MkCmdResult ("error: " ++ err) "null"

||| Convenience constructor for info.
public export
cmdInfo : String -> CmdResult
cmdInfo msg = MkCmdResult msg "null"

||| Structured result for delete operations.
public export
record DeleteResult where
  constructor MkDeleteResult
  entity : String
  id     : Bits64

%runElab derive "DeleteResult" [Show,ToJSON,FromJSON]

||| Format a CmdResult for display.
||| JSON mode:  pure JSON payload only (no envelope, pipeable to jq).
||| Text mode:  plain text output.
public export
renderCmdResult : OutputFormat -> CmdResult -> String
renderCmdResult JsonFmt cr = cr.payload
renderCmdResult TextFmt cr = cr.text

-- ---------------------------------------------------------------------------
-- Status helpers
-- ---------------------------------------------------------------------------

||| Extract task statuses from cached project.
taskStatuses : Maybe Project -> List StatusInfo
taskStatuses = maybe [] (.task_statuses)

||| Extract issue statuses from cached project.
issueStatuses : Maybe Project -> List StatusInfo
issueStatuses = maybe [] (.issue_statuses)

||| Extract story statuses from cached project.
storyStatuses : Maybe Project -> List StatusInfo
storyStatuses = maybe [] (.us_statuses)

||| Extract epic statuses from cached project.
epicStatuses : Maybe Project -> List StatusInfo
epicStatuses = maybe [] (.epic_statuses)

||| Look up a status name from a list of StatusInfo.
public export
lookupStatusName : List StatusInfo -> Maybe Bits64 -> String
lookupStatusName _   Nothing  = "-"
lookupStatusName ss (Just id) =
  case find (\s => s.id == id) ss of
    Nothing => show id
    Just s  => s.name

-- ---------------------------------------------------------------------------
-- String padding helper
-- ---------------------------------------------------------------------------

||| Right-pad a string to a given width.
private
padR : Nat -> String -> String
padR n s =
  let len := length s
   in if len >= n then s else s ++ pack (replicate (minus n len) ' ')

-- ---------------------------------------------------------------------------
-- Text formatters for model types
-- ---------------------------------------------------------------------------

||| Format a list of project summaries.
public export
formatProjectSummaries : List ProjectSummary -> String
formatProjectSummaries ps =
  unlines (map (\p => p.name ++ " (" ++ p.slug.slug ++ ")") ps)

||| Format a single project.
public export
formatProject : Project -> String
formatProject p =
  unlines
    [ "ID:          " ++ show p.id.id
    , "Name:        " ++ p.name
    , "Slug:        " ++ p.slug.slug
    , "Description: " ++ p.description
    , "Private:     " ++ show p.is_private
    ]

||| Format a list of task summaries.
public export
formatTaskSummaries : Maybe Project -> List TaskSummary -> String
formatTaskSummaries mProj ts =
  let ss     := taskStatuses mProj
      fmt    : TaskSummary -> String
      fmt t  =
        let status := lookupStatusName ss t.status
            closed := if t.is_closed then " [CLOSED]" else ""
         in "#" ++ padR 4 (show t.ref) ++ " " ++ padR 14 status ++ " " ++ t.subject ++ closed
      header := "Ref   Status         Subject"
      lines  := map fmt ts
   in unlines (header :: lines)

||| Format a single task.
public export
formatTask : Maybe Project -> Task -> String
formatTask mProj t =
  let ss := taskStatuses mProj
   in unlines
        [ "Task #" ++ show t.ref ++ ": " ++ t.subject
        , replicate 40 '-'
        , "ID:      " ++ show t.id.id
        , "Status:  " ++ lookupStatusName ss t.status
        , "Story:   " ++ maybe "-" (\us => "#" ++ show us.id) t.user_story
        , "Closed:  " ++ if t.is_closed then "Yes" else "No"
        ]

||| Format a list of epic summaries.
public export
formatEpicSummaries : Maybe Project -> List EpicSummary -> String
formatEpicSummaries mProj es =
  let ss     := epicStatuses mProj
      fmt    : EpicSummary -> String
      fmt e  =
        let status := lookupStatusName ss e.status
         in "#" ++ padR 4 (show e.ref) ++ " " ++ padR 14 status ++ " " ++ e.subject
      header := "Ref   Status         Subject"
      lines  := map fmt es
   in unlines (header :: lines)

||| Format a single epic.
public export
formatEpic : Maybe Project -> Epic -> String
formatEpic mProj e =
  let ss := epicStatuses mProj
   in unlines
        [ "Epic #" ++ show e.ref ++ ": " ++ e.subject
        , replicate 40 '-'
        , "ID:      " ++ show e.id.id
        , "Status:  " ++ lookupStatusName ss e.status
        ]

||| Format a list of issue summaries.
public export
formatIssueSummaries : Maybe Project -> List IssueSummary -> String
formatIssueSummaries mProj is =
  let ss     := issueStatuses mProj
      fmt    : IssueSummary -> String
      fmt i  =
        let status := lookupStatusName ss i.status
            prio   := maybe "" (\p => " [P" ++ show p ++ "]") i.priority
         in "#" ++ padR 4 (show i.ref) ++ " " ++ padR 14 status ++ " " ++ i.subject ++ prio
      header := "Ref   Status         Subject"
      lines  := map fmt is
   in unlines (header :: lines)

||| Format a single issue.
public export
formatIssue : Maybe Project -> Issue -> String
formatIssue mProj i =
  let ss := issueStatuses mProj
   in unlines
        [ "Issue #" ++ show i.ref ++ ": " ++ i.subject
        , replicate 40 '-'
        , "ID:      " ++ show i.id.id
        , "Status:  " ++ lookupStatusName ss i.status
        , "Priority: " ++ maybe "-" show i.priority
        ]

||| Format a list of story summaries.
public export
formatStorySummaries : Maybe Project -> List UserStorySummary -> String
formatStorySummaries mProj sts =
  let ss     := storyStatuses mProj
      fmt    : UserStorySummary -> String
      fmt s  =
        let status := lookupStatusName ss s.status
            ms     := maybe "" (\m => " [M" ++ show m.id ++ "]") s.milestone
         in "#" ++ padR 4 (show s.ref) ++ " " ++ padR 14 status ++ " " ++ s.subject ++ ms
      header := "Ref   Status         Subject"
      lines  := map fmt sts
   in unlines (header :: lines)

||| Format a single story.
public export
formatStory : Maybe Project -> UserStory -> String
formatStory mProj s =
  let ss := storyStatuses mProj
   in unlines
        [ "Story #" ++ show s.ref ++ ": " ++ s.subject
        , replicate 40 '-'
        , "ID:      " ++ show s.id.id
        , "Status:  " ++ lookupStatusName ss s.status
        , "Sprint:  " ++ maybe "-" (\m => "#" ++ show m.id) s.milestone
        ]

||| Format a list of milestones.
public export
formatMilestoneSummaries : Maybe Project -> List MilestoneSummary -> String
formatMilestoneSummaries _ ms =
  let fmt    : MilestoneSummary -> String
      fmt m  = padR 30 m.name ++ " " ++ padR 14 "-" ++ " " ++ "-"
      header := "Name                           Start          Finish"
      lines  := map fmt ms
   in unlines (header :: lines)

||| Format a single milestone.
public export
formatMilestone : Milestone -> String
formatMilestone m =
  unlines
    [ "Sprint: " ++ m.name
    , replicate 40 '-'
    , "ID:      " ++ show m.id.id
    , "Slug:    " ++ m.slug.slug
    , "Start:   " ++ maybe "-" show m.estimated_start
    , "Finish:  " ++ maybe "-" show m.estimated_finish
    ]

||| Format a list of wiki pages.
public export
formatWikiPageSummaries : Maybe Project -> List WikiPageSummary -> String
formatWikiPageSummaries _ ws =
  unlines (map (\w => w.slug.slug) ws)

||| Format a single wiki page.
public export
formatWikiPage : WikiPage -> String
formatWikiPage w =
  unlines
    [ "Wiki: " ++ w.slug.slug
    , replicate 40 '-'
    , "ID:      " ++ show w.id.id
    , "Version: " ++ show w.version
    ]

||| Format a list of comments.
public export
formatCommentSummaries : List CommentSummary -> String
formatCommentSummaries cs =
  unlines (map (\c => c.author ++ " (" ++ c.created_at ++ "): " ++ c.text) cs)

||| Format a list of history entries.
public export
formatHistoryEntries : List HistoryEntry -> String
formatHistoryEntries es =
  unlines (map (\e =>
    e.user.name ++ " (" ++ e.created_at ++ "): " ++ maybe "" id e.comment) es)

||| Format a delete result.
public export
formatDeleteResult : DeleteResult -> String
formatDeleteResult dr =
  dr.entity ++ " " ++ show dr.id ++ " deleted"
