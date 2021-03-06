{-
Module containing autocrrect functions
-}

module AutoCorrect
  ( initDict,
    isInDict,
    allWordsInDict,
    distance,
    bestSuggestion,
    bestSuggestionN,
  )
where

import Control.Monad.Memo
import Data.List as L
import Data.Set as S
import Data.Text as T
import qualified Data.Vector as V
import Test.HUnit (Assertion, Counts, Test (..), assert, runTestTT, (~:), (~?=))

-- | returns a dictionary with all the words in a given text
initDict :: Text -> S.Set String
initDict = S.fromList . L.words . unpack

-- | Dictionary containing initial used words (initially only )
initialWords :: S.Set String
initialWords = S.empty

-- | checks to see if a given word is in the diciontary
isInDict :: String -> S.Set String -> Bool
isInDict = S.member

-- | checks if all words are in the dictionary
allWordsInDict :: S.Set String -> S.Set String -> Bool
allWordsInDict = flip S.isSubsetOf

-- | adds a word to the dictionary
addWord :: String -> S.Set String -> S.Set String
addWord = S.insert

deleteWord :: String -> S.Set String -> S.Set String
deleteWord = S.delete

-- | Finds the distance (Levenshtein) between two strings
distance :: String -> String -> Int
distance s t = startEvalMemo $ distance' (V.fromList s, V.fromList t)

-- | Uses vectors and memo for better runtime
distance' ::
  (MonadMemo (V.Vector Char, V.Vector Char) Int m) =>
  (V.Vector Char, V.Vector Char) ->
  m Int
distance' (s, t)
  | V.null s = return $ V.length t
  | V.null t = return $ V.length s
  | V.last s == V.last t = memo distance' (V.init s, V.init t)
  | otherwise = do
    d1 <- memo distance' (V.init s, t)
    d2 <- memo distance' (V.init s, V.init t)
    d3 <- memo distance' (s, V.init t)
    return $ 1 + L.minimum [d1, d2, d3]

-- | Finds the distances between a given string and a list of strings
distances :: String -> [String] -> [(String, Int)]
distances x = L.map (\y -> (y, distance x y))

-- | finds the tuple with the lowest distance, given all (String, distance) pairs
findBest :: [(String, Int)] -> Maybe String
findBest distances =
  let aux :: [(String, Int)] -> Maybe (String, Int) -> Maybe (String, Int)
      aux [] acc = acc
      aux ((s1, d1) : ps) acc = case aux ps acc of
        Nothing -> Just (s1, d1)
        Just (s2, d2) -> if d2 < d1 then Just (s2, d2) else Just (s1, d1)
   in do
        (s, d) <- aux distances Nothing
        return s

-- | Finds the closest suggestion to a word given a dictionary
bestSuggestion :: String -> S.Set String -> Maybe String
bestSuggestion word dict =
  if S.null dict
    then Nothing
    else
      let allDistances = distances word (S.toList dict)
       in findBest allDistances

-- | Finds the N closest suggestions to a word given a dictionary
bestSuggestionN :: Int -> String -> S.Set String -> S.Set String
bestSuggestionN 0 _ _ = S.empty
bestSuggestionN n word dict = case bestSuggestion word dict of
  Nothing -> S.empty
  Just w -> S.insert w $ bestSuggestionN (n - 1) word (deleteWord w dict)
