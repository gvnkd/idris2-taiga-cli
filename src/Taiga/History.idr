module Taiga.History
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Comment
import Taiga.Api
import Taiga.Env

%language ElabReflection

public export
record CommentBody where
  constructor MkCommentBody
  comment : String
  version : Bits32

public export
implementation ToJSON CommentBody where
  toJSON b =
    object [jpair "comment" b.comment, jpair "version" b.version]

parameters {auto env : ApiEnv}
  fetchHistoryList : (url : String) -> {auto _ : HasIO io} -> io (Either String (List HistoryEntry))
  fetchHistoryList url = do
    resp <- authGet env url
    expectJson resp 200 "list history"
  public export
  listHistory : (entity : String) -> (entityId : Nat64Id) -> {auto _ : HasIO io} -> io (Either String (List HistoryEntry))
  listHistory entity eid =
    fetchHistoryList (buildUrl ["history", entity, showId eid] [] env.base)
  patchUrl : (url : String) -> (body : String) -> {auto _ : HasIO io} -> io (Either String String)
  patchUrl url body = do
    resp <- authPatch env url body
    expectRaw resp 200 "patch"
  entityPlural : String -> String
  entityPlural "userstory" =
    "userstories"
  entityPlural other =
    other ++ "s"
  public export
  addComment : (entity : String) -> (entityId : Nat64Id) -> (text : String) -> (version : Bits32) -> {auto _ : HasIO io} -> io (Either String String)
  addComment entity eid txt ver = do
    let url : _ = buildUrl [entityPlural entity, showId eid] [] env.base
    let body : _ = encode $ MkCommentBody txt ver
    resp <- authPatch env url body
    expectRaw resp 200 "add comment"
