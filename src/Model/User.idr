||| Taiga user record with FromJSON / ToJSON instances.
module Model.User

import JSON.Derive
import Model.Common

%language ElabReflection

||| A Taiga user.
public export
record User where
  constructor MkUser
  id : Nat64Id
  username : String
  full_name : String
  email : String

%runElab derive "User" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record UserSummary where
  constructor MkUserSummary
  id : Nat64Id
  username : String

%runElab derive "UserSummary" [Show,Eq,ToJSON,FromJSON]

||| Membership record from /memberships endpoint.
public export
record Membership where
  constructor MkMembership
  id : Nat64Id
  user : Bits64
  project : Bits64
  role : Bits64
  is_admin : Bool
  full_name : String
  email : String

%runElab derive "Membership" [Show,Eq,ToJSON,FromJSON]

||| Role record from /roles endpoint.
public export
record Role where
  constructor MkRole
  id : Nat64Id
  name : String
  slug : String
  project : Bits64

%runElab derive "Role" [Show,Eq,ToJSON,FromJSON]
