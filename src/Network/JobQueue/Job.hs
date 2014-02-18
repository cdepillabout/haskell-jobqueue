-- Copyright (c) Gree, Inc. 2013
-- License: MIT-style

module Network.JobQueue.Job (
    Job(jobState, jobUnit, jobCTime, jobOnTime, jobId, jobGroup, jobPriority, StopTheWorld)
  , JobState(..)
  , process
  , createJob
  , createOnTimeJob
  , createStopTheWorld
  , createOnTimeStopTheWorld
  , printJob
  , module Network.JobQueue.Types
  , module Network.JobQueue.Action
  ) where

--module Network.JobQueue.Job where

import Control.Monad.State hiding (state)

import Data.Time.Clock
import System.Log.Logger
import System.IO

import Network.JobQueue.Class
import Network.JobQueue.Types
import Network.JobQueue.Action

data JobState = Initialized | Runnable | Running | Aborted | Finished
  deriving (Show, Read, Eq)

{- | Job control block
Job consists of /State/, /Unit/, /CTime/, /OnTime/, /Id/, /Group/, and /Priority/.

- State - takes one of 5 states (initialized, runnable, running, aborted and finished)

- Unit - an instance of Unit class, which is specified by type parameter of Job data type

- CTime - creation time

- OnTime - the time at which this job starts

- Id - Identifier of this job

- Group - Group ID of this job

- Priority - the priority of this job

-}
data Job a =
    Job {
      jobState    :: JobState
    , jobUnit     :: a
    , jobCTime    :: UTCTime
    , jobOnTime   :: UTCTime
    , jobId       :: Int
    , jobGroup    :: Int
    , jobPriority :: Int }
  | StopTheWorld {
      jobCTime    :: UTCTime
    , jobOnTime   :: UTCTime }
  deriving (Show, Read)

--------------------------------

{- | Declare a function which accepts a unit and execute the action of it if possible.
-}
process :: (Env e, Unit a) => (a -> ActionM e a ()) -> JobM e a ()
process action = modify $ addAction $ eval action

eval :: (Env e, Unit a) => (a -> ActionM e a ()) -> ActionFn e a
eval action env ju = runAction env ju (action ju)

--------------------------------

createJob :: (Unit a) => JobState -> a -> IO (Job a)
createJob state unit = do
  ctime <- getCurrentTime
  return (Job state unit ctime ctime (defaultId) (defaultGroup) (getPriority unit))

createOnTimeJob :: (Unit a) => JobState -> UTCTime -> a -> IO (Job a)
createOnTimeJob state ontime unit = do
  ctime <- getCurrentTime
  return (Job state unit ctime ontime (defaultId) (defaultGroup) (getPriority unit))

createStopTheWorld :: IO (Job a)
createStopTheWorld = do
  ctime <- getCurrentTime
  return (StopTheWorld ctime ctime)

createOnTimeStopTheWorld :: UTCTime -> IO (Job a)
createOnTimeStopTheWorld ontime = do
  ctime <- getCurrentTime
  return (StopTheWorld ctime ontime)

printJob :: (Unit a) => Job a -> IO ()
printJob job = case job of
  Job {} -> do
    noticeM "job" $ show (jobUnit job)
    hPutStrLn stdout $ desc (jobUnit job)
    hFlush stdout

---------------------------------------------------------------- PRIVATE

defaultId :: Int
defaultId = -1

defaultGroup :: Int
defaultGroup = -1
