||| Taiga comment / history entry record with FromJSON / ToJSON instances.
module Model.Comment

import JSON.Derive
import Model.Common

%language ElabReflection

||| Author info embedded in history entries.
public export
record HistoryAuthor where
  constructor MkHistoryAuthor
  id : Bits64
  username : String
  name : String

%runElab derive "HistoryAuthor" [Show,Eq,ToJSON,FromJSON]

||| A history entry (comment or status change) on any entity.
public export
record HistoryEntry where
  constructor MkHistoryEntry
  id : String
  user : HistoryAuthor
  created_at : String
  comment : String
  status_from : Maybe String
  status_to : Maybe String

%runElab derive "HistoryEntry" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record CommentSummary where
  constructor MkCommentSummary
  id : String
  text : String
  author : String
  created_at : String

%runElab derive "CommentSummary" [Show,Eq,ToJSON,FromJSON]
