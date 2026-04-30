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
                    [ map (\p => ("page", show p)) page
                    , map (\s => ("page_size", show s)) pageSize
                    ]
        url := env.base ++ "/milestones" ++ qs
    resp <- authGet env url
    expectJson resp 200 "list milestones"

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
    expectJson resp 201 "create milestone"

  ||| Build JSON body for updating a milestone.
  buildUpdateMilestoneBody :
       Maybe String -> Maybe String -> Maybe String -> Version -> String
  buildUpdateMilestoneBody name estStart estFinish ver =
    "{" ++ joined ++ ",\"version\":" ++ show ver.version ++ "}"
    where
      fields : List String
      fields = catMaybes
        [ map (\s => "\"name\":" ++ encode s) name
        , map (\s => "\"estimated_start\":" ++ encode s) estStart
        , map (\s => "\"estimated_finish\":" ++ encode s) estFinish
        ]
      joined : String
      joined = concat $ intersperse "," fields

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
    resp <- authPatch env (env.base ++ "/milestones/" ++ show id.id) body
    expectJson resp 200 "update milestone"