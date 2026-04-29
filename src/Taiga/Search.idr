||| Resolver and search endpoints.
module Taiga.Search

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Taiga.Api

%language ElabReflection

||| Global search within a project.
search :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (text : String)
  -> io (Either String String)
search = ?rhs_search

||| Resolve an entity by its slug or ref.
resolve :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (ref : String)
  -> io (Either String String)
resolve = ?rhs_resolve
