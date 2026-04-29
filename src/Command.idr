||| Command sum type and dispatch table.
|||
||| Each constructor corresponds to one agent-visible operation,
||| which maps to one HTTP call (or a short sequence).
module Command

import Model.Auth
import Model.Common
import Model.Epic
import Model.Issue
import Model.Milestone
import Model.Project
import Model.Task
import Model.User
import Model.UserStory
import Model.WikiPage
import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Protocol.Request
import Protocol.Response
import Taiga.Auth
import Taiga.Api

%language ElabReflection

||| Refresh token argument wrapper.
record RefreshArgs where
  constructor MkRefreshArgs
  refresh : String

%runElab derive "RefreshArgs" [Show,FromJSON]

||| Sum type of all supported commands.
public export
data Command : Type where
  -- Authentication
  CmdLogin    : Credentials -> Command
  CmdRefresh  : String       -> Command
  CmdMe       : Command

  -- Read-only / list commands
  CmdListProjects     : Maybe String -> Command
  CmdGetProject       : Maybe Nat64Id -> Maybe Slug -> Command
  CmdListEpics        : String -> Command
  CmdGetEpic          : Maybe Nat64Id -> Command
  CmdListStories      : String -> Command
  CmdGetStory         : Maybe Nat64Id -> Command
  CmdListTasks        : Maybe String -> Command
  CmdGetTask          : Maybe Nat64Id -> Command
  CmdListIssues       : String -> Command
  CmdGetIssue         : Maybe Nat64Id -> Command
  CmdListWiki         : String -> Command
  CmdGetWiki          : Maybe Nat64Id -> Command
  CmdListMilestones   : String -> Command
  CmdListUsers        : String -> Command
  CmdListMemberships  : String -> Command
  CmdListRoles        : String -> Command
  CmdSearch           : String -> String -> Command
  CmdResolve          : String -> String -> Command

  -- Write / mutation commands — epics
  CmdCreateEpic : String -> String -> Maybe String -> Maybe String -> Command
  CmdUpdateEpic : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteEpic : Nat64Id -> Command

  -- Write / mutation commands — stories
  CmdCreateStory : String -> String -> Maybe String -> Maybe Nat64Id -> Command
  CmdUpdateStory : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteStory : Nat64Id -> Command

  -- Write / mutation commands — tasks
  CmdCreateTask : String -> String -> Maybe Nat64Id -> Maybe String -> Maybe String -> Command
  CmdUpdateTask : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteTask : Nat64Id -> Command

  -- Write / mutation commands — issues
  CmdCreateIssue : String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> Command
  CmdUpdateIssue : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteIssue : Nat64Id -> Command

  -- Write / mutation commands — wiki
  CmdCreateWiki : String -> String -> String -> Command
  CmdUpdateWiki : Nat64Id -> Maybe String -> Maybe String -> Version -> Command
  CmdDeleteWiki : Nat64Id -> Command

  -- Comments (via history API)
  CmdComment      : String -> Nat64Id -> String -> Command
  CmdEditComment  : String -> Nat64Id -> Nat64Id -> String -> Command
  CmdDeleteComment : String -> Nat64Id -> Nat64Id -> Command

  -- Milestones
  CmdCreateMilestone : String -> String -> String -> String -> Command
  CmdUpdateMilestone : Nat64Id -> Maybe String -> Maybe String -> Maybe String -> Version -> Command

%runElab derive "Command" [Show,ToJSON,FromJSON]

||| Dispatch CmdLogin: authenticate and return token.
dispatchLogin :
      HasIO io
   => (creds : Credentials)
   -> (base : Maybe String)
   -> io Response
dispatchLogin _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchLogin creds (Just baseUrl)
  = do result <- login baseUrl creds
       pure (case result of
                Left  err  => Err $ MkErrorResponse False "auth_error" err
                Right tok => Ok $ MkSuccess True (encode tok))

||| Dispatch CmdRefresh: refresh expiring token.
dispatchRefresh :
      HasIO io
   => (refreshTok : String)
   -> (base : Maybe String)
   -> io Response
dispatchRefresh _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchRefresh refreshTok (Just baseUrl)
  = do result <- refreshToken baseUrl refreshTok
       pure (case result of
                Left  err  => Err $ MkErrorResponse False "auth_error" err
                Right tok => Ok $ MkSuccess True (encode tok))

||| Dispatch CmdMe: fetch current user profile.
dispatchMe :
      HasIO io
   => (auth : Maybe Token)
   -> (base : Maybe String)
   -> io Response
dispatchMe Nothing _ = pure $ Err $ MkErrorResponse False "unauthorized" "No token provided"
dispatchMe _ Nothing = pure $ Err $ MkErrorResponse False "no_base" "No base URL provided"
dispatchMe (Just token) (Just baseUrl)
  = do result <- me baseUrl token.token
       pure (case result of
                Left err  => Err $ MkErrorResponse False "api_error" err
                Right u  => Ok $ MkSuccess True (encode u))

||| Parse a command name and JSON arguments into a Command.
public export
parseCommand : (cmd : String) -> (args : String) -> Either String Command
parseCommand "me"      _ = pure CmdMe
parseCommand "login"   args = case decodeEither args of
                                Left  err  => Left err
                                Right c   => pure $ CmdLogin c
parseCommand "refresh" args = case decodeEither args of
                                Left  err  => Left err
                                Right r    => pure $ CmdRefresh r.refresh
parseCommand cmd _    = Left $ "Unknown command: " ++ cmd

||| Dispatch a parsed Command together with auth and base URL,
||| returning a Response.
public export
dispatchCommand :
      HasIO io =>
      (command : Command)
   -> (auth  : Maybe Model.Auth.Token)
   -> (base  : Maybe String)
   -> io Response
dispatchCommand command auth base
  = case command of
       CmdLogin creds     => dispatchLogin creds base
       CmdRefresh rtok    => dispatchRefresh rtok base
       CmdMe              => dispatchMe auth base
       _                  => pure $ Err $ MkErrorResponse False "unimplemented" "Command not yet implemented"
