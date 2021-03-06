{-# LANGUAGE DeriveGeneric, DeriveAnyClass #-}
module Ceburilo.Graph (
    Graph
  , buildGraph
  , generateRoute
  ) where

import Data.HashSet as S
import Data.IntMap.Strict as IM
import Data.Graph.AStar as AS
import Ceburilo.Types
import GHC.Generics
import Control.DeepSeq

type Distance = Float
type Graph = IM.IntMap Node

data Node = Node { edges :: IM.IntMap Distance
                 , longitude :: Distance
                 , latitude :: Distance
                 } deriving (Generic, NFData)

-- How much time it takes to change bike (2 minutes)
-- in milliseconds
bikeChangeTime :: Distance
bikeChangeTime = 2 * 60 * 1000

getDistance :: Graph -> Key -> Key -> Distance
getDistance graph start goal = if start == goal then 0 else
-- very unsafe, but a* has proper assumption
  edges (graph ! start) ! goal + bikeChangeTime

getNeighbours :: Graph -> Key -> HashSet Key
getNeighbours graph nodeKey =
-- nodeKey will exist in DB!
  S.fromList . IM.keys . edges $ (graph ! nodeKey)

-- Maximum allowed time (20 minutes), in milliseconds.
maxTime :: Distance
maxTime = 20 * 60 * 1000

getAllowedTimeNeighbours :: Graph -> Key -> HashSet Key
getAllowedTimeNeighbours graph nodeKey =
  S.fromList . IM.keys . IM.filter (<= maxTime) . edges $ (graph ! nodeKey)

foundGoal :: Key -> Key -> Bool
foundGoal goal node = goal == node

-- In case you needed, change [] case for debugging
addNodeToGraph :: Graph -> Key -> Distance -> Distance -> Graph
addNodeToGraph graph key long lat =
  case IM.lookup key graph of
    Nothing -> graph -- error "Node with given id already exist"
    (Just _) -> IM.insert key (Node IM.empty long lat) graph


-- In case you needed, change [] case for debuggin
addEdgeToGraph :: Graph -> Key -> Key -> Distance -> Graph
addEdgeToGraph graph start goal dist =
  case mNode of
    Nothing -> graph -- error "Path leads to not existing node"
    (Just node) -> IM.insert start (Node (IM.insert goal dist (edges node))
                                      (longitude node)
                                      (latitude node) ) graph
    where
      mNode = IM.lookup start graph


generateRoute :: Graph -> Key -> Key -> Maybe [Key]
generateRoute graph start goal =
  AS.aStar (getAllowedTimeNeighbours graph)
           (getDistance graph)
           (getDistance graph goal)
           (foundGoal goal)
           start


buildGraph :: Applicative f => [f StationPaths] -> f Graph
buildGraph = fmap IM.fromList . traverse (fmap stationToPair)
  where
    stationToPair (StationPaths (Station number _ (Point lat lon)) paths) =
        (number, node)
      where
        node = Node edgez lon lat
        edgez = fmap pathTime paths
