||| Comment (history) endpoints.
module Taiga.History

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Comment
import Taiga.Api

%language ElabReflection

||| Add a comment to an entity (task, story, epic, or issue).
addComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> (text : String)
  -> io (Either String Comment)
addComment = ?rhs_addComment

||| Edit an existing comment.
editComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> (commentId : Nat64Id)
  -> (text : String)
  -> io (Either String Comment)
editComment = ?rhs_editComment

||| Delete a comment.
deleteComment :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (entity : String)
  -> (entityId : Nat64Id)
  -> (commentId : Nat64Id)
  -> io (Either String ())
deleteComment = ?rhs_deleteComment
