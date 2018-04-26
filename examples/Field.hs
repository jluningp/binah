{-# LANGUAGE EmptyDataDecls, GADTs, ExistentialQuantification #-}

{-@ LIQUID "--no-adt" 	                           @-}
{-@ LIQUID "--exact-data-con"                      @-}
{-@ LIQUID "--higherorder"                         @-}
{-@ LIQUID "--no-termination"                      @-}
{-@ LIQUID "--no-totality"                      @-}
{-@ LIQUID "--ple" @-} 


module Field
where

import Prelude hiding (sequence, mapM, filter)

{-@ reflect admin @-}
admin = User "" []

{-@ data TaggedUser a <p :: User -> User -> Bool> = TaggedUser { content :: a } @-}
data TaggedUser a = TaggedUser { content :: a }

{-@ data variance TaggedUser covariant contravariant @-}

{-@ output :: forall <p :: User -> User -> Bool>.
             msg:TaggedUser<p> a 
          -> row:TaggedUser<p> User
          -> User<p (content row)>
          -> ()
@-}
output :: TaggedUser a -> TaggedUser User -> User -> ()
output = undefined

data RefinedPersistFilter = EQUAL
{-@ data RefinedFilter record typ <p :: User -> record -> Bool> = RefinedFilter
    { refinedFilterField  :: EntityField record typ
    , refinedFilterValue  :: typ
    , refinedFilterFilter :: RefinedPersistFilter
    } 
  @-}
{-@ data variance RefinedFilter covariant covariant contravariant @-}
data RefinedFilter record typ = RefinedFilter
    { refinedFilterField  :: EntityField record typ
    , refinedFilterValue  :: typ
    , refinedFilterFilter :: RefinedPersistFilter
    } 

{-@
data User = User
     { userName :: String
     , userFriends :: [User]
     }
@-}
data User = User { userName :: String, userFriends :: [User] }
    deriving Eq

{-@
data EntityField User typ where 
   Field.UserName :: EntityField User {v:_ | True}
 | Field.UserFriends :: EntityField User {v:_ | True}
@-}
data EntityField a b where
  UserName :: EntityField User String
  UserFriends :: EntityField User [User]

{-@ filterUserName:: RefinedPersistFilter -> String -> RefinedFilter<{\v u -> friends u v}> User String @-}
{-@ reflect filterUserName @-}
filterUserName :: RefinedPersistFilter -> String -> RefinedFilter User String 
filterUserName f v = RefinedFilter UserName v f

{-@ assume selectUser :: forall <p :: User -> User -> Bool>.
                         f:[RefinedFilter<p> User typ]
                      -> TaggedUser<p> User
@-}
selectUser ::
      [RefinedFilter User typ]
      -> TaggedUser User
selectUser fs = undefined

{-@ assume Prelude.error :: [Char] -> a @-} 

{-@ measure friends :: User -> User -> Bool @-}
{-@ assume isFriends :: forall <p :: User -> User -> Bool>. u:User -> v:TaggedUser<p> User -> {b:Bool | b <=> friends u (content v)} @-}
isFriends :: User -> TaggedUser User -> Bool
isFriends u (TaggedUser v) = elem u (userFriends v)

instance Functor TaggedUser where
  fmap f (TaggedUser x) = TaggedUser (f x)

instance Applicative TaggedUser where
  pure  = TaggedUser
  -- f (a -> b) -> f a -> f b
  (TaggedUser f) <*> (TaggedUser x) = TaggedUser (f x)

instance Monad TaggedUser where
  return x = TaggedUser x
  (TaggedUser x) >>= f = f x
  (TaggedUser _) >>  t = t
  fail          = error

{-@ instance Monad TaggedUser where
     >>= :: forall <p :: User-> User -> Bool, f:: a -> b -> Bool>.
            x:TaggedUser <p> a
         -> (u:a -> TaggedUser <p> (b <f u>))
         -> TaggedUser <p> (b<f (content x)>);
     >>  :: x:TaggedUser a
         -> TaggedUser b
         -> TaggedUser b;
     return :: forall <p :: User -> User -> Bool>. a -> TaggedUser <p> a
  @-}

-- Why is this line needed to type check?
{-@ selectTaggedData :: () -> TaggedUser<{\v u -> friends u v}> User @-}
selectTaggedData :: () -> TaggedUser User
selectTaggedData () = selectUser [filterUserName EQUAL "friend"]

sink () = do
  let user = selectTaggedData ()
  let viewer = User "" []
  return $ if isFriends viewer user then output user user viewer else ()
  
