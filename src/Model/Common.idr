||| Shared types used across the data model: entity IDs, slugs,
||| optimistic-concurrency versions, and date-time strings.
module Model.Common

import JSON.Derive
import JSON.FromJSON
import JSON.ToJSON
import Data.SortedMap

%language ElabReflection

||| Stable identifier for every Taiga entity.
public export
record Nat64Id where
  constructor MkNat64Id
  id : Bits64

||| URL-safe unique identifier.
public export
record Slug where
  constructor MkSlug
  slug : String

||| Optimistic-concurrency version counter.
public export
record Version where
  constructor MkVersion
  version : Bits32

||| ISO-8601 date-time string as returned by the Taiga API.
public export
record DateTime where
  constructor MkDateTime
  dateTime : String

%runElab derive "Nat64Id" [Eq, Ord]
%runElab derive "Slug" [Eq, Ord]
%runElab derive "Version" [Eq, Ord]
%runElab derive "DateTime" [Eq, Ord]

||| Human-readable display for common wrapper types.
public export
Show Nat64Id where
  show (MkNat64Id n) = "Nat64Id " ++ show n

public export
Show Slug where
  show (MkSlug s) = "Slug " ++ show s

public export
Show Version where
  show (MkVersion n) = "Version " ++ show n

public export
Show DateTime where
  show (MkDateTime s) = s

||| Deserialize common types as bare JSON values.
public export
FromJSON Nat64Id where
  fromJSON = withInteger "Nat64Id" $ \n => pure $ MkNat64Id $ cast n

public export
FromJSON Slug where
  fromJSON = withString "Slug" $ \s => pure $ MkSlug s

public export
FromJSON Version where
  fromJSON = withInteger "Version" $ \n => pure $ MkVersion $ cast n

public export
FromJSON DateTime where
  fromJSON = withString "DateTime" $ \s => pure $ MkDateTime s

||| Serialize common types as bare JSON values.
public export
ToJSON Nat64Id where
  toJSON {v} (MkNat64Id n) = integer $ cast n

public export
ToJSON Slug where
  toJSON {v} (MkSlug s) = string s

public export
ToJSON Version where
  toJSON {v} (MkVersion n) = integer $ cast n

public export
ToJSON DateTime where
  toJSON {v} (MkDateTime s) = string s

||| A generic reference to an entity by its numeric ID.
public export
record EntityRef where
  constructor MkEntityRef
  id : Nat64Id
  subject : String

%runElab derive "EntityRef" [Show,Eq,ToJSON,FromJSON]

||| Tagged entity kinds for total dispatch.
public export
data EntityKind
  = TaskK
  | IssueK
  | StoryK
  | EpicK
  | WikiK
  | MilestoneK

||| Map a user-friendly entity name to an EntityKind.
public export
parseEntityKind : String -> Maybe EntityKind
parseEntityKind "task"      = Just TaskK
parseEntityKind "issue"     = Just IssueK
parseEntityKind "story"     = Just StoryK
parseEntityKind "epic"      = Just EpicK
parseEntityKind "wiki"      = Just WikiK
parseEntityKind "milestone" = Just MilestoneK
parseEntityKind "sprint"    = Just MilestoneK
parseEntityKind _           = Nothing

||| Resolver API key for an entity kind.
public export
resolverKey : EntityKind -> String
resolverKey TaskK      = "task"
resolverKey IssueK     = "issue"
resolverKey StoryK     = "us"
resolverKey EpicK      = "epic"
resolverKey WikiK      = "wiki"
resolverKey MilestoneK = "milestone"

||| API entity name for an entity kind.
public export
apiEntityName : EntityKind -> String
apiEntityName TaskK      = "task"
apiEntityName IssueK     = "issue"
apiEntityName StoryK     = "userstory"
apiEntityName WikiK      = "wiki"
apiEntityName MilestoneK = "milestone"
apiEntityName EpicK      = "epic"

||| Response from the Taiga resolver endpoint.
public export
record ResolveResponse where
  constructor MkResolveResponse
  project   : Maybe Bits64
  task      : Maybe Bits64
  issue     : Maybe Bits64
  us        : Maybe Bits64
  wiki      : Maybe Bits64
  milestone : Maybe Bits64
  epic      : Maybe Bits64

%runElab derive "ResolveResponse" [Show,Eq,ToJSON]

||| Custom FromJSON: the resolver API omits absent fields instead of
||| returning null, so we must treat missing keys as Nothing.
public export
FromJSON ResolveResponse where
  fromJSON =
    withObject "ResolveResponse" $ \o =>
      [| MkResolveResponse
           (fieldMaybe o "project")
           (fieldMaybe o "task")
           (fieldMaybe o "issue")
           (fieldMaybe o "us")
           (fieldMaybe o "wiki")
           (fieldMaybe o "milestone")
           (fieldMaybe o "epic")
      |]

||| Extract the first non-project entity ID from a resolver response.
||| Keys must match `resolverKey` for each EntityKind.
public export
extractEntityFromResolve : ResolveResponse -> Maybe (String, Nat64Id)
extractEntityFromResolve r =
  go
    [ ("task",)      <$> map MkNat64Id r.task
    , ("issue",)     <$> map MkNat64Id r.issue
    , ("us",)        <$> map MkNat64Id r.us
    , ("wiki",)      <$> map MkNat64Id r.wiki
    , ("milestone",) <$> map MkNat64Id r.milestone
    , ("epic",)      <$> map MkNat64Id r.epic
    ]
  where
    go : List (Maybe (String, Nat64Id)) -> Maybe (String, Nat64Id)
    go [] = Nothing
    go (Just p :: _) = Just p
    go (Nothing :: ps) = go ps

||| Attempt to parse a string as Bits64.
||| Returns Nothing on invalid input.
public export
readNat : String -> Maybe Bits64
readNat s =
  let n := cast {to = Integer} s in
  if s == "0" then Just 0
  else if n == 0 then Nothing
  else if n < 0 then Nothing
  else Just $ cast n
