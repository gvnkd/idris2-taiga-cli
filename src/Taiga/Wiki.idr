||| Wiki page endpoints.
module Taiga.Wiki

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.WikiPage
import Taiga.Api

%language ElabReflection

||| List wiki pages in a project.
public export
listWiki :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List WikiPageSummary))
listWiki = ?rhs_listWiki

||| Get a wiki page by its ID.
public export
getWiki :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String WikiPage)
getWiki = ?rhs_getWiki

||| Create a new wiki page.
public export
createWiki :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (slug : String)
  -> (content : String)
  -> io (Either String WikiPage)
createWiki = ?rhs_createWiki

||| Update an existing wiki page (OCC-aware).
public export
updateWiki :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (content : Maybe String)
  -> (slug : Maybe String)
  -> (version : Version)
  -> io (Either String WikiPage)
updateWiki = ?rhs_updateWiki

||| Delete a wiki page.
public export
deleteWiki :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteWiki = ?rhs_deleteWiki
