||| Milestone / sprint endpoints.
module Taiga.Milestone

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Milestone
import Taiga.Api
import Taiga.Env
import Data.List

%language ElabReflection

||| Build a query string from key-value pairs.
public export
buildQueryString : List (String, String) -> String
buildQueryString [] = ""
buildQueryString kvs =
  let pairs := map (\(k, v) => k ++ "=" ++ v) kvs
   in "?" ++ concat (intersperse "&" pairs)

parameters {auto env : ApiEnv}

  ||| List milestones in a project.
  public export
  listMilestones :
       (project : String)
    -> (page : Maybe Bits32)
    -> (pageSize : Maybe Bits32)
    -> {auto _ : HasIO io}
    -> io (Either String (List MilestoneSummary))
  listMilestones project page pageSize = do
    let qs  := buildQueryString $
                  ("project", project) ::
                  catMaybes
                    [ case page of { Nothing => Nothing; Just p => Just ("page", show p) }
                    , case pageSize of { Nothing => Nothing; Just s => Just ("page_size", show s) }
                    ]
        url := env.base ++ "/milestones" ++ qs
    resp <- authGet env url
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right ms  => Right ms
             _     => Left ("list milestones failed with status " ++ show resp.status.code)

  ||| Parse string as Bits64.
  parseBits64 : String -> Bits64
  parseBits64 = cast

  ||| Build JSON body for creating a milestone.
  buildCreateMilestoneBody : String -> String -> String -> String -> String
  buildCreateMilestoneBody project name estStart estFinish =
    "{\"project\":" ++ show (parseBits64 project) ++
    ",\"name\":" ++ encode name ++
    ",\"estimated_start\":" ++ encode estStart ++
    ",\"estimated_finish\":" ++ encode estFinish ++ "}"

  ||| Create a new milestone.
  public export
  createMilestone :
       (project : String)
    -> (name : String)
    -> (estimatedStart : String)
    -> (estimatedFinish : String)
    -> {auto _ : HasIO io}
    -> io (Either String Milestone)
  createMilestone project name estStart estFinish = do
    let body := buildCreateMilestoneBody project name estStart estFinish
    resp <- authPost env (env.base ++ "/milestones") body
    pure $ case resp.status.code of
             201 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right m   => Right m
             _     => Left ("create milestone failed with status " ++ show resp.status.code)

  ||| Build JSON body for updating a milestone.
  buildUpdateMilestoneBody :
       Maybe String -> Maybe String -> Maybe String -> Version -> String
  buildUpdateMilestoneBody name estStart estFinish ver =
    "{" ++ concat fields ++ ",\"version\":" ++ show ver.version ++ "}"
    where
      fields : List String
      fields = catMaybes
        [ case name      of { Nothing => Nothing; Just s => Just (",\"name\":" ++ encode s) }
        , case estStart  of { Nothing => Nothing; Just s => Just (",\"estimated_start\":" ++ encode s) }
        , case estFinish of { Nothing => Nothing; Just s => Just (",\"estimated_finish\":" ++ encode s) }
        ]

  ||| Update an existing milestone (OCC-aware).
  public export
  updateMilestone :
       (id : Nat64Id)
    -> (name : Maybe String)
    -> (estimatedStart : Maybe String)
    -> (estimatedFinish : Maybe String)
    -> (version : Version)
    -> {auto _ : HasIO io}
    -> io (Either String Milestone)
  updateMilestone id name estStart estFinish ver = do
    let body := buildUpdateMilestoneBody name estStart estFinish ver
    resp <- authPut env (env.base ++ "/milestones/" ++ show id.id) body
    pure $ case resp.status.code of
             200 => case decodeEither resp.body of
                      Left  err  => Left err
                      Right m   => Right m
             _     => Left ("update milestone failed with status " ++ show resp.status.code)