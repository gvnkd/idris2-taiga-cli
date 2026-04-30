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

||| --- Show instances (needed before EntityRef derive) ---

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
  show (MkDateTime s) = "DateTime " ++ show s

||| --- Eq instances ---

public export
Eq Nat64Id where
  (MkNat64Id a) == (MkNat64Id b) = a == b

public export
Eq Slug where
  (MkSlug a) == (MkSlug b) = a == b

public export
Eq Version where
  (MkVersion a) == (MkVersion b) = a == b

public export
Eq DateTime where
  (MkDateTime a) == (MkDateTime b) = a == b

||| --- Ord instances ---

public export
Ord Nat64Id where
  compare (MkNat64Id a) (MkNat64Id b) = compare a b

public export
Ord Slug where
  compare (MkSlug a) (MkSlug b) = compare a b

public export
Ord Version where
  compare (MkVersion a) (MkVersion b) = compare a b

||| --- FromJSON: bare integer / string round-trip ---

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

||| --- ToJSON: bare integer / string round-trip ---

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
