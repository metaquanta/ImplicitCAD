-- Implicit CAD. Copyright (C) 2011, Christopher Olah (chris@colah.ca)
-- Copyright (C) 2014 2015 2016, Julia Longtin (julial@turinglace.com)
-- Released under the GNU AGPLV3+, see LICENSE

-- A module of math utilities.
module Graphics.Implicit.MathUtil (rmax, rmaximum, rminimum, distFromLineSeg, pack, box3sWithin) where

-- Explicitly include what we need from Prelude.
import Prelude (Bool, Ordering, (>), (<), (+), ($), (/), otherwise, not, (||), (&&), abs, (-), (*), sin, asin, pi, max, sqrt, min, compare, (<=), fst, snd, (++), head, flip, maximum, minimum, (==))

import Graphics.Implicit.Definitions (ℝ, ℝ2, ℝ3, Box2, (⋅))

import Data.List (sort, sortBy, (!!))

import Data.VectorSpace (magnitude, normalized, (^-^), (^+^), (*^))

-- get the distance between two points.
import Data.AffineSpace (distance)

-- | The distance a point p is from a line segment (a,b)
distFromLineSeg :: ℝ2 -> (ℝ2, ℝ2) -> ℝ
distFromLineSeg p (a,b) = distance p closest
    where
        ab = b ^-^ a
        ap = p ^-^ a
        d :: ℝ
        d  = normalized ab ⋅ ap
        -- the closest point to p on the line segment.
        closest :: ℝ2
        closest
            | d < 0 = a
            | d > magnitude ab = b
            | otherwise = a ^+^ d *^ normalized ab

box3sWithin :: ℝ -> (ℝ3, ℝ3) -> (ℝ3, ℝ3) -> Bool
box3sWithin r ((ax1, ay1, az1),(ax2, ay2, az2)) ((bx1, by1, bz1),(bx2, by2, bz2)) =
    let
        near (a1, a2) (b1, b2) = not $ (a2 + r < b1) || (b2 + r < a1)
    in
           (ax1,ax2) `near` (bx1, bx2)
        && (ay1,ay2) `near` (by1, by2)
        && (az1,az2) `near` (bz1, bz2)

-- | Rounded Maximum
-- Consider  max(x,y) = 0, the generated curve
-- has a square-like corner. We replace it with a
-- quarter of a circle
rmax ::
    ℝ     -- ^ radius
    -> ℝ  -- ^ first number to round maximum
    -> ℝ  -- ^ second number to round maximum
    -> ℝ  -- ^ resulting number
rmax r x y
  | r == 0    = max x y
  | otherwise = if abs (x-y) < r
                then y - r*sin(pi/4-asin((x-y)/r/sqrt 2)) + r
                else max x y

-- | Rounded minimum
rmin ::
    ℝ     -- ^ radius
    -> ℝ  -- ^ first number to round minimum
    -> ℝ  -- ^ second number to round minimum
    -> ℝ  -- ^ resulting number
rmin r x y = if abs (x-y) < r
    then y + r*sin(pi/4+asin((x-y)/r/sqrt 2)) - r
    else min x y

-- | Like rmax, but on a list instead of two.
-- Just as maximum is.
-- The implementation is to take the maximum two
-- and rmax those.
rmaximum ::
    ℝ      -- ^ radius
    -> [ℝ] -- ^ numbers to take round maximum
    -> ℝ   -- ^ resulting number
rmaximum _ [] = 0
rmaximum _ [a] = a
rmaximum r [a,b]
  | r == 0    = max a b
  | otherwise = rmax r a b
rmaximum r l
  | r == 0    = maximum l
  | otherwise =
    let
        tops = sortBy (flip compare) l
    in
        rmax r (head tops) (tops !! 1)

-- | Like rmin but on a list.
rminimum ::
    ℝ      -- ^ radius
    -> [ℝ] -- ^ numbers to take round minimum
    -> ℝ   -- ^ resulting number
rminimum _ [] = 0
rminimum _ [a] = a
rminimum r [a,b]
  | r > 0     = rmin r a b
  | otherwise = min a b
rminimum r l
  | r > 0 =
    let
        tops = sort l
    in
        rmin r (head tops) (tops !! 1)
  | otherwise = minimum l

-- | Pack the given objects in a box the given size.
pack ::
    Box2           -- ^ The box to pack within
    -> ℝ           -- ^ The space seperation between items
    -> [(Box2, a)] -- ^ Objects with their boxes
    -> ([(ℝ2, a)], [(Box2, a)] ) -- ^ Packed objects with their positions, objects that could be packed
pack (dx, dy) sep objs = packSome sortedObjs (dx, dy)
    where
        compareBoxesByY :: Box2 -> Box2 -> Ordering
        compareBoxesByY  ((_, ay1), (_, ay2))  ((_, by1), (_, by2)) =
                compare (abs $ by2-by1) (abs $ ay2-ay1)

        sortedObjs = sortBy
            (\(boxa, _) (boxb, _) -> compareBoxesByY boxa boxb )
            objs

        tmap1 :: (t2 -> t) -> (t2, t1) -> (t, t1)
        tmap1 f (a,b) = (f a, b)
        tmap2 :: (t2 -> t1) -> (t, t2) -> (t, t1)
        tmap2 f (a,b) = (a, f b)

        packSome :: [(Box2,a)] -> Box2 -> ([(ℝ2,a)], [(Box2,a)])
        packSome (presObj@(((x1,y1),(x2,y2)),obj):otherBoxedObjs) box@((bx1, by1), (bx2, by2)) =
            if abs (x2 - x1) <= abs (bx2-bx1) && abs (y2 - y1) <= abs (by2-by1)
            then
                let
                    row = tmap1 (((bx1-x1,by1-y1), obj):) $
                        packSome otherBoxedObjs ((bx1+x2-x1+sep, by1), (bx2, by1 + y2-y1))
                    rowAndUp =
                        if abs (by2-by1) - abs (y2-y1) > sep
                        then tmap1 (fst row ++ ) $
                            packSome (snd row) ((bx1, by1 + y2-y1+sep), (bx2, by2))
                        else row
                in
                    rowAndUp
            else
                tmap2 (presObj:) $ packSome otherBoxedObjs box
        packSome [] _ = ([], [])
