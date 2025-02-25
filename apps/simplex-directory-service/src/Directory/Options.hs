{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Directory.Options
  ( DirectoryOpts (..),
    getDirectoryOpts,
    mkChatOpts,
  )
where

import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Options.Applicative
import Simplex.Chat.Bot.KnownContacts
import Simplex.Chat.Controller (AcceptAsObserver (..), updateStr, versionNumber, versionString)
import Simplex.Chat.Options (ChatCmdLog (..), ChatOpts (..), CoreChatOpts, coreChatOptsP)

data DirectoryOpts = DirectoryOpts
  { coreOptions :: CoreChatOpts,
    adminUsers :: [KnownContact],
    superUsers :: [KnownContact],
    ownersGroup :: Maybe KnownGroup,
    blockedWordsFile :: Maybe FilePath,
    blockedExtensionRules :: Maybe FilePath,
    nameSpellingFile :: Maybe FilePath,
    profileNameLimit :: Int,
    acceptAsObserver :: Maybe AcceptAsObserver,
    directoryLog :: Maybe FilePath,
    serviceName :: T.Text,
    runCLI :: Bool,
    searchResults :: Int,
    testing :: Bool
  }

directoryOpts :: FilePath -> FilePath -> Parser DirectoryOpts
directoryOpts appDir defaultDbName = do
  coreOptions <- coreChatOptsP appDir defaultDbName
  adminUsers <-
    option
      parseKnownContacts
      ( long "admin-users"
          <> metavar "ADMIN_USERS"
          <> value []
          <> help "Comma-separated list of admin-users in the format CONTACT_ID:DISPLAY_NAME who will be allowed to manage the directory"
      )
  superUsers <-
    option
      parseKnownContacts
      ( long "super-users"
          <> metavar "SUPER_USERS"
          <> help "Comma-separated list of super-users in the format CONTACT_ID:DISPLAY_NAME who will be allowed to manage the directory"
      )
  ownersGroup <-
    optional $
      option
        parseKnownGroup
        ( long "owners-group"
            <> metavar "OWNERS_GROUP"
            <> help "The group of group owners in the format GROUP_ID:DISPLAY_NAME - owners of listed groups will be invited automatically"
        )
  blockedWordsFile <-
    optional $
      strOption
        ( long "blocked-words-file"
            <> metavar "BLOCKED_WORDS_FILE"
            <> help "File with the basic forms of words not allowed in profiles and groups"
        )
  blockedExtensionRules <-
    optional $
      strOption
        ( long "blocked-extenstion-rules"
            <> metavar "BLOCKED_EXTENSION_RULES"
            <> help "Substitions to extend the list of blocked words"
        )
  nameSpellingFile <-
    optional $
      strOption
        ( long "name-spelling-file"
            <> metavar "NAME_SPELLING_FILE"
            <> help "File with the character substitions to match in profile names"
        )
  profileNameLimit <-
    option
      auto
      ( long "profile-name-limit"
          <> metavar "PROFILE_NAME_LIMIT"
          <> help "Max length of profile name that will be allowed to connect and to join groups"
          <> value maxBound
      )
  acceptAsObserver <-
    optional $
      option
        parseAcceptAsObserver
        ( long "accept-as-observer"
            <> metavar "ACCEPT_AS_OBSERVER"
            <> help "Whether to accept all or some of the joining members without posting rights ('all', 'no-image', 'incognito')"
        )
  directoryLog <-
    Just
      <$> strOption
        ( long "directory-file"
            <> metavar "DIRECTORY_FILE"
            <> help "Append only log for directory state"
        )
  serviceName <-
    strOption
      ( long "service-name"
          <> metavar "SERVICE_NAME"
          <> help "The display name of the directory service bot, without *'s and spaces (SimpleX-Directory)"
          <> value "SimpleX-Directory"
      )
  runCLI <- 
    switch
      ( long "run-cli"
          <> help "Run directory service as CLI"
      )
  pure
    DirectoryOpts
      { coreOptions,
        adminUsers,
        superUsers,
        ownersGroup,
        blockedWordsFile,
        blockedExtensionRules,
        nameSpellingFile,
        profileNameLimit,
        acceptAsObserver,
        directoryLog,
        serviceName = T.pack serviceName,
        runCLI,
        searchResults = 10,
        testing = False
      }

getDirectoryOpts :: FilePath -> FilePath -> IO DirectoryOpts
getDirectoryOpts appDir defaultDbName =
  execParser $
    info
      (helper <*> versionOption <*> directoryOpts appDir defaultDbName)
      (header versionStr <> fullDesc <> progDesc "Start SimpleX Directory Service with DB_FILE, DIRECTORY_FILE and SUPER_USERS options")
  where
    versionStr = versionString versionNumber
    versionOption = infoOption versionAndUpdate (long "version" <> short 'v' <> help "Show version")
    versionAndUpdate = versionStr <> "\n" <> updateStr

mkChatOpts :: DirectoryOpts -> ChatOpts
mkChatOpts DirectoryOpts {coreOptions} =
  ChatOpts
    { coreOptions,
      deviceName = Nothing,
      chatCmd = "",
      chatCmdDelay = 3,
      chatCmdLog = CCLNone,
      chatServerPort = Nothing,
      optFilesFolder = Nothing,
      optTempDirectory = Nothing,
      showReactions = False,
      allowInstantFiles = True,
      autoAcceptFileSize = 0,
      muteNotifications = True,
      markRead = False,
      maintenance = False
    }

parseAcceptAsObserver :: ReadM AcceptAsObserver
parseAcceptAsObserver = eitherReader $ decodeAAO . encodeUtf8 . T.pack
  where
    decodeAAO = \case
      "all" -> Right AOAll
      "name-only" -> Right AONameOnly
      "incognito" -> Right AOIncognito
      _ -> Left "bad AcceptAsObserver"
