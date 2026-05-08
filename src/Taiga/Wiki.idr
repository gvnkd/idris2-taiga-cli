module Taiga.Wiki
import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.WikiPage
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

public export
record CreateWikiBody where
  constructor MkCreateWikiBody
  project : Bits64
  slug : String
  content : String

public export
implementation ToJSON CreateWikiBody where
  toJSON b =
    object [jpair "project" b.project, jpair "slug" b.slug, jpair "content" b.content]

public export
record UpdateWikiBody where
  constructor MkUpdateWikiBody
  content : Maybe String
  slug : Maybe String
  version : Version

public export
implementation ToJSON UpdateWikiBody where
  toJSON b =
    object $ catMaybes [omitNothing "content" b.content, omitNothing "slug" b.slug, Just $ jpair "version" b.version]

parameters {auto env : ApiEnv}
  public export
  listWiki : (project : Maybe String) -> (page : Maybe Bits32) -> (pageSize : Maybe Bits32) -> {auto _ : HasIO io} -> io (Either String (List WikiPageSummary, PaginationMeta))
  listWiki mproject page pageSize = do
    let opts : _ = concat $ catMaybes [map (\p => [("page", show p)]) page, map (\s => [("page_size", show s)]) pageSize, map (\p => [("project__id", p)]) mproject]
    let url : _ = buildUrl ["wiki"] opts env.base
    resp <- authGet env url
    expectJsonWithMeta resp 200 "list wiki"
  public export
  getWiki : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String WikiPage)
  getWiki id = do
    let errMsg : _ = "wiki page #" ++ showId id
    let url : _ = buildUrl ["wiki", showId id] [] env.base
    resp <- authGet env url
    expectJson resp 200 errMsg
  public export
  createWiki : (project : String) -> (slug : String) -> (content : String) -> {auto _ : HasIO io} -> io (Either String WikiPage)
  createWiki project slug content = do
    let body : _ = encode $ MkCreateWikiBody (parseBits64 project) slug content
    let url : _ = buildUrl ["wiki"] [] env.base
    resp <- authPost env url body
    expectJson resp 201 "create wiki"
  public export
  updateWiki : (id : Nat64Id) -> (content : Maybe String) -> (slug : Maybe String) -> (version : Version) -> {auto _ : HasIO io} -> io (Either String WikiPage)
  updateWiki id content slug ver = do
    let errMsg : _ = "wiki page #" ++ showId id
    let body : _ = encode $ MkUpdateWikiBody content slug ver
    let url : _ = buildUrl ["wiki", showId id] [] env.base
    resp <- authPatch env url body
    expectJson resp 200 errMsg
  public export
  deleteWiki : (id : Nat64Id) -> {auto _ : HasIO io} -> io (Either String ())
  deleteWiki id = do
    let errMsg : _ = "wiki page #" ++ showId id
    let url : _ = buildUrl ["wiki", showId id] [] env.base
    resp <- authDelete env url
    expectOk resp 204 errMsg
