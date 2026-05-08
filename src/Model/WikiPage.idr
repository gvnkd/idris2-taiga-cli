module Model.WikiPage
import JSON.Derive
import Model.Common

%language ElabReflection

public export
record WikiPage where
  constructor MkWikiPage
  id : Nat64Id
  slug : Slug
  content : String
  version : Version

%runElab derive "WikiPage" [Show, Eq, ToJSON, FromJSON]

public export
record WikiPageSummary where
  constructor MkWikiPageSummary
  id : Nat64Id
  slug : Slug

%runElab derive "WikiPageSummary" [Show, Eq, ToJSON, FromJSON]
