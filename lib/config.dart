import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zapdart/colors.dart';

// the default testnet value
const TestnetDefault = false;
// the app title
const AppTitle = 'Whitelabel Demo';
// all instances where the asset short name has the first letter capitalized
const AssetShortName = 'OTH';
// all instances where the asset short name is lower case
const AssetShortNameLower = 'oth';
// all instances where the asset short name is upper case
const AssetShortNameUpper = 'OTH';
// the 'zap' icon on the header of the home page
const AssetHeaderIconPng = 'assets/icon.png';
// the lightning icon on the home page balance widget
const AssetBalanceIconSvg = 'assets/oth2.svg';
// enable/disable reward UI/feature
const UseReward = false;
// enable/disable settlement UI/feature
const UseSettlement = false;
// enable/disable merchant api (including all references/conversions to NZD)
const UseMerchantApi = false;
// enable/disable a webview homepage (null = disabled)
const String WebviewURL = 'https://sites.google.com/view/othdemocms/home';
// set these two to use a different mainnet/testnet asset id pair then the defualt zap asset ids.
const String AssetIdMainnet = null;
const String AssetIdTestnet = null;
// If set the app will try to register with the premio stage server for push notifications
const String PremioStageIndexUrl = null;
const String PremioStageName = null;

void initConfig() {
  overrideTheme(
    //zapWhite: Colors.lightBlue[50],
    zapYellow: Colors.deepPurple[200],
    zapWarning: Colors.yellow,
    zapWarningLight: Colors.yellow[100],
    zapBlue: Color.fromRGBO(0x5b, 0xc9, 0xde, 1),
    zapGreen: Colors.green[200],
    zapTextThemer: GoogleFonts.openSansTextTheme);
}
