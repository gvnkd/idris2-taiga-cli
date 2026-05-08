module CLI.Output
import State.Config
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import JSON.Encoder
import Taiga.Api
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

public export
record CmdResult where
  constructor MkCmdResult
  text : String
  payload : String

public export
cmdOk : ToJSON a => (text : String) -> (payload : a) -> CmdResult
cmdOk txt val =
  MkCmdResult txt (encode val)

public export
cmdOkRaw : (text : String) -> (payload : String) -> CmdResult
cmdOkRaw txt raw =
  MkCmdResult txt raw

public export
cmdError : String -> CmdResult
cmdError err =
  MkCmdResult ("error: " ++ err) "null"

public export
cmdInfo : String -> CmdResult
cmdInfo msg =
  MkCmdResult msg "null"

public export
record DeleteResult where
  constructor MkDeleteResult
  entity : String
  id : Bits64

%runElab derive "DeleteResult" [Show, ToJSON, FromJSON]

public export
renderCmdResult : OutputFormat -> CmdResult -> String
renderCmdResult JsonFmt cr =
  cr.payload
renderCmdResult TextFmt cr =
  cr.text
-- ---------------------------------------------------------------------------
taskStatuses : Maybe Project -> List StatusInfo
taskStatuses =
  maybe [] (.task_statuses)

issueStatuses : Maybe Project -> List StatusInfo
issueStatuses =
  maybe [] (.issue_statuses)

storyStatuses : Maybe Project -> List StatusInfo
storyStatuses =
  maybe [] (.us_statuses)

epicStatuses : Maybe Project -> List StatusInfo
epicStatuses =
  maybe [] (.epic_statuses)

public export
formatPagination : PaginationMeta -> String
formatPagination meta =
  case meta.totalCount of
    Nothing => ""
    Just count => let pageInfo = case meta.currentPage of
                                   Nothing => ""
                                   Just p => " (page " ++ show p ++ ")" in "\n" ++ show count ++ " total items" ++ pageInfo

public export
lookupStatusName : List StatusInfo -> Maybe Bits64 -> String
lookupStatusName _ Nothing =
  "-"
lookupStatusName ss (Just id) =
  case find (\s => s.id == id) ss of
    Nothing => show id
    Just s => s.name

padR : Nat -> String -> String
padR n s =
  let len = length s in if len >= n
                          then s
                            else
                              s ++ pack (replicate (minus n len) ' ')

separator : String
separator =
  replicate 40 '-'
-- ---------------------------------------------------------------------------
-- Text formatters for model types
public export
formatProjectSummaries : List ProjectSummary -> String
formatProjectSummaries ps =
  unlines (map (\p => p.name ++ " (" ++ p.slug.slug ++ ")") ps)

public export
formatProject : Project -> String
formatProject p =
  unlines ["ID:          " ++ show p.id.id, "Name:        " ++ p.name, "Slug:        " ++ p.slug.slug, "Description: " ++ p.description, "Private:     " ++ show p.is_private]

public export
formatTaskSummaries : Maybe Project -> List TaskSummary -> String
formatTaskSummaries mProj ts =
  let ss = taskStatuses mProj in let
                                   fmt : TaskSummary -> String
                                   fmt t =
                                     let status = lookupStatusName ss t.status in let closed = if t.is_closed
                                                                                                 then " [CLOSED]"
                                                                                                   else
                                                                                                     "" in "#" ++ padR 4 (show t.ref) ++ " " ++ padR 14 status ++ " " ++ t.subject ++ closed
                                 in let header = "Ref   Status         Subject" in let lines = map fmt ts in unlines (header :: lines)

public export
formatTask : Maybe Project -> Task -> String
formatTask mProj t =
  let ss = taskStatuses mProj in unlines ["Task #" ++ show t.ref ++ ": " ++ t.subject, separator, "ID:      " ++ show t.id.id, "Status:  " ++ lookupStatusName ss t.status, "Story:   " ++ maybe "-" (\us => "#" ++ show us.id) t.user_story, "Closed:  " ++ (if t.is_closed
                                                                                                                                                                                                                                                                then "Yes"
                                                                                                                                                                                                                                                                  else
                                                                                                                                                                                                                                                                    "No")]

public export
formatEpicSummaries : Maybe Project -> List EpicSummary -> String
formatEpicSummaries mProj es =
  let ss = epicStatuses mProj in let
                                   fmt : EpicSummary -> String
                                   fmt e =
                                     let status = lookupStatusName ss e.status in "#" ++ padR 4 (show e.ref) ++ " " ++ padR 14 status ++ " " ++ e.subject
                                 in let header = "Ref   Status         Subject" in let lines = map fmt es in unlines (header :: lines)

public export
formatEpic : Maybe Project -> Epic -> String
formatEpic mProj e =
  let ss = epicStatuses mProj in unlines ["Epic #" ++ show e.ref ++ ": " ++ e.subject, separator, "ID:      " ++ show e.id.id, "Status:  " ++ lookupStatusName ss e.status]

public export
formatIssueSummaries : Maybe Project -> List IssueSummary -> String
formatIssueSummaries mProj is =
  let ss = issueStatuses mProj in let
                                    fmt : IssueSummary -> String
                                    fmt i =
                                      let status = lookupStatusName ss i.status in let prio = maybe "" (\p => " [P" ++ show p ++ "]") i.priority in "#" ++ padR 4 (show i.ref) ++ " " ++ padR 14 status ++ " " ++ i.subject ++ prio
                                  in let header = "Ref   Status         Subject" in let lines = map fmt is in unlines (header :: lines)

public export
formatIssue : Maybe Project -> Issue -> String
formatIssue mProj i =
  let ss = issueStatuses mProj in unlines ["Issue #" ++ show i.ref ++ ": " ++ i.subject, separator, "ID:      " ++ show i.id.id, "Status:  " ++ lookupStatusName ss i.status, "Priority: " ++ maybe "-" show i.priority]

public export
formatStorySummaries : Maybe Project -> List UserStorySummary -> String
formatStorySummaries mProj sts =
  let ss = storyStatuses mProj in let
                                    fmt : UserStorySummary -> String
                                    fmt s =
                                      let status = lookupStatusName ss s.status in let ms = maybe "" (\m => " [M" ++ show m.id ++ "]") s.milestone in "#" ++ padR 4 (show s.ref) ++ " " ++ padR 14 status ++ " " ++ s.subject ++ ms
                                  in let header = "Ref   Status         Subject" in let lines = map fmt sts in unlines (header :: lines)

public export
formatStory : Maybe Project -> UserStory -> String
formatStory mProj s =
  let ss = storyStatuses mProj in unlines ["Story #" ++ show s.ref ++ ": " ++ s.subject, separator, "ID:      " ++ show s.id.id, "Status:  " ++ lookupStatusName ss s.status, "Sprint:  " ++ maybe "-" (\m => "#" ++ show m.id) s.milestone]

public export
formatMilestoneSummaries : Maybe Project -> List MilestoneSummary -> String
formatMilestoneSummaries _ ms =
  let
    fmt : MilestoneSummary -> String
    fmt m =
      padR 30 m.name ++ " " ++ padR 14 "-" ++ " " ++ "-"
  in let header = "Name                           Start          Finish" in let lines = map fmt ms in unlines (header :: lines)

public export
formatMilestone : Milestone -> String
formatMilestone m =
  unlines ["Sprint: " ++ m.name, separator, "ID:      " ++ show m.id.id, "Slug:    " ++ m.slug.slug, "Start:   " ++ maybe "-" show m.estimated_start, "Finish:  " ++ maybe "-" show m.estimated_finish]

public export
formatWikiPageSummaries : Maybe Project -> List WikiPageSummary -> String
formatWikiPageSummaries _ ws =
  unlines (map (\w => w.slug.slug) ws)

public export
formatWikiPage : WikiPage -> String
formatWikiPage w =
  unlines ["Wiki: " ++ w.slug.slug, separator, "ID:      " ++ show w.id.id, "Version: " ++ show w.version]

public export
formatHistoryEntries : List HistoryEntry -> String
formatHistoryEntries es =
  unlines (map (\e => e.user.name ++ " (" ++ e.created_at ++ "): " ++ maybe "" id e.comment) es)

public export
formatDeleteResult : DeleteResult -> String
formatDeleteResult dr =
  dr.entity ++ " " ++ show dr.id ++ " deleted"
