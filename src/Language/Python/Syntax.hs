{-# LANGUAGE DeriveAnyClass #-}
module Language.Python.Syntax where

import           Data.Abstract.Environment as Env
import           Data.Abstract.Evaluatable
import           Data.Abstract.Module
import           Data.Aeson
import           Data.Align.Generic
import           Data.Functor.Classes.Generic
import           Data.JSON.Fields
import           Data.Mergeable
import           Diffing.Algorithm
import           GHC.Generics
import           Prelude hiding (fail)
import           Prologue
import           System.FilePath.Posix
import qualified Data.ByteString.Char8 as BC
import qualified Data.Language as Language
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Semigroup.Reducer as Reducer

data QualifiedName
  = QualifiedName (NonEmpty FilePath)
  | RelativeQualifiedName FilePath (Maybe QualifiedName)
  deriving (Eq, Generic, Hashable, Ord, Show, ToJSON)

qualifiedName :: NonEmpty ByteString -> QualifiedName
qualifiedName xs = QualifiedName (BC.unpack <$> xs)

relativeQualifiedName :: ByteString -> [ByteString] -> QualifiedName
relativeQualifiedName prefix []    = RelativeQualifiedName (BC.unpack prefix) Nothing
relativeQualifiedName prefix paths = RelativeQualifiedName (BC.unpack prefix) (Just (qualifiedName (NonEmpty.fromList paths)))

-- Python module resolution.
-- https://docs.python.org/3/reference/import.html#importsystem
--
-- TODO: Namespace packages
--
-- Regular packages resolution:
--
-- parent/
--     __init__.py
--     one/
--         __init__.py
--     two/
--         __init__.py
--     three/
--         __init__.py
--
-- `import parent.one` will implicitly execute:
--     `parent/__init__.py` and
--     `parent/one/__init__.py`
-- Subsequent imports of `parent.two` or `parent.three` will execute
--     `parent/two/__init__.py` and
--     `parent/three/__init__.py` respectively.
resolvePythonModules :: ( Member (Modules location value) effects
                        , Member (Reader ModuleInfo) effects
                        , Member (Resumable ResolutionError) effects
                        , Member Trace effects
                        )
                     => QualifiedName
                     -> Evaluator location value effects (NonEmpty ModulePath)
resolvePythonModules q = do
  relRootDir <- rootDir q <$> currentModule
  for (moduleNames q) $ \name -> do
    x <- search relRootDir name
    x <$ traceResolve name x
  where
    rootDir (QualifiedName _) ModuleInfo{..}           = mempty -- overall rootDir of the Package.
    rootDir (RelativeQualifiedName n _) ModuleInfo{..} = upDir numDots (takeDirectory modulePath)
      where numDots = pred (length n)
            upDir n dir | n <= 0 = dir
                        | otherwise = takeDirectory (upDir (pred n) dir)

    moduleNames (QualifiedName qualifiedName)          = NonEmpty.scanl1 (</>) qualifiedName
    moduleNames (RelativeQualifiedName x Nothing)      = error $ "importing from '" <> show x <> "' is not implemented"
    moduleNames (RelativeQualifiedName _ (Just paths)) = moduleNames paths

    search rootDir x = do
      trace ("searching for " <> show x <> " in " <> show rootDir)
      let path = normalise (rootDir </> normalise x)
      let searchPaths = [ path </> "__init__.py"
                        , path <.> ".py"
                        ]
      modulePath <- resolve searchPaths
      maybe (throwResumable $ NotFoundError path searchPaths Language.Python) pure modulePath


-- | Import declarations (symbols are added directly to the calling environment).
--
-- If the list of symbols is empty copy everything to the calling environment.
data Import a = Import { importFrom :: QualifiedName, importSymbols :: ![(Name, Name)] }
  deriving (Diffable, Eq, Foldable, Functor, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance ToJSONFields1 Import

instance Eq1 Import where liftEq = genericLiftEq
instance Ord1 Import where liftCompare = genericLiftCompare
instance Show1 Import where liftShowsPrec = genericLiftShowsPrec

-- from a import b
instance Evaluatable Import where
  -- from . import moduleY
  -- This is a bit of a special case in the syntax as this actually behaves like a qualified relative import.
  eval (Import (RelativeQualifiedName n Nothing) [(name, _)]) = do
    path <- NonEmpty.last <$> resolvePythonModules (RelativeQualifiedName n (Just (qualifiedName (unName name :| []))))
    Rval <$> evalQualifiedImport name path

  -- from a import b
  -- from a import b as c
  -- from a import *
  -- from .moduleY import b
  eval (Import name xs) = do
    modulePaths <- resolvePythonModules name

    -- Eval parent modules first
    for_ (NonEmpty.init modulePaths) (isolate . require)

    -- Last module path is the one we want to import
    let path = NonEmpty.last modulePaths
    importedEnv <- maybe emptyEnv fst <$> isolate (require path)
    modifyEnv (mergeEnvs (select importedEnv))
    pure (Rval unit)
    where
      select importedEnv
        | Prologue.null xs = importedEnv
        | otherwise = Env.overwrite xs importedEnv


-- Evaluate a qualified import
evalQualifiedImport :: ( AbstractValue location value effects
                       , Member (Allocator location value) effects
                       , Member (Modules location value) effects
                       , Member (Reader (Environment location)) effects
                       , Member (State (Environment location)) effects
                       , Member (State (Exports location)) effects
                       , Member (State (Heap location (Cell location) value)) effects
                       , Ord location
                       , Reducer.Reducer value (Cell location value)
                       )
                    => Name -> ModulePath -> Evaluator location value effects value
evalQualifiedImport name path = letrec' name $ \addr -> do
  importedEnv <- maybe emptyEnv fst <$> isolate (require path)
  modifyEnv (mergeEnvs importedEnv)
  unit <$ makeNamespace name addr Nothing

newtype QualifiedImport a = QualifiedImport { qualifiedImportFrom :: QualifiedName }
  deriving (Diffable, Eq, Foldable, Functor, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance ToJSONFields1 QualifiedImport

instance Eq1 QualifiedImport where liftEq = genericLiftEq
instance Ord1 QualifiedImport where liftCompare = genericLiftCompare
instance Show1 QualifiedImport where liftShowsPrec = genericLiftShowsPrec

-- import a.b.c
instance Evaluatable QualifiedImport where
  eval (QualifiedImport (RelativeQualifiedName _ _))        = raiseEff (fail "technically this is not allowed in python")
  eval (QualifiedImport qname@(QualifiedName qualifiedName)) = do
    modulePaths <- resolvePythonModules qname
    Rval <$> go (NonEmpty.zip (name . BC.pack <$> qualifiedName) modulePaths)
    where
      -- Evaluate and import the last module, updating the environment
      go ((name, path) :| []) = evalQualifiedImport name path
      -- Evaluate each parent module, just creating a namespace
      go ((name, path) :| xs) = letrec' name $ \addr -> do
        void $ isolate (require path)
        void $ go (NonEmpty.fromList xs)
        makeNamespace name addr Nothing

data QualifiedAliasedImport a = QualifiedAliasedImport { qualifiedAliasedImportFrom :: QualifiedName, qualifiedAliasedImportAlias :: !a }
  deriving (Diffable, Eq, Foldable, Functor, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance ToJSONFields1 QualifiedAliasedImport

instance Eq1 QualifiedAliasedImport where liftEq = genericLiftEq
instance Ord1 QualifiedAliasedImport where liftCompare = genericLiftCompare
instance Show1 QualifiedAliasedImport where liftShowsPrec = genericLiftShowsPrec

-- import a.b.c as e
instance Evaluatable QualifiedAliasedImport where
  eval (QualifiedAliasedImport name aliasTerm) = do
    modulePaths <- resolvePythonModules name

    -- Evaluate each parent module
    for_ (NonEmpty.init modulePaths) (isolate . require)

    -- Evaluate and import the last module, aliasing and updating the environment
    alias <- either (throwEvalError . FreeVariablesError) pure (freeVariable $ subterm aliasTerm)
    Rval <$> letrec' alias (\addr -> do
      let path = NonEmpty.last modulePaths
      importedEnv <- maybe emptyEnv fst <$> isolate (require path)
      modifyEnv (mergeEnvs importedEnv)
      unit <$ makeNamespace alias addr Nothing)

-- | Ellipsis (used in splice expressions and alternatively can be used as a fill in expression, like `undefined` in Haskell)
data Ellipsis a = Ellipsis
  deriving (Diffable, Eq, Foldable, Functor, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Ellipsis where liftEq = genericLiftEq
instance Ord1 Ellipsis where liftCompare = genericLiftCompare
instance Show1 Ellipsis where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Ellipsis

-- TODO: Implement Eval instance for Ellipsis
instance Evaluatable Ellipsis


data Redirect a = Redirect !a !a
  deriving (Diffable, Eq, Foldable, Functor, Generic1, Hashable1, Mergeable, Ord, Show, Traversable, FreeVariables1, Declarations1)

instance Eq1 Redirect where liftEq = genericLiftEq
instance Ord1 Redirect where liftCompare = genericLiftCompare
instance Show1 Redirect where liftShowsPrec = genericLiftShowsPrec

instance ToJSONFields1 Redirect

-- TODO: Implement Eval instance for Redirect
instance Evaluatable Redirect
