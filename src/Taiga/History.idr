||| Comment (history) endpoints.
|||
||| Comments in Taiga are stored as history entries.  Reading comments
||| uses `GET /history/{entity}/{id}`.  Adding a comment uses `PATCH`
||| on the entity itself with a `comment` field.
module Taiga.History

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Comment
import Taiga.Api
import Taiga.Env

%language ElabReflection

parameters {auto env : ApiEnv}

  ||| Fetch and parse a JSON list from a GET request.
  fetchHistoryList :
       (url : String)
    -> {auto _ : HasIO io}
    -> io (Either String (List HistoryEntry))
  fetchHistoryList url = do
    resp <- authGet env url
    pure $ if resp.status.code == 200
             then case decodeEither resp.body of
                    Left  err  => Left err
                    Right hs  => Right hs
             else Left $ "list history failed with status " ++ show resp.status.code

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
    pure $ if resp.status.code == 200
             then Right "patched"
             else Left $ "patch failed with status " ++ show resp.status.code

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
  addComment entity eid txt ver =
    patchUrl (env.base ++ "/" ++ entity ++ "s/" ++ show eid.id)
      ("{\"comment\":" ++ encode txt ++ ",\"version\":" ++ show ver ++ "}")

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