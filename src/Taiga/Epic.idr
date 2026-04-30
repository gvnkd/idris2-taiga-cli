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
formatEpicDesc : Maybe String -> String
formatEpicDesc Nothing  = ""
formatEpicDesc (Just d) = ",\"description\":" ++ encode d

||| Format a status field for JSON.
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
      [ case subj of { Nothing => Nothing; Just s => Just ("\"subject\":" ++ encode s) }
      , case desc of { Nothing => Nothing; Just d => Just ("\"description\":" ++ encode d) }
      , case stat of { Nothing => Nothing; Just s => Just ("\"status\":" ++ show (parseBits64 s)) }
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
                    [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                    , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                    ]
        url := env.base ++ "/epics" ++ qs
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right es  => Right es
             _     => Left ("list epics failed with status " ++ show resp.status.code)

  ||| Get an epic by its ID.
  public export
  getEpic :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String Epic)
  getEpic id = do
    let url := env.base ++ "/epics/" ++ show id.id
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right e   => Right e
             _     => Left ("get epic failed with status " ++ show resp.status.code)

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
    pure $ case resp.status.code of
             201 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right e   => Right e
             _     => Left ("create epic failed with status " ++ show resp.status.code)

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
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right e   => Right e
             _     => Left ("update epic failed with status " ++ show resp.status.code)

  ||| Delete an epic.
  public export
  deleteEpic :
       (id : Nat64Id)
    -> {auto _ : HasIO io}
    -> io (Either String ())
  deleteEpic id = do
    let url := env.base ++ "/epics/" ++ show id.id
    resp <- authDelete env url
    pure $ case resp.status.code of
             204 => Right ()
             _     => Left ("delete epic failed with status " ++ show resp.status.code)
