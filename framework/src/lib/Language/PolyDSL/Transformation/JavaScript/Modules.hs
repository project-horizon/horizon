{-
Copyright (c) 2015 Nils 'bash0r' Jonsson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-}

{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances  #-}

{- |
Module      :  $Header$
Description :  Conversion from PolyDSL modules to JavaScript.
Author	    :  Nils 'bash0r' Jonsson
Copyright   :  (c) 2015 Nils 'bash0r' Jonsson
License	    :  MIT

Maintainer  :  aka.bash0r@gmail.com
Stability   :  unstable
Portability :  non-portable (Portability is untested.)

Conversion from PolyDSL modules to JavaScript.
-}
module Language.PolyDSL.Transformation.JavaScript.Modules
(
) where

import           Language.JavaScript
import           Language.Transformation.Protocol
import           Language.Transformation.Semantics

import qualified Language.PolyDSL.DOM as DOM

import           Language.PolyDSL.Transformation.JavaScript.GADTs
import           Language.PolyDSL.Transformation.JavaScript.Internal


instance Transformer DOM.Module (SemanticResult ModL1) where
  transform (DOM.Module mName es ds) =
      let (is, ts, tas, fs) = filterDecls ds [] [] [] []
       in return $ ModL1 mName es (Imports is) (GADTs ts) (TypeAliases tas) (Functions fs)
    where
      filterDecls []                        is ts tas fs = (reverse is, reverse ts, reverse tas, reverse fs)
      filterDecls (i@(DOM.Import    {}):ds) is ts tas fs = filterDecls ds (i:is) ts     tas     fs
      filterDecls (t@(DOM.GADT      {}):ds) is ts tas fs = filterDecls ds is     (t:ts) tas     fs
      filterDecls (t@(DOM.TypeAlias {}):ds) is ts tas fs = filterDecls ds is     ts     (t:tas) fs
      filterDecls (f@(DOM.Function  {}):ds) is ts tas fs = filterDecls ds is     ts     tas     (f:fs)
      filterDecls (s@(DOM.Signature {}):ds) is ts tas fs = filterDecls ds is     ts     tas     (s:fs)

instance Transformer ModL1 (SemanticResult Statement) where
  transform (ModL1 mName es is ts tas fs) = return $ expr (this ... "module_register" ... mName .= body)
    where
      body = new (function [] (defs ++ exps)) []
      defs = transform ts
      exps = map (\v -> expr (this ... v .= ident v)) es

instance Transformer DOM.Module (SemanticResult Statement) where
  transform p = do
    x <- transform p 
    transform (x :: ModL1)

instance Transformer [DOM.Module] (SemanticResult Statement) where
  transform ms = do
    let modBlockInit = expr (this ... "module_register" .= object [])
    ms' <- mapM transform ms
    return (block (modBlockInit : ms'))
