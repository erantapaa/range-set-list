import Test.Tasty
import Test.Tasty.QuickCheck as QC

import Data.Set (Set)
import qualified Data.Set as Set

import Data.RangeSet.List (RSet)
import qualified Data.RangeSet.List as RSet

import Control.Applicative
import Data.Int

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests" [qcProps]

data SetAction a = AEmpty
                 | ASingleton a
                 | AFromList [a]
                 | AInsert a (SetAction a)
                 | ADelete a (SetAction a)
                 | AUnion (SetAction a) (SetAction a)
                 | ADifference (SetAction a) (SetAction a)
                 | AIntersection (SetAction a) (SetAction a)
  deriving (Show)

instance Arbitrary a => Arbitrary (SetAction a) where
  arbitrary = sized arbitrary'
    where arbitrary' n
            | n <= 0     = oneof [pure AEmpty, ASingleton <$> arbitrary]
            | otherwise  = oneof [ pure AEmpty
                                 , ASingleton <$> arbitrary
                                 , AFromList <$> arbitrary
                                 , AInsert <$> arbitrary <*> arbitrary1
                                 , ADelete <$> arbitrary <*> arbitrary1
                                 , AUnion <$> arbitrary2 <*> arbitrary2
                                 , ADifference <$> arbitrary2 <*> arbitrary2
                                 , AIntersection <$> arbitrary2 <*> arbitrary2
                                 ]
                              where arbitrary1 = arbitrary' $ n - 1
                                    arbitrary2 = arbitrary' $ n `div` 2

toSet :: (Ord a) => SetAction a -> Set a
toSet AEmpty               = Set.empty
toSet (ASingleton a)       = Set.singleton a
toSet (AFromList l)        = Set.fromList l
toSet (AInsert a set)      = Set.insert a $ toSet set
toSet (ADelete a set)      = Set.delete a $ toSet set
toSet (AUnion a b)         = Set.union (toSet a) (toSet b)
toSet (ADifference a b)    = Set.difference (toSet a) (toSet b)
toSet (AIntersection a b)  = Set.intersection (toSet a) (toSet b)

toRSet :: (Enum a, Ord a) => SetAction a -> RSet a
toRSet AEmpty               = RSet.empty
toRSet (ASingleton a)       = RSet.singleton a
toRSet (AFromList l)        = RSet.fromList l
toRSet (AInsert a set)      = RSet.insert a $ toRSet set
toRSet (ADelete a set)      = RSet.delete a $ toRSet set
toRSet (AUnion a b)         = RSet.union (toRSet a) (toRSet b)
toRSet (ADifference a b)    = RSet.difference (toRSet a) (toRSet b)
toRSet (AIntersection a b)  = RSet.intersection (toRSet a) (toRSet b)

elementsProp :: SetAction Int -> Bool
elementsProp seta = Set.elems (toSet seta) == RSet.elems (toRSet seta)

data RSetAction a = RAEmpty
                  | RASingleton (a, a)
                  | RAFromList [(a, a)]
                  | RAInsert (a, a) (RSetAction a)
                  | RADelete (a, a) (RSetAction a)
                  | RAUnion (RSetAction a) (RSetAction a)
                  | RADifference (RSetAction a) (RSetAction a)
                  | RAIntersection (RSetAction a) (RSetAction a)
  deriving (Show)

instance Arbitrary a => Arbitrary (RSetAction a) where
  arbitrary = sized arbitrary'
    where arbitrary' n
            | n <= 0     = oneof [pure RAEmpty, RASingleton <$> arbitrary]
            | otherwise  = oneof [ pure RAEmpty
                                 , RASingleton <$> arbitrary
                                 , RAFromList <$> arbitrary
                                 , RAInsert <$> arbitrary <*> arbitrary1
                                 , RADelete <$> arbitrary <*> arbitrary1
                                 , RAUnion <$> arbitrary2 <*> arbitrary2
                                 , RADifference <$> arbitrary2 <*> arbitrary2
                                 , RAIntersection <$> arbitrary2 <*> arbitrary2
                                 ]
                              where arbitrary1 = arbitrary' $ n - 1
                                    arbitrary2 = arbitrary' $ n `div` 2  

rangeToSet :: (Enum a, Ord a) => RSetAction a -> Set a
rangeToSet RAEmpty               = Set.empty
rangeToSet (RASingleton a)       = Set.fromList $ uncurry enumFromTo a
rangeToSet (RAFromList l)        = Set.fromList $ concatMap (uncurry enumFromTo) l
rangeToSet (RAInsert a set)      = foldr Set.insert (rangeToSet set) $ uncurry enumFromTo a
rangeToSet (RADelete a set)      = foldr Set.delete (rangeToSet set) $ uncurry enumFromTo a
rangeToSet (RAUnion a b)         = Set.union (rangeToSet a) (rangeToSet b)
rangeToSet (RADifference a b)    = Set.difference (rangeToSet a) (rangeToSet b)
rangeToSet (RAIntersection a b)  = Set.intersection (rangeToSet a) (rangeToSet b)

rangeToRSet :: (Enum a, Ord a) => RSetAction a -> RSet a
rangeToRSet RAEmpty               = RSet.empty
rangeToRSet (RASingleton a)       = RSet.singletonRange a
rangeToRSet (RAFromList l)        = RSet.fromRangeList l
rangeToRSet (RAInsert a set)      = RSet.insertRange a $ rangeToRSet set
rangeToRSet (RADelete a set)      = RSet.deleteRange a $ rangeToRSet set
rangeToRSet (RAUnion a b)         = RSet.union (rangeToRSet a) (rangeToRSet b)
rangeToRSet (RADifference a b)    = RSet.difference (rangeToRSet a) (rangeToRSet b)
rangeToRSet (RAIntersection a b)  = RSet.intersection (rangeToRSet a) (rangeToRSet b)

rangeProp :: RSetAction Int8 -> Bool
rangeProp seta = Set.elems (rangeToSet seta) == RSet.elems (rangeToRSet seta)

ordered :: Ord a => [(a,a)] -> Bool
ordered rs = all lt $ zip rs (tail rs)
  where
    lt :: Ord a => ((a,a),(a,a)) -> Bool
    lt ((_,y),(u,_)) = y < u

orderedProp :: RSetAction Int8 -> Bool
orderedProp = ordered . RSet.toRangeList . rangeToRSet

qcProps :: TestTree
qcProps = testGroup "QuickCheck properties"
  [ QC.testProperty "element operations similar" elementsProp
  , QC.testProperty "range operations similar" rangeProp
  , QC.testProperty "ranges remain ordered" orderedProp
  ]
