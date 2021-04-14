// uncomment if you need to override the app theme
//import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';

import 'package:zapdart/colors.dart';

enum TokenType { Waves, PayDB }

// the default testnet value
const TestnetDefault = false;
// the app title
const AppTitle = 'Zap Retailer';
// all instances where the asset short name has the first letter capitalized
const AssetShortName = 'Zap';
// all instances where the asset short name is lower case
const AssetShortNameLower = 'zap';
// all instances where the asset short name is upper case
const AssetShortNameUpper = 'ZAP';
// the 'zap' icon on the header of the home page
const AssetHeaderIconPng = 'assets/icon.png';
// the lightning icon on the home page balance widget
const AssetBalanceIconSvg = 'assets/icon-bolt.svg';
// enable/disable reward UI/feature
const UseReward = false;
// enable/disable settlement UI/feature
const UseSettlement = true;
// enable/disable merchant api (including all references/conversions to NZD)
const UseMerchantApi = true;
// enable/disable a webview homepage (null = disabled)
const String? WebviewURL = null;

// are we using the waves network or a paydb server
const TokenType AppTokenType = TokenType.Waves;

// Waves settings
// set these two to use a different mainnet/testnet asset id pair then the default zap asset ids.
const String? AssetIdMainnet = null;
const String? AssetIdTestnet = null;
// set these two to use a different mainnet/testnet node url pair then the default urls.
const String? NodeUrlMainnet = null;
const String? NodeUrlTestnet = null;

// PayDB settings
const String? PayDBServerMainnet = null;
const String? PayDBServerTestnet = null;

// If set the app will try to register with the premio stage server for push notifications
const String? PremioStageIndexUrl = null;
const String? PremioStageName = null;
// If set the app will use this api key to get info about centrapay payment requests
// but why/how do we need an api key just to pay an invoice!!
const String CentrapayApiKey = 'PvfgoXxDv2FCzsgVsk1izM41e5tWd7C8AGuThG9M1';

void initConfig() {
  overrideTheme();
  // example
  /*overrideTheme(
    zapWhite: Colors.lightBlue[50],
    zapYellow: Colors.teal[100],
    zapWarning: Colors.yellow,
    zapWarningLight: Colors.yellow[100],
    zapBlue: Colors.pink[200],
    zapGreen: Colors.blueGrey[300],
    zapTextThemer: GoogleFonts.sansitaTextTheme);
    */
}
