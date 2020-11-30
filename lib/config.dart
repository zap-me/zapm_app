// uncomment if you need to override the app theme
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_icons/flutter_icons.dart';

import 'package:zapdart/colors.dart';

enum TokenType { Waves, PayDB }

// the default testnet value
const TestnetDefault = false;
// the app title
const AppTitle = 'Frankie';
// all instances where the asset short name has the first letter capitalized
const AssetShortName = 'FP';
// all instances where the asset short name is lower case
const AssetShortNameLower = 'fp';
// all instances where the asset short name is upper case
const AssetShortNameUpper = 'FP';
// the 'zap' icon on the header of the home page
const AssetHeaderIconPng = 'assets/icon.png';
// the lightning icon on the home page balance widget
const AssetBalanceIcon = 'assets/fp.svg';
// whether to disable some repeated/redundant titles
const DontRepeatTitles = true;
// enable/disable reward UI/feature
const UseReward = true;
// enable/disable settlement UI/feature
const UseSettlement = false;
// enable/disable merchant api (including all references/conversions to NZD)
const UseMerchantApi = false;
// enable/disable a webview homepage (null = disabled)
const String? WebviewURL = null;
// enable/disable the centered ZAP button
const ZapButton = true;
const ZapButtonIcon = FlutterIcons.bolt_faw5s;
const TabLabels = false;
// capitalize UI strings
const UseCapitalizeAllWords = false;
const UseCapitalizeFirstWord = false;
const UseCapitalizeAsset = false;

// are we using the waves network or a paydb server
const TokenType AppTokenType = TokenType.PayDB;

// can we claim Redrat Zap tokens
const ClaimRedRatZap =
    false; // when changing this to true you must add the redrat deeplink to the app metadata
// can we buy/sell zap on bronze
const UseBronze = true;

// Waves settings
// set these two to use a different mainnet/testnet asset id pair then the default zap asset ids.
const String? AssetIdMainnet = null;
const String? AssetIdTestnet = null;
// set these two to use a different mainnet/testnet node url pair then the default urls.
const String? NodeUrlMainnet = null;
const String? NodeUrlTestnet = null;

// PayDB settings
const String? PayDBServerMainnet = null;
const String? PayDBServerTestnet = 'https://mtoken-test.zap.me/paydb/';
// registration
const bool RequireMobileNumber = false;
const String? InitialMobileCountry = null;
const List<String>? PreferredMobileCountries = null;
const bool RequireAddress = false;
const String? GooglePlaceApiKeyIOS = null;
const String? GooglePlaceApiKeyAndroid = null;
const String? LocationIqApiKeyIOS = null;
const String? LocationIqApiKeyAndroid = null;

// If set the app will try to register with the premio stage server for push notifications
const String? PremioStageIndexUrl = null;
const String? PremioStageName = null;

// If set the app will add the option of saving (waves) recovery words to the stash server
const String? StashServer = null;

// If set the app will use this api key to get info about centrapay payment requests
// but why/how do we need an api key just to pay an invoice!!
const String? CentrapayApiKey = 'PvfgoXxDv2FCzsgVsk1izM41e5tWd7C8AGuThG9M1';

// PremioPay scheme and prefix (also needs to be changed in AndroidManifest.xml and Info.plist)
const String PremioPayScheme = 'premiofrankiepoints';
const String PremioPayPrefix = '$PremioPayScheme://';

// PremioStageLink scheme and prefix (also needs to be changed in AndroidManifest.xml and Info.plist)
const String PremioStageLinkScheme = 'premiostagefrankiepoints';

void initConfig() {
  overrideTheme(
      zapWhite: Colors.white,
      zapYellow: Color.fromARGB(255, 218, 62, 82), //DA3E52 ~Amaranth
      zapYellowGradient: LinearGradient(colors: [Color.fromARGB(255, 218, 62, 82), Color.fromARGB(255, 230, 70, 90)]),
      zapWarning: Colors.yellow,
      zapWarningLight: Colors.yellow[100],
      zapBlue: Color.fromARGB(255, 20, 89, 29), //14591D ~Lincoln Green
      zapBlueGradient: LinearGradient(colors: [Color.fromARGB(255, 20, 89, 29), Color.fromARGB(255, 40, 100, 40)]),
      zapGreen: Color.fromARGB(255, 240, 162, 2), //F0A202 ~Marigold
      zapGreenGradient: LinearGradient(colors: [Color.fromARGB(255, 240, 162, 2), Color.fromARGB(255, 255, 180, 20)]),
      zapOutgoingFunds: Colors.red,
      zapIncomingFunds: Colors.green,
      zapTextThemer: GoogleFonts.robotoTextTheme);
}
