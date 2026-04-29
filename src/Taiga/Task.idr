||| Task endpoints.
module Taiga.Task

import JSON.FromJSON
import JSON.ToJSON
import Model.Common
import Model.Task
import Taiga.Api

%language ElabReflection

||| List tasks in a project or belonging to a story.
listTasks :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : Maybe String)
  -> (story : Maybe Nat64Id)
  -> (page : Maybe Bits32)
  -> (pageSize : Maybe Bits32)
  -> io (Either String (List TaskSummary))
listTasks = ?rhs_listTasks

||| Get a task by its ID.
getTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String Task)
getTask = ?rhs_getTask

||| Create a new task.
createTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (project : String)
  -> (subject : String)
  -> (story : Maybe Nat64Id)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> io (Either String Task)
createTask = ?rhs_createTask

||| Update an existing task (OCC-aware).
updateTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> (subject : Maybe String)
  -> (description : Maybe String)
  -> (status : Maybe String)
  -> (version : Version)
  -> io (Either String Task)
updateTask = ?rhs_updateTask

||| Delete a task.
deleteTask :
     HasIO io
  => (base : String)
  -> (token : String)
  -> (id : Nat64Id)
  -> io (Either String ())
deleteTask = ?rhs_deleteTask
