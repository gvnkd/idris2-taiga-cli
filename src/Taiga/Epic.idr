||| Epic endpoints and related user stories.
module Taiga.Epic

import JSON.FromJSON
import JSON.ToJSON
import JSON.Encoder
import Model.Common
import Model.Epic
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Request body for creating an epic.
public export
record CreateEpicBody where
  constructor MkCreateEpicBody
  project     : Bits64
  subject     : String
  description : Maybe String
  status      : Maybe Bits64

public export
ToJSON CreateEpicBody where
  toJSON b =
    object $ catMaybes
      [ Just $ jpair "project" b.project
      , Just $ jpair "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "status" b.status
      ]

||| Request body for updating an epic.
public export
record UpdateEpicBody where
  constructor MkUpdateEpicBody
  subject     : Maybe String
  description : Maybe String
  status      : Maybe Bits64
  version     : Version

public export
ToJSON UpdateEpicBody where
  toJSON b =
    object $ catMaybes
      [ omitNothing "subject" b.subject
      , omitNothing "description" b.description
      , omitNothing "status" b.status
      , Just $ jpair "version" b.version
      ]

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
    let body := encode $ MkCreateEpicBody (parseBits64 project) subject desc (map parseBits64 stat)
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
    let body := encode $ MkUpdateEpicBody subj desc (map parseBits64 stat) ver
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
