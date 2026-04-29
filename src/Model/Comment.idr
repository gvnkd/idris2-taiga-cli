||| Taiga comment / history entry record with FromJSON / ToJSON instances.
module Model.Comment

import JSON.Derive
import Model.Common

%language ElabReflection

||| A comment on any entity (task, story, epic, issue).
public export
record Comment where
  constructor MkComment
  id : Nat64Id
  text : String
  author : Maybe Nat64Id

%runElab derive "Comment" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record CommentSummary where
  constructor MkCommentSummary
  id : Nat64Id
  text : String
  author : Maybe Nat64Id

%runElab derive "CommentSummary" [Show,Eq,ToJSON,FromJSON]
