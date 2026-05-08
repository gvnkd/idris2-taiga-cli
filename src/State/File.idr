module State.File
import System
import System.Directory
import System.File
import System.File.ReadWrite
import System.File.Meta
import Data.String
import Data.List
import Data.List1
import JSON.ToJSON
import JSON.FromJSON

%language ElabReflection

public export
data Store : Type where
  WorkspaceStore : Store
  GlobalAuthStore : Store
  GlobalConfigStore : Store

storeDir : Store -> String
storeDir WorkspaceStore =
  "./.taiga"
storeDir GlobalAuthStore =
  "~/.local/share/taiga-cli/tokens"
storeDir GlobalConfigStore =
  "~/.local/share/taiga-cli"

resolvePath : String -> IO String
resolvePath path =
  if isPrefixOf "~/" path
    then do
           home <- getEnv "HOME"
           pure $ (case home of
                     Nothing => path
                     Just home' => home' ++ (substr 1 (minus (length path) 1) path))
    else
      pure path

public export
ensureDir : Store -> IO ()
ensureDir store =
  do
    dir <- resolvePath (storeDir store)
    ensureDir' dir
  where
    endsWithSlash : String -> Bool
    endsWithSlash str =
      let len = length str in if len == 0
                                then False
                                  else
                                    substr (minus len 1) len str == "/"
    joinPath : List String -> String
    joinPath [] =
      "."
    joinPath [x] =
      x
    joinPath (x :: xs) =
      x ++ "/" ++ joinPath xs
    parentDir : String -> String
    parentDir path =
      let trimmed = trim path in let noSlash = if endsWithSlash trimmed
                                                 then trim (substr 0 (minus (length trimmed) 1) trimmed)
                                                   else
                                                     trimmed in let parts = forget $ split (== '/') noSlash in case parts of
                                                                                                                                                             [] => "."
                                                                                                                                                             [_] => "."
                                                                                                                                                             (x :: xs) => let initParts = init (x :: xs) in joinPath initParts
    ensureDir' : String -> IO ()
    ensureDir' path = do
      ok <- exists path
      if ok
        then pure ()
          else
            do
              let par : _ = parentDir path
              if par == path || par == "." || par == ""
                then pure ()
                  else
                    ensureDir' par
              Right () <- createDir path
              | Left _ => pure ()
              pure ()

public export
storePath : Store -> String -> IO String
storePath store name = do
  dir <- resolvePath (storeDir store)
  pure $ dir ++ "/" ++ name ++ ".json"

public export
load : FromJSON a => Store -> String -> IO (Maybe a)
load store name = do
  path <- storePath store name
  ok <- exists path
  if not ok
    then pure Nothing
      else
        do
          result <- readFile path
          case result of
            Left _ => pure Nothing
            Right txt => case decodeEither txt of
                           Left _ => pure Nothing
                           Right val => pure $ Just val

public export
save : ToJSON a => Store -> String -> a -> IO ()
save store name val = do
  ensureDir store
  path <- storePath store name
  Right () <- writeFile path (encode val)
  | Left _ => pure ()
  pure ()

public export
removeFile' : Store -> String -> IO ()
removeFile' store name = do
  path <- storePath store name
  ok <- exists path
  if ok
    then do
           Right () <- removeFile path
           | Left _ => pure ()
           pure ()
      else
        pure ()
