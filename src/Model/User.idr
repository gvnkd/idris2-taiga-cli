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
  fullName : String
  email : String

%runElab derive "User" [Show,Eq,ToJSON,FromJSON]

||| Compact serialisation for list responses.
public export
record UserSummary where
  constructor MkUserSummary
  id : Nat64Id
  username : String

%runElab derive "UserSummary" [Show,Eq,ToJSON,FromJSON]
