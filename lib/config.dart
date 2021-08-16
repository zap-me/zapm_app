import 'package:universal_platform/universal_platform.dart';
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
const AssetShortName = 'FRT';
// all instances where the asset short name is lower case
const AssetShortNameLower = 'FRT';
// all instances where the asset short name is upper case
const AssetShortNameUpper = 'FRT';
// the 'zap' icon on the header of the home page
const AssetHeaderIconPng = 'assets/icon.png';
// the lightning icon on the home page balance widget
const AssetBalanceIcon = 'assets/frt.svg';
// whether to disable some repeated/redundant titles
const DontRepeatTitles = true;
// enable/disable reward UI/feature
const UseReward = true;
// enable/disable settlement UI/feature
const UseSettlement = false;
// enable/disable merchant api (including all references/conversions to NZD)
const UseMerchantApi = false;
// enable/disable a webview homepage (null = disabled)
const String? WebviewURL = 'https://www.frankietoken.com';
// enable/disable the centered ZAP button
const ZapButton = true;
const ZapButtonIcon = FlutterIcons.plus_faw5s;
const TabLabels = false;
// capitalize UI strings
const UseCapitalizeAllWords = true;
const UseCapitalizeFirstWord = true;
const UseCapitalizeAsset = true;

// are we using the waves network or a paydb server
const TokenType AppTokenType = TokenType.PayDB;

// can we claim Redrat Zap tokens
const ClaimRedRatZap =
    false; // when changing this to true you must add the redrat deeplink to the app metadata
// can we buy/sell zap on bronze
const UseBronze = false;

// Waves settings
// set these two to use a different mainnet/testnet asset id pair then the default zap asset ids.
const String? AssetIdMainnet = null;
const String? AssetIdTestnet = null;
// set these two to use a different mainnet/testnet node url pair then the default urls.
const String? NodeUrlMainnet = null;
const String? NodeUrlTestnet = null;

// PayDB settings
const String? PayDBServerMainnet = 'https://frankie.zap.me/paydb/';
const String? PayDBServerTestnet = 'https://mtoken-test.zap.me/paydb/';
// registration
const bool RequireMobileNumber = true;
const String? InitialMobileCountry = 'WS';
const List<String>? PreferredMobileCountries = [
  'Samoa',
  'New Zealand',
  'Australia',
  'United States of America'
];
const bool RequireAddress = true;
const String? GooglePlaceApiKeyIOS = null;
const String? GooglePlaceApiKeyAndroid = null;
const String? GooglePlaceApiKeyWeb = null;
const String? LocationIqApiKeyIOS = 'pk.e53109b5fdcb2dfd00bbc57c8b713d79';
const String? LocationIqApiKeyAndroid = 'pk.e53109b5fdcb2dfd00bbc57c8b713d79';
const String? LocationIqApiKeyWeb = 'pk.e53109b5fdcb2dfd00bbc57c8b713d79';

String? googlePlaceApiKey() {
  if (UniversalPlatform.isAndroid) return GooglePlaceApiKeyAndroid;
  if (UniversalPlatform.isIOS) return GooglePlaceApiKeyIOS;
  return GooglePlaceApiKeyWeb;
}

String? locationIqApiKey() {
  if (UniversalPlatform.isAndroid) return LocationIqApiKeyIOS;
  if (UniversalPlatform.isIOS) return LocationIqApiKeyAndroid;
  return LocationIqApiKeyWeb;
}

// If set the app will try to register with the premio stage server for push notifications
const String? PremioStageIndexUrl = null;
const String? PremioStageName = null;

// If set the app will add the option of saving (waves) recovery words to the stash server
const String? StashServer = null;

// If set the app will use this api key to get info about centrapay payment requests
// but why/how do we need an api key just to pay an invoice!!
const String? CentrapayApiKey = 'PvfgoXxDv2FCzsgVsk1izM41e5tWd7C8AGuThG9M1';

// PremioPay scheme and prefix (also needs to be changed in AndroidManifest.xml and Info.plist)
const String PremioPayScheme = 'premiofrankie';
const String PremioPayPrefix = '$PremioPayScheme://';

// PremioStageLink scheme and prefix (also needs to be changed in AndroidManifest.xml and Info.plist)
const String PremioStageLinkScheme = 'premiostagefrankie';

void initConfig() {
  const color = Color.fromARGB(255, 53, 150, 192);
  const grad = LinearGradient(colors: [Color.fromARGB(255, 65, 234, 193), Color.fromARGB(255, 65, 190, 192), Color.fromARGB(255, 53, 150, 192)]);
  overrideTheme(
      zapWhite: Colors.white,
      zapYellow: color,
      zapYellowGradient: grad,
      zapWarning: Colors.yellow,
      zapWarningLight: Colors.yellow[100],
      zapBlue: color,
      zapBlueGradient: grad,
      zapGreen: color,
      zapGreenGradient: grad,
      zapOutgoingFunds: Colors.red,
      zapIncomingFunds: Colors.green,
      zapTextThemer: GoogleFonts.robotoTextTheme);
}
