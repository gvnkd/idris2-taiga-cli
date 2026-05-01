||| Command-line argument parser.
|||
||| Hand-rolled parser: consumes `List String` from `getArgs` and
||| produces a `CLIArgs` value.  Unrecognised flags or missing
||| arguments yield a parse error string.
module CLI.Parse

import CLI.Args
import CLI.Subcommand
import Model.Auth
import Model.Common
import Data.List

%language ElabReflection

||| Parser state: remaining arguments and accumulated base URL.
public export
record State where
  constructor MkState
  rest : List String
  base : Maybe String

||| Result of parsing the command-line arguments.
public export
record ParseResult where
  constructor MkParseResult
  cli_args : CLIArgs
  base_url : Maybe String

||| A parser that consumes a `State` and produces a value,
||| the remaining `State`, or an error.
public export
record Parser a where
  constructor MkParser
  run : State -> Either String (a, State)

||| Polymorphic helper to parse a non-negative integer from String.
private
readNat' : 
     {auto _ : Cast Integer a}
  -> {auto _ : Ord a}
  -> (zero : a)
  -> String
  -> Either String a
readNat' zero s =
  let n := cast {to = Integer} s in
  if s == "0" then Right zero
  else if n == 0 then Left "not a number"
  else if n < 0 then Left "negative number"
  else Right $ cast n

||| Attempt to read a non-negative integer as Bits64.
public export
readNat64 : String -> Either String Bits64
readNat64 = readNat' 0

||| Attempt to read a non-negative integer as Bits32.
public export
readNat32 : String -> Either String Bits32
readNat32 = readNat' 0

||| Check whether a flag string starts with "--".
public export
isLongFlag : String -> Bool
isLongFlag s =
  case unpack s of
     []            => False
     [_]           => False
     ('-' :: '-' :: _) => True
     _             => False

||| Check whether a flag string starts with "-" (short form).
public export
isShortFlag : String -> Bool
isShortFlag s =
  case unpack s of
     []        => False
     ('-' :: _) => True
     _         => False

||| Consume the next argument from the front of the list.
public export
nextArg : List String -> Either String String
nextArg []        = Left "missing argument"
nextArg (x :: _) = pure x

||| Functor instance: map a function over the parser's result.
public export
Functor Parser where
 map f p = MkParser (\st => case run p st of
                                 Left  e      => Left e
                                 Right (v, s) => Right (f v, s))

||| Applicative instance: sequential parser composition.
public export
Applicative Parser where
  pure v = MkParser (\st => Right (v, st))
  (<*>) af ax = MkParser
    (\st => case run af st of
               Left  e              => Left e
               Right (f, st1)       => case run ax st1 of
                                         Left  e              => Left e
                                         Right (v, st2)       => Right (f v, st2))

||| Monad instance: bind parsers with state threading.
public export
Monad Parser where
  (>>=) mx f = MkParser
    (\st => case run mx st of
               Left  e              => Left e
               Right (v, st1)       => run (f v) st1)

||| Primitive: peek at the next argument without consuming it.
peek : Parser (Maybe String)
peek = MkParser
  (\st => case st.rest of
             []       => Right (Nothing, st)
             (x :: _) => Right (Just x, st))

||| Primitive: consume the next argument.
pop : Parser String
pop = MkParser
  (\st => case st.rest of
             []       => Left "expected argument, got end of input"
             (x :: xs) => Right (x, MkState xs st.base))

||| Primitive: check if input is exhausted.
isEmpty : Parser Bool
isEmpty = MkParser
  (\st => case st.rest of
             []       => Right (True, st)
             (_ :: _) => Right (False, st))

||| Primitive: set the base URL.
setBase : String -> Parser ()
setBase url = MkParser
  (\st => Right ((), MkState st.rest (Just url)))

||| Fail with an error message.
failParse : String -> Parser a
failParse msg = MkParser (\_ => Left msg)

||| Strip the leading `--` from a long flag name.
stripDashes : String -> String
stripDashes s = case drop 2 (unpack s) of
                   []  => ""
                   cs  => pack cs

||| Parse `--help` / `-h`.
parseHelp : Parser CLIArgs
parseHelp = pure ArgHelp

||| Parse `--stdin`: read JSON from stdin instead of running a CLI command.
parseStdin : Parser CLIArgs
parseStdin = pure ArgStdin

||| Parse `--login USER PASS`.
parseLogin : Parser CLIArgs
parseLogin = ArgLogin <$> pop <*> pop

||| Parse `--me`.
parseMe : Parser CLIArgs
parseMe = pure ArgMe

||| Decide whether the next argument looks like a flag or is absent.
||| Returns `True` when the next arg is a flag OR there is no next arg,
||| meaning the optional parameter should be treated as absent.
looksLikeFlag : Maybe String -> Bool
looksLikeFlag Nothing  = True
looksLikeFlag (Just s) = isLongFlag s

||| Parse `--list-projects [OWNER]`.
parseListProjects : Parser CLIArgs
parseListProjects = classifyNext >>= go

  where
    classifyNext : Parser Bool
    classifyNext = do
      next <- peek
      pure $ looksLikeFlag next

    go : Bool -> Parser CLIArgs
    go True  = pure $ ArgListProjects Nothing
    go False = do
      owner <- pop
      pure $ ArgListProjects (Just owner)

||| Parse `--base URL` and store the base URL in state.
parseBase : (recurse : Parser CLIArgs) -> Parser CLIArgs
parseBase recurse = do
  url <- pop
  setBase url
  recurse

||| Parse `--watch-task ID`.
parseWatchTask : Parser CLIArgs
parseWatchTask = do
  idStr <- pop
  case readNat64 idStr of
    Left  _     => failParse $ "invalid task id: " ++ idStr
    Right nid   => pure $ ArgWatchTask (MkNat64Id nid)

||| Parse `--change-task-status ID STATUS VERSION`.
parseChangeTaskStatus : Parser CLIArgs
parseChangeTaskStatus = do
  idStr   <- pop
  stStr   <- pop
  verStr  <- pop
  case (readNat64 idStr, readNat64 stStr, readNat32 verStr) of
    (Left _, _, _)   => failParse $ "invalid task id: " ++ idStr
    (_, Left _, _)   => failParse $ "invalid status id: " ++ stStr
    (_, _, Left _)   => failParse $ "invalid version: " ++ verStr
    (Right nid, Right st, Right v)
                    => pure $ ArgChangeTaskStatus (MkNat64Id nid) st (MkVersion v)

||| Parse `--task-comment ID TEXT VERSION`.
parseTaskComment : Parser CLIArgs
parseTaskComment = do
  idStr  <- pop
  txt    <- pop
  verStr <- pop
  case (readNat64 idStr, readNat32 verStr) of
    (Left _, _)   => failParse $ "invalid task id: " ++ idStr
    (_, Left _)   => failParse $ "invalid version: " ++ verStr
    (Right nid, Right v)
                    => pure $ ArgTaskComment (MkNat64Id nid) txt (MkVersion v)

||| Parse `--list-comments ENTITY ID`.
parseListComments : Parser CLIArgs
parseListComments = do
  entity <- pop
  idStr  <- pop
  case readNat64 idStr of
    Left  _     => failParse $ "invalid entity id: " ++ idStr
    Right nid   => pure $ ArgListComments entity (MkNat64Id nid)

||| Parse `--delete-milestone ID`.
parseDeleteMilestone : Parser CLIArgs
parseDeleteMilestone = do
  idStr <- pop
  case readNat64 idStr of
    Left  _     => failParse $ "invalid milestone id: " ++ idStr
    Right nid   => pure $ ArgDeleteMilestone (MkNat64Id nid)

||| Parse a long flag and dispatch to the correct sub-parser.
parseLongFlag : String -> Parser CLIArgs -> Parser CLIArgs
parseLongFlag "--base"                recurse = parseBase recurse
parseLongFlag "--help"                _        = parseHelp
parseLongFlag "--stdin"               _        = parseStdin
parseLongFlag "--login"               _        = parseLogin
parseLongFlag "--me"                  _        = parseMe
parseLongFlag "--list-projects"       _        = parseListProjects
parseLongFlag "--watch-task"          _        = parseWatchTask
parseLongFlag "--change-task-status"  _        = parseChangeTaskStatus
parseLongFlag "--task-comment"        _        = parseTaskComment
parseLongFlag "--list-comments"       _        = parseListComments
parseLongFlag "--delete-milestone"    _        = parseDeleteMilestone
parseLongFlag flag                    _        = failParse $ "unimplemented flag: " ++ flag

||| Top-level parser: dispatch on the first argument and invoke
||| the appropriate sub-parser.
parseCLI : Parser CLIArgs
parseCLI = do
  hasArgs <- isEmpty
  if hasArgs
    then failParse "no command given"
    else do
      flag <- pop
      if not $ isLongFlag flag
        then failParse $ "unrecognised flag: " ++ flag
        else parseLongFlag flag parseCLI

||| Parse a list of raw command-line arguments.
|||
||| Returns `Left err` on parse failure, or `Right result` with the
||| parsed `CLIArgs` and any global `--base` that was supplied.
public export
parseArgs : List String -> Either String ParseResult
parseArgs rawArgs =
  let st := MkState rawArgs Nothing
   in case run parseCLI st of
         Left  e              => Left e
         Right (args, st')    => Right $ MkParseResult args st'.base

||| Scan a list of tokens for `--flag value` and return the value.
||| If the flag appears without a following value, returns Nothing.
public export
findFlag : String -> List String -> Maybe String
findFlag _ [] = Nothing
findFlag _ [_] = Nothing
findFlag key (a :: b :: rest) =
  if a == key then Just b else findFlag key (b :: rest)

------------------------------------------------------------------------------
-- Subcommand Parser
------------------------------------------------------------------------------

||| Parse subcommand arguments into an Action.
|||
||| Syntax: taiga-cli <verb> [<action>] [args...] [--json]
public export
parseAction : List String -> Either String Action
parseAction []                         = Left "no command given"
parseAction ("init" :: rest)           =
  case rest of
    []        => Right $ ActInit Nothing
    (url ::_) => Right $ ActInit (Just url)
parseAction ("login" :: "--user" :: u :: "--password" :: p :: _) =
  Right $ ActLogin u (Just p)
parseAction ("login" :: "--user" :: u :: "--pass" :: p :: _) =
  Right $ ActLogin u (Just p)
parseAction ("login" :: "--user" :: u :: _) =
  Right $ ActLogin u Nothing
parseAction ("login" :: _)             = Left "usage: login --user USER [--password PASS | --pass PASS]"
parseAction ("logout" :: _)            = Right ActLogout
parseAction ("show" :: _)              = Right ActShow
parseAction ("project" :: "list" :: _) = Right ActProjectList
parseAction ("project" :: "set" :: slug :: _) = Right $ ActProjectSet slug
parseAction ("project" :: "get" :: _)  = Right ActProjectGet
parseAction ("project" :: _)           = Left "usage: project {list|set <slug>|get}"
parseAction ("task" :: "list" :: rest) =
  case rest of
    []               => Right $ ActTaskList Nothing
    ("--status" :: s :: _) => Right $ ActTaskList (Just s)
    _                => Left "usage: task list [--status STATUS]"
parseAction ("task" :: "create" :: subj :: _) = Right $ ActTaskCreate subj
parseAction ("task" :: "get" :: ident :: _) = Right $ ActTaskGet ident
parseAction ("task" :: "update" :: ident :: rest) =
  let mSubj     := findFlag "--subject" rest
      mDesc     := findFlag "--description" rest
      mStatText := findFlag "--status" rest
      mStatId   := findFlag "--statusId" rest
   in case mStatId of
        Nothing  => Right $ ActTaskUpdate ident mSubj mDesc mStatText Nothing
        Just sid => case readNat64 sid of
          Right id  => Right $ ActTaskUpdate ident mSubj mDesc Nothing (Just id)
          Left _    => Left "usage: task update <id-or-ref> [--subject S] [--description D] [--status ST|--statusId N]"
parseAction ("task" :: "delete" :: ident :: _) = Right $ ActTaskDelete ident
parseAction ("task" :: "status" :: ident :: stStr :: _) =
  case readNat64 stStr of
    Right st  => Right $ ActTaskStatus ident st
    Left _    => Left "usage: task status <id-or-ref> <status-id>"
parseAction ("task" :: "comment" :: ident :: text :: _) = Right $ ActTaskComment ident text
parseAction ("task" :: "assign-story" :: taskIdent :: storyIdent :: _) = Right $ ActTaskAssignStory taskIdent storyIdent
parseAction ("task" :: "statuses" :: _) = Right ActTaskStatuses
parseAction ("task" :: _)              = Left "usage: task {list|create <subject>|get <id-or-ref>|update <id-or-ref> [--subject S] [--description D] [--status ST]|delete <id-or-ref>|status <id-or-ref> <status>|comment <id-or-ref> <text>|assign-story <task-id-or-ref> <story-id-or-ref>|statuses}"
parseAction ("epic" :: "list" :: _)    = Right ActEpicList
parseAction ("epic" :: "get" :: ident :: _) = Right $ ActEpicGet ident
parseAction ("epic" :: "create" :: subj :: rest) =
  let mDesc   := findFlag "--description" rest
      mStatus := findFlag "--status" rest
   in Right $ ActEpicCreate subj mDesc mStatus
parseAction ("epic" :: "update" :: ident :: rest) =
  let mSubj     := findFlag "--subject" rest
      mDesc     := findFlag "--description" rest
      mStatText := findFlag "--status" rest
      mStatId   := findFlag "--statusId" rest
   in case mStatId of
        Nothing  => Right $ ActEpicUpdate ident mSubj mDesc mStatText Nothing
        Just sid => case readNat64 sid of
          Right id  => Right $ ActEpicUpdate ident mSubj mDesc Nothing (Just id)
          Left _    => Left "usage: epic update <id-or-ref> [--subject S] [--description D] [--status ST|--statusId N]"
parseAction ("epic" :: "delete" :: ident :: _) = Right $ ActEpicDelete ident
parseAction ("epic" :: "statuses" :: _) = Right ActEpicStatuses
parseAction ("epic" :: _)              = Left "usage: epic {list|get <id-or-ref>|create <subject> [--description D] [--status ST]|update <id-or-ref> [--subject S] [--description D] [--status ST]|delete <id-or-ref>|statuses}"
parseAction ("story" :: "list" :: _)   = Right ActStoryList
parseAction ("story" :: "get" :: ident :: _) = Right $ ActStoryGet ident
parseAction ("story" :: "create" :: subj :: rest) =
  let mDesc := findFlag "--description" rest
      mMs   := findFlag "--milestone" rest
   in Right $ ActStoryCreate subj mDesc mMs
parseAction ("story" :: "update" :: ident :: rest) =
  let mSubj     := findFlag "--subject" rest
      mDesc     := findFlag "--description" rest
      mMs       := findFlag "--milestone" rest
      mStatText := findFlag "--status" rest
      mStatId   := findFlag "--statusId" rest
   in case mStatId of
        Nothing  => Right $ ActStoryUpdate ident mSubj mDesc mMs mStatText Nothing
        Just sid => case readNat64 sid of
          Right id  => Right $ ActStoryUpdate ident mSubj mDesc mMs Nothing (Just id)
          Left _    => Left "usage: story update <id-or-ref> [--subject S] [--description D] [--milestone M] [--status ST|--statusId N]"
parseAction ("story" :: "delete" :: ident :: _) = Right $ ActStoryDelete ident
parseAction ("story" :: "statuses" :: _) = Right ActStoryStatuses
parseAction ("story" :: _)             = Left "usage: story {list|get <id-or-ref>|create <subject> [--description D] [--milestone M]|update <id-or-ref> [--subject S] [--description D] [--milestone M]|delete <id-or-ref>|statuses}"
parseAction ("issue" :: "list" :: _)   = Right ActIssueList
parseAction ("issue" :: "get" :: ident :: _) = Right $ ActIssueGet ident
parseAction ("issue" :: "create" :: subj :: rest) =
  let mDesc := findFlag "--description" rest
      mPrio := findFlag "--priority" rest
      mSev  := findFlag "--severity" rest
      mType := findFlag "--type" rest
   in Right $ ActIssueCreate subj mDesc mPrio mSev mType
parseAction ("issue" :: "update" :: ident :: rest) =
  let mSubj     := findFlag "--subject" rest
      mDesc     := findFlag "--description" rest
      mType     := findFlag "--type" rest
      mStatText := findFlag "--status" rest
      mStatId   := findFlag "--statusId" rest
   in case mStatId of
        Nothing  => Right $ ActIssueUpdate ident mSubj mDesc mType mStatText Nothing
        Just sid => case readNat64 sid of
          Right id  => Right $ ActIssueUpdate ident mSubj mDesc mType Nothing (Just id)
          Left _    => Left "usage: issue update <id-or-ref> [--subject S] [--description D] [--type T] [--status ST|--statusId N]"
parseAction ("issue" :: "delete" :: ident :: _) = Right $ ActIssueDelete ident
parseAction ("issue" :: "statuses" :: _) = Right ActIssueStatuses
parseAction ("issue" :: _)             = Left "usage: issue {list|get <id-or-ref>|create <subject> [--description D] [--priority P] [--severity S] [--type T]|update <id-or-ref> [--subject S] [--description D] [--type T] [--status ST]|delete <id-or-ref>|statuses}"
parseAction ("wiki" :: "list" :: _)    = Right ActWikiList
parseAction ("wiki" :: "get" :: ident :: _) = Right $ ActWikiGet ident
parseAction ("wiki" :: "create" :: slug :: content :: _) = Right $ ActWikiCreate slug content
parseAction ("wiki" :: "update" :: ident :: rest) =
  let mContent := findFlag "--content" rest
      mSlug    := findFlag "--slug" rest
   in Right $ ActWikiUpdate ident mContent mSlug
parseAction ("wiki" :: "delete" :: ident :: _) = Right $ ActWikiDelete ident
parseAction ("wiki" :: _)              = Left "usage: wiki {list|get <id-or-ref>|create <slug> <content>|update <id-or-ref> [--content C] [--slug S]|delete <id-or-ref>}"
parseAction ("sprint" :: "list" :: _)  = Right ActSprintList
parseAction ("sprint" :: "show" :: _)  = Right ActSprintShow
parseAction ("sprint" :: "set" :: ident :: _) = Right $ ActSprintSet ident
parseAction ("sprint" :: "create" :: name :: rest) =
  let mStart := findFlag "--start" rest
      mEnd   := findFlag "--end" rest
   in Right $ ActSprintCreate name mStart mEnd
parseAction ("sprint" :: "update" :: ident :: rest) =
  let mName  := findFlag "--name" rest
      mStart := findFlag "--start" rest
      mEnd   := findFlag "--end" rest
      mVer   := findFlag "--version" rest
   in case mVer of
        Nothing   => Left "usage: sprint update <id-or-ref> --version VER [--name N] [--start DATE] [--end DATE]"
        Just ver  => case readNat64 ver of
                         Right v   => Right $ ActSprintUpdate ident mName mStart mEnd v
                         Left _    => Left "usage: sprint update <id-or-ref> --version VER [--name N] [--start DATE] [--end DATE]"
parseAction ("sprint" :: "delete" :: ident :: _) = Right $ ActSprintDelete ident
parseAction ("sprint" :: _)            = Left "usage: sprint {list|show|set <id-or-ref>|create <name> [--start DATE] [--end DATE]|update <id-or-ref> [--name N] [--start DATE] [--end DATE]|delete <id-or-ref>}"
parseAction ("comment" :: "add" :: entity :: ident :: text :: _) = Right $ ActCommentAdd entity ident text
parseAction ("comment" :: "list" :: entity :: ident :: _) = Right $ ActCommentList entity ident
parseAction ("comment" :: _)           = Left "usage: comment {add <entity> <id-or-ref> <text>|list <entity> <id-or-ref>}"
parseAction ("resolve" :: ref :: _)    = Right $ ActResolve ref
parseAction ("resolve" :: _)           = Left "usage: resolve <ref>"
parseAction (cmd :: _)                 = Left $ "unknown command: " ++ cmd