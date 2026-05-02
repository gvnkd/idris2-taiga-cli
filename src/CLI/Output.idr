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
formatTaskSummaries : List TaskSummary -> String
formatTaskSummaries ts =
  unlines (map (\t => "#" ++ show t.ref ++ " " ++ t.subject) ts)

||| Format a single task.
public export
formatTask : Task -> String
formatTask t =
  unlines
    [ "ID:        " ++ show t.id.id
    , "Ref:       #" ++ show t.ref
    , "Subject:   " ++ t.subject
    , "Status:    " ++ maybe "-" show t.status
    , "Closed:    " ++ show t.is_closed
    ]

||| Format a list of epic summaries.
public export
formatEpicSummaries : List EpicSummary -> String
formatEpicSummaries es =
  unlines (map (\e => "#" ++ show e.ref ++ " " ++ e.subject) es)

||| Format a single epic.
public export
formatEpic : Epic -> String
formatEpic e =
  unlines
    [ "ID:        " ++ show e.id.id
    , "Ref:       #" ++ show e.ref
    , "Subject:   " ++ e.subject
    , "Status:    " ++ maybe "-" show e.status
    ]

||| Format a list of issue summaries.
public export
formatIssueSummaries : List IssueSummary -> String
formatIssueSummaries is =
  unlines (map (\i => "#" ++ show i.ref ++ " " ++ i.subject) is)

||| Format a single issue.
public export
formatIssue : Issue -> String
formatIssue i =
  unlines
    [ "ID:        " ++ show i.id.id
    , "Ref:       #" ++ show i.ref
    , "Subject:   " ++ i.subject
    , "Status:    " ++ maybe "-" show i.status
    ]

||| Format a list of story summaries.
public export
formatStorySummaries : List UserStorySummary -> String
formatStorySummaries ss =
  unlines (map (\s => "#" ++ show s.ref ++ " " ++ s.subject) ss)

||| Format a single story.
public export
formatStory : UserStory -> String
formatStory s =
  unlines
    [ "ID:        " ++ show s.id.id
    , "Ref:       #" ++ show s.ref
    , "Subject:   " ++ s.subject
    , "Status:    " ++ maybe "-" show s.status
    ]

||| Format a list of milestones.
public export
formatMilestoneSummaries : List MilestoneSummary -> String
formatMilestoneSummaries ms =
  unlines (map (\m => m.name ++ " (" ++ m.slug.slug ++ ")") ms)

||| Format a single milestone.
public export
formatMilestone : Milestone -> String
formatMilestone m =
  unlines
    [ "ID:              " ++ show m.id.id
    , "Name:            " ++ m.name
    , "Slug:            " ++ m.slug.slug
    , "Est. start:      " ++ maybe "-" show m.estimated_start
    , "Est. finish:     " ++ maybe "-" show m.estimated_finish
    ]

||| Format a list of wiki pages.
public export
formatWikiPageSummaries : List WikiPageSummary -> String
formatWikiPageSummaries ws =
  unlines (map (\w => w.slug.slug) ws)

||| Format a single wiki page.
public export
formatWikiPage : WikiPage -> String
formatWikiPage w =
  unlines
    [ "ID:      " ++ show w.id.id
    , "Slug:    " ++ w.slug.slug
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
