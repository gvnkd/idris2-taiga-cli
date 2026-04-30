||| Epic endpoints and related user stories.
module Taiga.Epic

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Epic
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Format a description field for JSON.
public export
formatEpicDesc : Maybe String -> String
formatEpicDesc Nothing  = ""
formatEpicDesc (Just d) = ",\"description\":" ++ encode d

||| Format a status field for JSON.
public export
formatEpicStatus : Maybe String -> String
formatEpicStatus Nothing  = ""
formatEpicStatus (Just s) = ",\"status\":" ++ show (parseBits64 s)

||| Build JSON body for creating an epic.
buildCreateEpicBody :
     (project : String)
  -> (subject : String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> String
buildCreateEpicBody project subject desc stat =
  "{\"project\":" ++ show (parseBits64 project) ++
  ",\"subject\":" ++ encode subject ++
  formatEpicDesc desc ++
  formatEpicStatus stat ++ "}"

||| Build JSON body for updating an epic.
buildUpdateEpicBody :
     (subject : Maybe String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> (version : Version)
  -> String
buildUpdateEpicBody subj desc stat ver =
  "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"
  where
    fields : List String
    fields = catMaybes
      [ map (\s => "\"subject\":" ++ encode s) subj
      , map (\d => "\"description\":" ++ encode d) desc
      , map (\s => "\"status\":" ++ show (parseBits64 s)) stat
      ]
    joined : String
    joined = concat $ intersperse "," fields

parameters {auto env : ApiEnv}

  ||| List epics in a project.
  public export
  listEpics :
       (project : String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List EpicSummary))
  listEpics project page pageSize = do
    let qs  := buildQueryString $
                  ("project", project) ::
                  catMaybes
                    [ map (\p => ("page", show p)) page
                    , map (\s => ("page_size", show s)) pageSize
                    ]
        url := env.base ++ "/epics" ++ qs
    resp <- authGet env url
    expectJson resp 200 "list epics"

  ||| Get an epic by its ID.
  public export
  getEpic :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Epic)
  getEpic id = do
    let url := env.base ++ "/epics/" ++ show id.id
    resp <- authGet env url
    expectJson resp 200 "get epic"

  ||| Create a new epic.
  public export
  createEpic :
       (project : String)
    -> (subject : String)
    -> (description : Maybe String)
    -> (status : Maybe String)
    -> {auto _ : HasIO io}
    -> io (Either String Epic)
  createEpic project subject desc stat = do
    let body := buildCreateEpicBody project subject desc stat
    resp <- authPost env (env.base ++ "/epics") body
    expectJson resp 201 "create epic"

  ||| Update an existing epic (OCC-aware).
  public export
  updateEpic :
       (id : Nat64Id)
    -> (subject : Maybe String)
    -> (description : Maybe String)
    -> (status : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String Epic)
  updateEpic id subj desc stat ver = do
    let body := buildUpdateEpicBody subj desc stat ver
    resp <- authPatch env (env.base ++ "/epics/" ++ show id.id) body
    expectJson resp 200 "update epic"

  ||| Delete an epic.
  public export
  deleteEpic :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteEpic id = do
    let url := env.base ++ "/epics/" ++ show id.id
    resp <- authDelete env url
    expectOk resp 204 "delete epic"
