import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zapdart/colors.dart';

// the default testnet value
const TestnetDefault = false;
// the app title
const AppTitle = 'M Token';
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
const String WebviewURL = 'https://sites.google.com/view/frankiecms/home';
// set these two to use a different mainnet/testnet asset id pair then the defualt zap asset ids.
const String AssetIdMainnet = null;
const String AssetIdTestnet = null;
// set these two to use a different mainnet/testnet node url pair then the default urls.
const String NodeUrlMainnet = 'https://node.zap.me';
const String NodeUrlTestnet = null;
// If set the app will try to register with the premio stage server for push notifications
const String PremioStageIndexUrl = null;
const String PremioStageName = null;

void initConfig() {
  overrideTheme(
    zapWhite: Colors.white,
    zapYellow: Color.fromARGB(255, 255, 65, 93),
    zapWarning: Colors.yellow,
    zapWarningLight: Colors.yellow[100],
    zapBlue: Color.fromARGB(255, 7, 65, 173),
    zapGreen: Color.fromARGB(255, 123, 216, 58),
    zapTextThemer: GoogleFonts.robotoTextTheme);
}
