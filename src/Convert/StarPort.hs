{- sv2v
 - Author: Zachary Snow <zach@zachjs.com>
 -
 - Conversion for `.*` in module instantiation
 -}

module Convert.StarPort (convert) where

import Control.Monad.Writer
import qualified Data.Map.Strict as Map

import Convert.Traverse
import Language.SystemVerilog.AST

type Ports = Map.Map Identifier [Identifier]

convert :: [AST] -> [AST]
convert =
    traverseFiles
        (collectDescriptionsM collectPortsM)
        (traverseDescriptions . traverseModuleItems . mapInstance)

collectPortsM :: Description -> Writer Ports ()
collectPortsM (Part _ _ _ _ name ports _) = tell $ Map.singleton name ports
collectPortsM _ = return ()

mapInstance :: Ports -> ModuleItem -> ModuleItem
mapInstance modulePorts (Instance m p x r bindings) =
    Instance m p x r $ concatMap expandBinding bindings
    where
        alreadyBound :: [Identifier]
        alreadyBound = map fst bindings
        expandBinding :: PortBinding -> [PortBinding]
        expandBinding ("*", Nothing) =
            case Map.lookup m modulePorts of
                Just l ->
                    map (\port -> (port, Just $ Ident port)) $
                    filter (\s -> not $ elem s alreadyBound) $ l
                -- if we can't find it, just skip :(
                Nothing -> [("*", Nothing)]
        expandBinding other = [other]
mapInstance _ other = other
