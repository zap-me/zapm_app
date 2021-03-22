import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zapdart/colors.dart';

enum TokenType {
  Waves,
  PayDB
}

// the default testnet value
const TestnetDefault = false;
// the app title
const AppTitle = 'Frankie';
// all instances where the asset short name has the first letter capitalized
const AssetShortName = 'MTOK';
// all instances where the asset short name is lower case
const AssetShortNameLower = 'mtok';
// all instances where the asset short name is upper case
const AssetShortNameUpper = 'MTOK';
// the 'zap' icon on the header of the home page
const AssetHeaderIconPng = 'assets/icon.png';
// the lightning icon on the home page balance widget
const AssetBalanceIconSvg = 'assets/m.svg';
// enable/disable reward UI/feature
const UseReward = false;
// enable/disable settlement UI/feature
const UseSettlement = false;
// enable/disable merchant api (including all references/conversions to NZD)
const UseMerchantApi = false;
// enable/disable a webview homepage (null = disabled)
const String WebviewURL = null;

// are we using the waves network or a paydb server
const TokenType AppTokenType = TokenType.PayDB;

// Waves settings
// set these two to use a different mainnet/testnet asset id pair then the defualt zap asset ids.
const String AssetIdMainnet = null;
const String AssetIdTestnet = null;
// set these two to use a different mainnet/testnet node url pair then the default urls.
const String NodeUrlMainnet = null;
const String NodeUrlTestnet = null;

// PayDB settings
const String PayDBServerMainnet = null;
const String PayDBServerTestnet = 'https://mtoken-test.zap.me/paydb/';

// If set the app will try to register with the premio stage server for push notifications
const String PremioStageIndexUrl = null;
const String PremioStageName = null;
// If set the app will use this api key to get info about centrapay payment requests
// but why/how do we need an api key just to pay an invoice!!
const String CentrapayApiKey = 'PvfgoXxDv2FCzsgVsk1izM41e5tWd7C8AGuThG9M1';

void initConfig() {
  overrideTheme(
    zapWhite: Colors.white,
    zapYellow: Color.fromARGB(255, 237, 29, 38),
    zapWarning: Colors.yellow,
    zapWarningLight: Colors.yellow[100],
    zapBlue: Color.fromARGB(255, 23, 125, 57),
    zapGreen: Colors.yellow,
    zapTextThemer: GoogleFonts.robotoTextTheme);
}
