||| Shared types used across the data model: entity IDs, slugs,
||| optimistic-concurrency versions, and date-time strings.
module Model.Common

import JSON.Derive
import Data.SortedMap

%language ElabReflection

||| Stable identifier for every Taiga entity.
public export
record Nat64Id where
  constructor MkNat64Id
  id : Bits64

%runElab derive "Nat64Id" [Show,Eq,Ord,ToJSON,FromJSON]

||| URL-safe unique identifier.
public export
record Slug where
  constructor MkSlug
  slug : String

%runElab derive "Slug" [Show,Eq,Ord,ToJSON,FromJSON]

||| Optimistic-concurrency version counter.
public export
record Version where
  constructor MkVersion
  version : Bits32

%runElab derive "Version" [Show,Eq,Ord,ToJSON,FromJSON]

||| ISO-8601 date-time string as returned by the Taiga API.
public export
record DateTime where
  constructor MkDateTime
  dateTime : String

%runElab derive "DateTime" [Show,Eq,ToJSON,FromJSON]

||| A generic reference to an entity by its numeric ID.
public export
record EntityRef where
  constructor MkEntityRef
  id : Nat64Id
  subject : String

%runElab derive "EntityRef" [Show,Eq,ToJSON,FromJSON]
