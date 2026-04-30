||| Command-line argument parser.
|||
||| Hand-rolled parser: consumes `List String` from `getArgs` and
||| produces a `CLIArgs` value.  Unrecognised flags or missing
||| arguments yield a parse error string.
module CLI.Parse

import CLI.Args
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

||| Attempt to read a non-negative integer from a string argument.
public export
readNat64 : String -> Either String Bits64
readNat64 s =
  let n := cast {to = Integer} s in
  if s == "0" then Right 0
  else if n == 0 then Left "not a number"
  else if n < 0 then Left "negative number"
  else Right $ cast n

||| Attempt to read a non-negative integer (version / id helper).
public export
readNat32 : String -> Either String Bits32
readNat32 s =
  let n := cast {to = Integer} s in
  if s == "0" then Right 0
  else if n == 0 then Left "not a number"
  else if n < 0 then Left "negative number"
  else Right $ cast n

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