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

%language ElabReflection

||| Fetch and parse a JSON list from a GET request.
fetchHistoryList :
     HasIO io
  => (url : String)
  -> (token : String)
  -> io (Either String (List HistoryEntry))
fetchHistoryList url token = do
  resp <- httpGet url (Just token)
  if resp.status.code == 200
    then case decodeEither resp.body of
           Left  err  => pure $ Left err
           Right hs  => pure $ Right hs
    else pure $ Left $ "list history failed with status " ++ show resp.status.code

||| List all history entries (including comments) for an entity.
|||
||| Entity type is one of: `"task"`, `"issue"`, `"userstory"`, `"wiki"`.
public export
listHistory :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> io (Either String (List HistoryEntry))
listHistory base token entity eid =
  fetchHistoryList (base ++ "/history/" ++ entity ++ "/" ++ show eid.id) token

||| Send a PATCH and return success/error string.
patchUrl :
     HasIO io
  => (url : String)
  -> (token : String)
  -> (body : String)
  -> io (Either String String)
patchUrl url token body = do
  resp <- httpPatch url (Just token) body
  if resp.status.code == 200
    then pure $ Right "patched"
    else pure $ Left $ "patch failed with status " ++ show resp.status.code

||| Add a comment to an entity by PATCHing the entity with a comment field.
|||
||| For tasks, this PATCHes `/tasks/{id}` with `{"comment": ..., "version": v}`.
public export
addComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> (text : String)
  -> (version : Bits32)
  -> io (Either String String)
addComment base token entity eid txt ver =
  patchUrl (base ++ "/" ++ entity ++ "s/" ++ show eid.id) token
    ("{\"comment\":" ++ encode txt ++ ",\"version\":" ++ show ver ++ "}")

||| Edit an existing comment is not supported by Taiga's API.
||| Returns a descriptive error.
public export
editComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> (commentId : String)
  -> (text : String)
  -> io (Either String String)
editComment _ _ _ _ _ _ = pure $ Left "Taiga does not support editing comments"

||| Delete a comment is not supported by Taiga's API.
||| Returns a descriptive error.
public export
deleteComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> (commentId : String)
  -> io (Either String ())
deleteComment _ _ _ _ _ = pure $ Left "Taiga does not support deleting comments"