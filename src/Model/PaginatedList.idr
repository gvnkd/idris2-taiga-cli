||| Paginated list with metadata from Taiga API.
module Model.PaginatedList

import JSON.Derive
import JSON.ToJSON
import JSON.FromJSON
import Data.List

%language ElabReflection

||| Pagination metadata from response headers.
public export
record PaginationMeta where
  constructor MkPaginationMeta
  totalCount  : Maybe Bits64
  currentPage : Maybe Bits32
  nextUrl     : Maybe String
  prevUrl     : Maybe String

%runElab derive "PaginationMeta" [Show,Eq,ToJSON,FromJSON]

||| A paginated list of items.
public export
record PaginatedList a where
  constructor MkPaginatedList
  items      : List a
  pagination : PaginationMeta

||| Extract just the items from a paginated list.
public export
paginatedItems : PaginatedList a -> List a
paginatedItems = (.items)

||| Format pagination info as a one-line summary.
public export
formatPagination : PaginationMeta -> String
formatPagination p =
  let count := fromMaybe 0 p.totalCount
      page  := fromMaybe 1 p.currentPage
   in "Showing " ++ show (length p) ++ " of " ++ show count ++ " items (page " ++ show page ++ ")"
