#!/usr/bin/env stack
{-
   stack
   --resolver lts-14.8
   --install-ghc
   script
   --package megaparsec
   --package rainbow
   --package typed-process
   --package bytestring
   --package conduit
   --package conduit-extra
   --package stringsearch
   --package errors
   --package aeson
   --package aeson-utils
   --package vector
-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

import System.Environment
import Text.Megaparsec hiding (chunk)
import Text.Megaparsec.Char
import Text.Megaparsec.Byte.Lexer
import Data.Void
import Rainbow
import System.Process.Typed
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BLC
import Control.Monad
import Text.Printf
import Data.Conduit ((.|))
import qualified Conduit as C
import qualified Data.Conduit.Process.Typed as C
import qualified Data.ByteString.Search as Search
import Control.Error.Util ((?:))
import Data.Aeson
import Data.Aeson.Utils (fromFloatDigits)
import qualified Data.Vector as V
import Data.Either

type Parser = Parsec Void B.ByteString

repo :: String
repo = "github.com/moby/moby"

gitDir :: String
gitDir = "/Users/chrismwendt/.sourcegraph/repos/github.com/moby/moby/.git"

-- insert into lsif_dumps (repository, commit) values ('github.com/moby/moby', '28b645755a6bbfd26dac73d9cb7200394828f47d');
targetCommit :: String
targetCommit = "28b645755a6bbfd26dac73d9cb7200394828f47d"

currentCommit :: String
currentCommit = "8d588d9c5b5cd019e09bcfc4f790eae79405c7b1"

-- each line is a JSON array [,,] with 3 elements:
-- - distance from target (starts at 0, increases by 1 for each line)
-- - old query response time
-- - new query response time
perfFile :: String
perfFile = "perf.txt" :: String

gitLogCmd = shell $ printf "git --git-dir=%s log --pretty=%%H --first-parent %s" gitDir targetCommit

templateFiles :: [String]
templateFiles = tail
  [ ""
  -- , "quadratic.sql"
  -- , "slow-linear.sql"
  -- , "fast-bounded.sql"
  , "fast-linear.sql"
  , "fast-linear-closest-dump.sql"
  -- , "fast-linear-row-number.sql"
  -- , "fast-linear-flood.sql"
  ]

-- maxN :: [(String, Int)]
-- maxN =
--   [ ("quadratic.sql", 3)
--   , ("slow-linear.sql", 100)
--   ]

main :: IO ()
main = do
  templates <- mapM B.readFile templateFiles

  runProcess_ (shell $ printf "gtruncate --size 0 %s" perfFile)
  process <- startProcess (setStdout C.createSource gitLogCmd)

  let
    loop = C.await >>= \case
      Nothing -> return ()
      Just params@(n, _) -> do
        C.liftIO $ putStrLn $ "Distance: " ++ show n
        C.liftIO (partitionEithers <$> mapM (perf params) templates) >>= \case
          ([], successes) -> C.liftIO (logTiming n successes) >> loop
          (failures, _) -> C.liftIO $ mapM_ (\(query, lines) -> BC.putStrLn query >> mapM_ BLC.putStrLn lines) failures

  C.runConduit $
    getStdout process
    .| C.linesUnboundedAsciiC
    .| withIndexC
    .| loop

  stopProcess process

  putStrLn "Done."

perf (n, commit) queryTemplate = do
  let
    strictReplace pat sub text = BL.toStrict $ pat `Search.replace` sub $ text
    instantiate = foldr (.) id
      [ "$repo" `strictReplace` (BC.pack repo)
      , "$commit" `strictReplace` commit
      ]
    query = instantiate queryTemplate
    stdin = byteStringInput (BL.fromStrict query)
  runProcess_ (shell "cat fn.sql | psql")
  runProcess_ (shell "psql -c \"insert into lsif_dumps (repository, commit) values ('github.com/moby/moby', '28b645755a6bbfd26dac73d9cb7200394828f47d') ON CONFLICT (repository, commit, root) DO NOTHING\"")
  (out, err) <- readProcess_ (setStdin stdin $ shell "psql -AtX")
  -- parseTest ("Time: " >> decimal :: Parser Int) "" (BLC.toStrict time) of
  if (err /= "")
    then return $ Left (BL.toStrict err, [])
    else case BLC.lines out of
      results@[_, result, time] -> if (" " `BLC.stripPrefix` result ?: result) /= BLC.pack targetCommit
        then return $ Left (query, results)
        else case parse ("Time: " >> decimal :: Parser Int) "" (BLC.toStrict time) of
          Left e -> do
            print (errorBundlePretty e)
            return $ Left (query, results)
          Right v -> return $ Right v
      lines -> return $ Left (query, lines)

      -- Right _chunk -> do
      --   putChunkLn $ chunk ("---------------------------------------------------------------------------" :: String) & faint

logTiming :: Int -> [Int] -> IO ()
logTiming n times = BL.appendFile "perf.txt"
  $ (`BLC.snoc` '\n')
  $ encode
  $ Array . V.fromList
  $ toNumber n : map (\time -> toNumber time) times

toNumber :: Int -> Value
toNumber a = Number $ fromFloatDigits $ (fromIntegral a :: Float)

withIndexC = void (C.mapAccumWhileC (\a s -> Right (s + 1, (s, a))) (0 :: Int))
