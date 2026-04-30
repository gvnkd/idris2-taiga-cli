||| Comment (history) endpoints.
|||
||| Comments in Taiga are stored as history entries.  Reading comments
||| uses `GET /history/{entity}/{id}`.  Adding a comment uses `PATCH`
||| on the entity itself with a `comment` field.
module Taiga.History

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Comment
import Taiga.Api
import Taiga.Env

%language ElabReflection

||| Request body for adding a comment to an entity.
public export
record CommentBody where
  constructor MkCommentBody
  comment : String
  version : Bits32

public export
ToJSON CommentBody where
  toJSON b =
    object
      [ jpair "comment" b.comment
      , jpair "version" b.version
      ]

parameters {auto env : ApiEnv}

  ||| Fetch and parse a JSON list from a GET request.
  fetchHistoryList :
       (url : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List HistoryEntry))
  fetchHistoryList url = do
    resp <- authGet env url
    expectJson resp 200 "list history"

  ||| List all history entries (including comments) for an entity.
  |||
  ||| Entity type is one of: `"task"`, `"issue"`, `"userstory"`, `"wiki"`.
  public export
  listHistory :
       (entity : String)
    -> (entityId : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String (List HistoryEntry))
  listHistory entity eid =
    fetchHistoryList (env.base ++ "/history/" ++ entity ++ "/" ++ show eid.id)

  ||| Send a PATCH and return success/error string.
  patchUrl :
       (url : String)
    -> (body : String)
    -> {auto _ : HasIO io}
    -> io (Either String String)
  patchUrl url body = do
    resp <- authPatch env url body
    expectRaw resp 200 "patch"

  ||| Resolve the correct plural URL path for an entity type.
  entityPlural : String -> String
  entityPlural "userstory" = "userstories"
  entityPlural other       = other ++ "s"

  ||| Add a comment to an entity by PATCHing the entity with a comment field.
  |||
  ||| For tasks, this PATCHes `/tasks/{id}` with `{"comment": ..., "version": v}`.
  public export
  addComment :
       (entity : String)
    -> (entityId : Nat64Id)
    -> (text : String)
    -> (version : Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String String)
  addComment entity eid txt ver = do
    let url := env.base ++ "/" ++ entityPlural entity ++ "/" ++ show eid.id
        body := encode $ MkCommentBody txt ver
    resp <- authPatch env url body
    expectRaw resp 200 "add comment"

  ||| Edit an existing comment is not supported by Taiga's API.
  ||| Returns a descriptive error.
  public export
  editComment :
       (entity : String)
    -> (entityId : Nat64Id)
    -> (commentId : String)
    -> (text : String)
    -> {auto _ : HasIO io}
    -> io (Either String String)
  editComment _ _ _ _ = pure $ Left "Taiga does not support editing comments"

  ||| Delete a comment is not supported by Taiga's API.
  ||| Returns a descriptive error.
  public export
  deleteComment :
       (entity : String)
    -> (entityId : Nat64Id)
    -> (commentId : String)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteComment _ _ _ = pure $ Left "Taiga does not support deleting comments"