module Model.Common
import JSON.Derive
import JSON.FromJSON
import JSON.ToJSON
import Data.SortedMap
import Data.List

%language ElabReflection

public export
record Nat64Id where
  constructor MkNat64Id
  id : Bits64

public export
record Slug where
  constructor MkSlug
  slug : String

public export
record Version where
  constructor MkVersion
  version : Bits32

public export
record DateTime where
  constructor MkDateTime
  dateTime : String

%runElab derive "Nat64Id" [Eq, Ord]

%runElab derive "Slug" [Eq, Ord]

%runElab derive "Version" [Eq, Ord]

%runElab derive "DateTime" [Eq, Ord]

public export
implementation Show Nat64Id where
  show (MkNat64Id n) =
    "Nat64Id " ++ show n

public export
implementation Show Slug where
  show (MkSlug s) =
    "Slug " ++ show s

public export
implementation Show Version where
  show (MkVersion n) =
    "Version " ++ show n

public export
implementation Show DateTime where
  show (MkDateTime s) =
    s

public export
implementation FromJSON Nat64Id where
  fromJSON =
    withInteger "Nat64Id" $ (\n => pure $ MkNat64Id $ cast n)

public export
implementation FromJSON Slug where
  fromJSON =
    withString "Slug" $ (\s => pure $ MkSlug s)

public export
implementation FromJSON Version where
  fromJSON =
    withInteger "Version" $ (\n => pure $ MkVersion $ cast n)

public export
implementation FromJSON DateTime where
  fromJSON =
    withString "DateTime" $ (\s => pure $ MkDateTime s)

public export
implementation ToJSON Nat64Id where
  (toJSON {v = v}) (MkNat64Id n) =
    integer $ cast n

public export
implementation ToJSON Slug where
  (toJSON {v = v}) (MkSlug s) =
    string s

public export
implementation ToJSON Version where
  (toJSON {v = v}) (MkVersion n) =
    integer $ cast n

public export
implementation ToJSON DateTime where
  (toJSON {v = v}) (MkDateTime s) =
    string s

public export
record EntityRef where
  constructor MkEntityRef
  id : Nat64Id
  subject : String

%runElab derive "EntityRef" [Show, Eq, ToJSON, FromJSON]

public export
data EntityKind : Type where
  TaskK : EntityKind
  IssueK : EntityKind
  StoryK : EntityKind
  EpicK : EntityKind
  WikiK : EntityKind
  MilestoneK : EntityKind

public export
parseEntityKind : String -> Maybe EntityKind
parseEntityKind "task" =
  Just TaskK
parseEntityKind "issue" =
  Just IssueK
parseEntityKind "story" =
  Just StoryK
parseEntityKind "epic" =
  Just EpicK
parseEntityKind "wiki" =
  Just WikiK
parseEntityKind "milestone" =
  Just MilestoneK
parseEntityKind "sprint" =
  Just MilestoneK
parseEntityKind _ =
  Nothing

public export
resolverKey : EntityKind -> String
resolverKey TaskK =
  "task"
resolverKey IssueK =
  "issue"
resolverKey StoryK =
  "us"
resolverKey EpicK =
  "epic"
resolverKey WikiK =
  "wiki"
resolverKey MilestoneK =
  "milestone"

public export
apiEntityName : EntityKind -> String
apiEntityName TaskK =
  "task"
apiEntityName IssueK =
  "issue"
apiEntityName StoryK =
  "userstory"
apiEntityName WikiK =
  "wiki"
apiEntityName MilestoneK =
  "milestone"
apiEntityName EpicK =
  "epic"

public export
entityTypeName : EntityKind -> String
entityTypeName TaskK =
  "Task"
entityTypeName IssueK =
  "Issue"
entityTypeName StoryK =
  "Story"
entityTypeName EpicK =
  "Epic"
entityTypeName WikiK =
  "Wiki"
entityTypeName MilestoneK =
  "Sprint"

public export
record ResolveResponse where
  constructor MkResolveResponse
  project : Maybe Bits64
  task : Maybe Bits64
  issue : Maybe Bits64
  us : Maybe Bits64
  wiki : Maybe Bits64
  milestone : Maybe Bits64
  epic : Maybe Bits64

%runElab derive "ResolveResponse" [Show, Eq, ToJSON]

public export
implementation FromJSON ResolveResponse where
  fromJSON =
    withObject "ResolveResponse" $ (\o => [|MkResolveResponse (fieldMaybe o "project") (fieldMaybe o "task") (fieldMaybe o "issue") (fieldMaybe o "us") (fieldMaybe o "wiki") (fieldMaybe o "milestone") (fieldMaybe o "epic")|])

public export
extractEntityFromResolve : ResolveResponse -> Maybe (String, Nat64Id)
extractEntityFromResolve r =
  head' $ catMaybes [("task",) <$> map MkNat64Id r.task, ("issue",) <$> map MkNat64Id r.issue, ("us",) <$> map MkNat64Id r.us, ("wiki",) <$> map MkNat64Id r.wiki, ("milestone",) <$> map MkNat64Id r.milestone, ("epic",) <$> map MkNat64Id r.epic]

public export
readNat : String -> Maybe Bits64
readNat s =
  let n = (cast {to = Integer}) s in if s == "0"
                                       then Just 0
                                         else
                                           if n == 0
                                             then Nothing
                                               else
                                                 if n < 0
                                                   then Nothing
                                                     else
                                                       Just $ cast n
