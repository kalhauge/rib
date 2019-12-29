{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- Suppressing orphans warning for `Markup MMark` instance

module Rib.Markup.MMark
  ( -- * Rendering
    render,

    -- * Extracting information
    getFirstImg,

    -- * Re-exports
    MMark,
  )
where

import Control.Foldl (Fold (..))
import Lucid (Html)
import Named
import Path
import Rib.Markup
import Text.MMark (MMark)
import qualified Text.MMark as MMark
import qualified Text.MMark.Extension as Ext
import qualified Text.MMark.Extension.Common as Ext
import qualified Text.Megaparsec as M
import Text.URI (URI)

instance IsMarkup MMark where

  type SubMarkup MMark = ()

  defaultSubMarkup = ()

  parseDoc () = parse "<memory>"

  readDoc () (Arg f) =
    parse (toFilePath f) <$> readFileText (toFilePath f)

  extractMeta = fmap Right . MMark.projectYaml

-- | Render a MMark document as HTML
render :: MMark -> Html ()
render = MMark.render

parse :: FilePath -> Text -> Either Text MMark
parse k s = case MMark.parse k s of
  Left e -> Left $ toText $ M.errorBundlePretty e
  Right doc -> Right $ MMark.useExtensions exts $ useTocExt doc

-- | Get the first image in the document if one exists
getFirstImg :: MMark -> Maybe URI
getFirstImg = flip MMark.runScanner $ Fold f Nothing id
  where
    f acc blk = acc <|> listToMaybe (mapMaybe getImgUri (inlinesContainingImg blk))
    getImgUri = \case
      Ext.Image _ uri _ -> Just uri
      _ -> Nothing
    inlinesContainingImg :: Ext.Bni -> [Ext.Inline]
    inlinesContainingImg = \case
      Ext.Naked xs -> toList xs
      Ext.Paragraph xs -> toList xs
      _ -> []

exts :: [MMark.Extension]
exts =
  [ Ext.fontAwesome,
    Ext.footnotes,
    Ext.kbd,
    Ext.linkTarget,
    Ext.mathJax (Just '$'),
    Ext.obfuscateEmail "protected-email",
    Ext.punctuationPrettifier,
    Ext.ghcSyntaxHighlighter,
    Ext.skylighting
  ]

useTocExt :: MMark -> MMark
useTocExt doc = MMark.useExtension (Ext.toc "toc" toc) doc
  where
    toc = MMark.runScanner doc $ Ext.tocScanner (\x -> x > 1 && x < 5)
