{-# LANGUAGE EmptyDataDecls             #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

{-@ LIQUID "--no-adt" 	                           @-}
{-@ LIQUID "--exact-data-con"                      @-}
{-@ LIQUID "--higherorder"                         @-}
{-@ LIQUID "--no-termination"                      @-}
{-@ LIQUID "--ple" @-} 

module BinahLibrary where
import           Prelude hiding (filter)
import           Control.Monad.IO.Class  (liftIO, MonadIO)
import           Control.Monad.Trans.Reader
import           Database.Persist
import           Models

data RefinedPersistFilter = EQUAL | NE | LE | LTP | GE | GTP

{-@ data RefinedFilter record typ = RefinedFilter
    { refinedFilterField  :: EntityField record typ
    , refinedFilterValue  :: typ
    , refinedFilterFilter :: RefinedPersistFilter
    } 
  @-}
data RefinedFilter record typ = RefinedFilter
    { refinedFilterField  :: EntityField record typ
    , refinedFilterValue  :: typ
    , refinedFilterFilter :: RefinedPersistFilter
    } 

{-@ data RefinedUpdate record typ = RefinedUpdate
    { refinedUpdateField :: EntityField record typ
    , refinedUpdateValue :: typ } @-}
data RefinedUpdate record typ = RefinedUpdate 
    { refinedUpdateField :: EntityField record typ
    , refinedUpdateValue :: typ
    } 

(=#) :: EntityField v typ -> typ -> RefinedUpdate v typ
x =# y = RefinedUpdate x y

{-@ reflect ==# @-}
(==#) :: (PersistEntity record, Eq typ) => 
                 EntityField record typ -> typ -> RefinedFilter record typ
field ==# value = RefinedFilter field value EQUAL

{-@ reflect /=# @-}
(/=#) :: (PersistEntity record, Eq typ) => 
                 EntityField record typ -> typ -> RefinedFilter record typ
field /=# value = RefinedFilter field value NE 

{-@ reflect <=# @-}
(<=#) :: (PersistEntity record, Eq typ) => 
                 EntityField record typ -> typ -> RefinedFilter record typ
field <=# value =
  RefinedFilter {
    refinedFilterField = field
  , refinedFilterValue = value
  , refinedFilterFilter = LE 
  }

{-@ reflect <# @-}
(<#) :: (PersistEntity record, Eq typ) => 
                 EntityField record typ -> typ -> RefinedFilter record typ
field <# value =
  RefinedFilter {
    refinedFilterField = field
  , refinedFilterValue = value
  , refinedFilterFilter = LTP
  }

{-@ reflect >=# @-}
(>=#) :: (PersistEntity record, Eq typ) => 
                 EntityField record typ -> typ -> RefinedFilter record typ
field >=# value =
  RefinedFilter {
    refinedFilterField = field
  , refinedFilterValue = value
  , refinedFilterFilter = GE 
  }

{-@ reflect ># @-}
(>#) :: (PersistEntity record, Eq typ) => 
                 EntityField record typ -> typ -> RefinedFilter record typ
field ># value =
  RefinedFilter {
    refinedFilterField = field
  , refinedFilterValue = value
  , refinedFilterFilter = GE 
  }


toPersistentFilter :: PersistField typ =>
                      RefinedFilter record typ -> Filter record
toPersistentFilter filter =
    case refinedFilterFilter filter of
         EQUAL -> (refinedFilterField filter) ==. (refinedFilterValue filter)
         NE -> (refinedFilterField filter) !=. (refinedFilterValue filter)
         LE -> (refinedFilterField filter) <=. (refinedFilterValue filter)
         LTP -> (refinedFilterField filter) <. (refinedFilterValue filter)
         GE -> (refinedFilterField filter) >=. (refinedFilterValue filter)
         GTP -> (refinedFilterField filter) >. (refinedFilterValue filter)

toPersistentUpdate :: PersistField typ =>
                      RefinedUpdate record typ -> Update record
toPersistentUpdate (RefinedUpdate a b) = a =. b

{-@ filter :: f:(a -> Bool) -> [a] -> [{v:a | f v}] @-}
filter :: (a -> Bool) -> [a] -> [a]
filter f (x:xs)
  | f x         = x : filter f xs
  | otherwise   =     filter f xs
filter _ []     = []
{-@ reflect evalQBlobXVal @-}
evalQBlobXVal :: RefinedPersistFilter -> Int -> Int -> Bool
evalQBlobXVal EQUAL filter given = given== filter
evalQBlobXVal LE filter given = given<= filter
evalQBlobXVal GE filter given = given>= filter
evalQBlobXVal LTP filter given = given< filter
evalQBlobXVal GTP filter given = given> filter
evalQBlobXVal NE filter given = given/= filter

{-@ reflect evalQBlobYVal @-}
evalQBlobYVal :: RefinedPersistFilter -> Int -> Int -> Bool
evalQBlobYVal EQUAL filter given = given== filter
evalQBlobYVal LE filter given = given<= filter
evalQBlobYVal GE filter given = given>= filter
evalQBlobYVal LTP filter given = given< filter
evalQBlobYVal GTP filter given = given> filter
evalQBlobYVal NE filter given = given/= filter

{-@ reflect evalQBlob @-}
evalQBlob :: RefinedFilter Blob typ -> Blob -> Bool
evalQBlob filter x = case refinedFilterField filter of
    BlobXVal -> evalQBlobXVal (refinedFilterFilter filter) (refinedFilterValue filter) (blobXVal x)
    BlobYVal -> evalQBlobYVal (refinedFilterFilter filter) (refinedFilterValue filter) (blobYVal x)
    BlobId -> False

{-@ reflect evalQsBlob @-}
evalQsBlob :: [RefinedFilter Blob typ] -> Blob -> Bool
evalQsBlob (f:fs) x = evalQBlob f x && (evalQsBlob fs x)
evalQsBlob [] _ = True

{-@ assume selectBlob :: f:[RefinedFilter Blob typ]
                -> [SelectOpt Blob]
                -> Control.Monad.Trans.Reader.ReaderT backend m [Entity {v:Blob | evalQsBlob f v}] @-}
selectBlob :: (PersistEntityBackend Blob ~ BaseBackend backend,
      PersistEntity Blob, Control.Monad.IO.Class.MonadIO m,
      PersistQueryRead backend, PersistField typ) =>
      [RefinedFilter Blob typ]
      -> [SelectOpt Blob]
      -> Control.Monad.Trans.Reader.ReaderT backend m [Entity Blob]
selectBlob fs ts = selectList (map toPersistentFilter fs) ts