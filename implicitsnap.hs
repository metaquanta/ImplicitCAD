{-# LANGUAGE OverloadedStrings, ViewPatterns #-}

{- This is a Snap server providing a ImplicitCAD REST API.
   It does not install by default. Its dependencies are not in the cabal file.
   We're just sticking it in the repo for lack of a better place... -}

module Main where

import Control.Applicative
import Snap.Core
import Snap.Http.Server
import Snap.Util.GZip (withCompression)

import Graphics.Implicit (runOpenscad)
import Graphics.Implicit.ExtOpenScad.Definitions (OpenscadObj (ONum))
import Graphics.Implicit.ObjectUtil (getBox2, getBox3)
import Graphics.Implicit.Export.TriangleMeshFormats (jsTHREE)
import Graphics.Implicit.Definitions (xmlErrorOn, errorMessage)
import Data.Map as Map
import Text.ParserCombinators.Parsec (errorPos, sourceLine)
import Text.ParserCombinators.Parsec.Error

-- class DiscreteApproxable
import Graphics.Implicit.Export.Definitions

-- instances of DiscreteApproxable...
import Graphics.Implicit.Export.SymbolicObj2
import Graphics.Implicit.Export.SymbolicObj3

import System.IO.Unsafe (unsafePerformIO)

import qualified Data.ByteString.Char8 as BS.Char

main :: IO ()
main = quickHttpServe site

site :: Snap ()
site = route 
	[ 
		("render/", renderHandler)
	] <|> writeBS "fall through"

renderHandler :: Snap ()
renderHandler = method GET $ withCompression $ do

	request <- getRequest
	case (rqParam "source" request, rqParam "callback" request)  of
		(Just [source], Just [callback]) -> do
			writeBS $ BS.Char.pack $ executeAndExport 
				(BS.Char.unpack source)
				(BS.Char.unpack callback)
		(_, _)       -> writeBS "must provide source and callback as 1 GET variable each"
 




getRes (Map.lookup "$res" -> Just (ONum res), _, _) = res

getRes (_, _, obj:_) = min (minimum [x,y,z]/2) ((x*y*z)**(1/3) / 22)
	where
		((x1,y1,z1),(x2,y2,z2)) = getBox3 obj
		(x,y,z) = (x2-x1, y2-y1, z2-z1)

getRes (_, obj:_, _) = min (min x y/2) ((x*y)**0.5 / 30)
	where
		((x1,y1),(x2,y2)) = getBox2 obj
		(x,y) = (x2-x1, y2-y1)

getRes _ = 1

-- | Give an openscad object to run and the basename of 
--   the target to write to... write an object!
executeAndExport :: String -> String -> String
executeAndExport content callback = 
	let
		callbackF False msg = callback ++ "([null," ++ show msg ++ "]);"
		callbackF True  msg = callback ++ "([new Shape()," ++ show msg ++ "]);"
	in case runOpenscad content of
		Left err -> 
			let
				line = sourceLine . errorPos $ err
				showErrorMessages' = showErrorMessages 
					"or" "unknown parse error" "expecting" "unexpected" "end of input"
				msgs :: String
				msgs = showErrorMessages' $ errorMessages err
			in callbackF False $ (\s-> "error (" ++ show line ++ "):" ++ s) msgs
		Right openscadProgram -> unsafePerformIO $ do 
			s <- openscadProgram 
			let
				res = getRes s
			return $ case s of 
				(_, _, x:xs)  -> jsTHREE (discreteAprox res x) ++ callbackF True ""
				_ ->  callbackF False "not a 3D object"


