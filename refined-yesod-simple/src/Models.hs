{-# LANGUAGE EmptyDataDecls             #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

{-@ LIQUID "--no-adt"                   @-}
{-@ LIQUID "--exact-data-con"           @-}
{-@ LIQUID "--higherorder"              @-}
{-@ LIQUID "--no-termination"           @-}

module Models where

import           Control.Monad
import           Database.Persist
import           Database.Persist.Sqlite
import           Database.Persist.TH
import           Data.Aeson
import           Data.HashMap.Strict
import           Data.Int
import           Data.Map
import           Data.Proxy
import           Data.Text
import           Web.Internal.HttpApiData
import           Web.PathPieces
import           Data.Typeable


{-@ embed String as Str @-}

{-@
data Person = Person
	{ personNumber :: {v:Int | v > 0},
          personName :: {v:String | True}
	}
@-}

{-@
data EntityField Person typ where
   Models.PersonNumber :: EntityField Person {v:_ | v > 0}
 | Models.PersonName :: EntityField Person {v:_ | True}
 | Models.PersonId :: EntityField Person {v:_ | True}
@-}

{-@ assume Prelude.error :: String -> a @-}
share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
Person
   ~number Int
   ~name String
   deriving Show
|]
