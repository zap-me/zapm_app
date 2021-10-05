import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uni_links/uni_links.dart';
import 'package:synchronized/synchronized.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'package:zapdart/colors.dart';
import 'package:zapdart/qrwidget.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/libzap.dart';

import 'config.dart';
import 'send_receive.dart';
import 'reward.dart';
import 'settlement.dart';
import 'settings.dart';
import 'transactions.dart';
import 'merchant.dart';
import 'centrapay.dart';
import 'firebase.dart';
import 'paydb.dart';
import 'qrscan.dart';
import 'wallet_state.dart';
import 'fab_with_icons.dart';
import 'redrat.dart';
import 'bronze.dart';
import 'webview.dart';
import 'ui_strings.dart';

void main() async {
  // print flutter errors to console
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    const bool kReleaseMode =
        bool.fromEnvironment('dart.vm.product', defaultValue: false);
    if (kReleaseMode) exit(1);
  };

  // initialize any config functions
  initConfig();

  runApp(Phoenix(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => dismissKeyboard(context),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppTitle,
          theme: ThemeData(
            brightness: ZapBrightness,
            primaryColor: ZapWhite,
            accentColor: ZapBlue,
            textTheme: ZapTextThemer(Theme.of(context).textTheme),
            primaryTextTheme: ZapTextThemer(Theme.of(context).textTheme),
          ),
          home: ZapHomePage(AppTitle),
        ));
  }
}

class ZapHomePage extends StatefulWidget {
  ZapHomePage(this.title, {Key? key}) : super(key: key);

  final String title;

  @override
  _ZapHomePageState createState() => new _ZapHomePageState();
}

class _ZapHomePageState extends State<ZapHomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  StreamSubscription? _uniLinksSub; // uni links subscription

  bool _showAlerts = true;
  String? _previousUniUri;
  final Lock _previousUniUriLock = Lock();
  FCM? _fcm;
  final audioPlayer = AudioCache();
  bool _walletOrAcctInited = false;
  bool _walletOrAcctLoading = false;
  AppVersion? _appVersion;
  late TabController _tabController;
  late WalletState _ws;
  bool _updatingBalance = true;
  bool _fabExpanded = false;

  _ZapHomePageState() {
    _ws = WalletState(_txNotification, _walletStateUpdate);
    _tabController = TabController(vsync: this, length: _buildTabCount());
    _tabController.addListener(_tabChange);
  }

  @override
  void initState() {
    // add WidgetsBindingObserver
    WidgetsBinding.instance?.addObserver(this);
    // init async stuff
    _init();
    super.initState();
  }

  @override
  void dispose() {
    _ws.dispose();
    // remove WidgetsBindingObserver
    WidgetsBinding.instance?.removeObserver(this);
    // close uni links subscription
    _uniLinksSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("App lifestyle state changed: $state");
    if (state == AppLifecycleState.resumed) if (AppTokenType == TokenType.Waves)
      _ws.watchAddress(context);
  }

  Future<bool> processUri(String uri) async {
    print('$uri');

    switch (AppTokenType) {
      case TokenType.Waves:
        // process waves links
        //
        // waves://<addr>...
        //
        var result = parseWavesUri(_ws.testnet, uri);
        if (result.error == NO_ERROR) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SendScreen(_ws, uri)),
          );
          if (tx != null) _updateBalance();
          return true;
        }
        // process redrat deep links
        //
        // https://www.redrat.co.nz/zap-rebate?i={i}&h={h}
        //
        if (ClaimRedRatZap) {
          var claimCode = await RRClaimCode.parseDeepLink(uri, _ws.testnet);
          if (claimCode != null) {
            var failed = false;
            var resultText = '';
            showAlertDialog(context, 'claiming payment..');
            try {
              if (await rrClaim(
                  claimCode, _ws.testnet, _ws.addrOrAccountValue())) {
                resultText = 'claimed funds to ${_ws.addrOrAccountValue()}';
                _updateBalance();
              } else {
                resultText = 'claim link failed';
                failed = true;
              }
            } catch (e) {
              resultText = 'claim link failed: $e';
              failed = true;
            }
            Navigator.pop(context);
            flushbarMsg(context, resultText,
                category:
                    failed ? MessageCategory.Warning : MessageCategory.Info);
            return true;
          }
        }
        break;
      case TokenType.PayDB:
        // process paydb links
        //
        // <PremioPayScheme>://<acct>...
        //
        if (PayDbUri.parse(uri) != null) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SendScreen(_ws, uri)),
          );
          if (tx != null) _updateBalance();
          return true;
        }
        break;
    }

    // process premio stage links (scheme parameter is optional - default to 'https')
    //
    // <PremioStageLinkScheme>://<HOST>/claim_payment/<CLAIM_CODE>[?scheme=<SCHEME>]
    //
    var uri2 = Uri.tryParse(uri);
    if (uri2 != null && uri2.isScheme(PremioStageLinkScheme)) {
      if (uri2.pathSegments.length == 2 &&
          uri2.pathSegments[0] == 'claim_payment') {
        var scheme = 'https';
        if (uri2.queryParameters.containsKey('scheme'))
          scheme = uri2.queryParameters['scheme']!;
        var url = uri2.replace(scheme: scheme);
        var body = {};
        var recipient = _ws.addrOrAccountValue();
        switch (AppTokenType) {
          case TokenType.Waves:
            if (recipient.isEmpty)
              throw FormatException(
                  'wallet address must be valid to claim payment');
            body = {'recipient': recipient, 'asset_id': LibZap().assetIdGet()};
            break;
          case TokenType.PayDB:
            if (recipient.isEmpty)
              throw FormatException(
                  'account email must be valid to claim payment');
            body = {'recipient': recipient};
            break;
        }
        var resultText = '';
        var failed = false;
        showAlertDialog(context, 'claiming payment..');
        try {
          var response = await httpPost(url, body);
          if (response.statusCode == 200) {
            resultText = 'claimed funds to $recipient';
            _updateBalance();
          } else {
            resultText =
                'claim link failed: ${response.statusCode} - ${response.body}';
            failed = true;
          }
        } catch (e) {
          resultText = 'claim link failed: $e';
          failed = true;
        }
        Navigator.pop(context);
        flushbarMsg(context, resultText,
            category: failed ? MessageCategory.Warning : MessageCategory.Info);
        return true;
      }
    }

    // process centrapay links
    //
    // http://app.centrapay.com/pay/<REQUEST_ID>
    //
    if (CentrapayApiKey != null) {
      var qr = centrapayParseQrcode(uri);
      if (qr != null) {
        var tx = await Navigator.push<Tx>(
          context,
          MaterialPageRoute(builder: (context) => CentrapayScreen(_ws, qr)),
        );
        if (tx != null) _updateBalance();
        return true;
      }
    }

    // did not recognize uri
    return false;
  }

  Future<Null> initUniLinks() async {
    // Check if the app was started with a link
    try {
      var initialUri = await getInitialLink();
      if (initialUri != null) {
        if (!await processUri(initialUri))
          flushbarMsg(context, 'invalid URL',
              category: MessageCategory.Warning);
      }
    } on FormatException {
      print('intial uri format exception!');
    } on PlatformException {
      print('intial uri platform exception!');
    } catch (e) {
      print('intial uri exception: $e');
    }

    // Attach a listener to catch any links when app is running in the background
    _uniLinksSub = linkStream.listen((String? uri) async {
      await _previousUniUriLock.synchronized(() async {
        if (_previousUniUri != uri) {
          // this seems to be invoked twice so ignore the second one
          if (uri != null && !await processUri(uri))
            flushbarMsg(context, 'invalid URL',
                category: MessageCategory.Warning);
          _previousUniUri = uri;
        }
      });
      // clear the uri here so the user can manually invoke twice
      Future.delayed(const Duration(seconds: 2), () => _previousUniUri = null);
    }, onError: (err) {
      print('uri stream error: $err');
    });
  }

  void _txNotification(String txid, String sender, String recipient,
      double amount, String? attachment) {
    var amountString = "${amount.toStringAsFixed(2)} $AssetShortNameUpper";
    // convert amount to NZD
    if (_ws.rates != null) {
      var amountDec = Decimal.parse(amount.toString());
      amountString += " / ${toNZDAmount(amountDec, _ws.rates!)}";
    }
    // decode attachment
    if (attachment != null && attachment.isNotEmpty)
      try {
        attachment = base58decodeString(attachment);
      } catch (_) {}
    // play audio file
    audioPlayer.play('chaching.mp3');
    // show user overview of new tx
    showDialog(
        context: context,
        barrierDismissible:
            false, // dialog is dismissible with a tap on the barrier
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("received $amountString"),
            content: Container(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(title: Text("TXID"), subtitle: Text(txid)),
                  ListTile(
                    title: Text("sender"),
                    subtitle: Text(sender),
                  ),
                  ListTile(title: Text("amount"), subtitle: Text(amountString)),
                  ListTile(
                      title: Text(attachment != null && attachment.isNotEmpty
                          ? "attachment"
                          : ""),
                      subtitle: Text(attachment != null && attachment.isNotEmpty
                          ? attachment
                          : "")),
                ],
              ),
            ),
            actions: [
              RoundedButton(
                  () => Navigator.pop(context), ZapBlue, ZapWhite, null, 'ok',
                  borderColor: ZapBlue),
            ],
          );
        });
    if (UseMerchantApi)
      // alert server to update merchant tx table
      merchantTx();
    // update balance
    _updateBalance();
  }

  void _showQrCode() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Align(
            alignment: Alignment.center,
            child: Card(
                child: InkWell(
                    child: Container(
                        width: 300,
                        height: 300,
                        child: QrWidget(_ws.addrOrAccountValue(), size: 300)),
                    onTap: () => Navigator.pop(context))));
      },
    );
  }

  void _copyAddrOrAccount() {
    Clipboard.setData(ClipboardData(text: _ws.addrOrAccountValue()))
        .then((value) {
      flushbarMsg(context, 'copied ${_ws.addrOrAccount()} to clipboard');
    });
  }

  void _scanQrCode() async {
    var value = await QrScan.scan(context);
    if (value == null) return;

    switch (AppTokenType) {
      case TokenType.Waves:
        // waves address or uri
        var result = parseRecipientOrWavesUri(_ws.testnet, value);
        if (result != null) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SendScreen(_ws, value)),
          );
          if (tx != null) _updateBalance();
          return;
        }
        // merchant claim code
        var ccresult = parseClaimCodeUri(value);
        if (ccresult.error == NO_ERROR) {
          var failed = false;
          var resultText = '';
          showAlertDialog(context, 'claiming payment..');
          try {
            if (await merchantClaim(ccresult.code, _ws.addrOrAccountValue()))
              resultText = 'claimed funds to ${_ws.addrOrAccountValue()}';
            else {
              resultText = 'claim link failed';
              failed = true;
            }
          } catch (e) {
            resultText = 'claim link failed: $e';
            failed = true;
          }
          Navigator.pop(context);
          flushbarMsg(context, resultText,
              category:
                  failed ? MessageCategory.Warning : MessageCategory.Info);
          return;
        }
        // redrat claim code
        if (ClaimRedRatZap) {
          var claimCode = RRClaimCode.parseQrCode(value);
          if (claimCode != null) {
            var failed = false;
            var resultText = '';
            showAlertDialog(context, 'claiming payment..');
            try {
              if (await rrClaim(
                  claimCode, _ws.testnet, _ws.addrOrAccountValue()))
                resultText = 'claimed funds to ${_ws.addrOrAccountValue()}';
              else {
                resultText = 'claim link failed';
                failed = true;
              }
            } catch (e) {
              resultText = 'claim link failed: $e';
              failed = true;
            }
            Navigator.pop(context);
            flushbarMsg(context, resultText,
                category:
                    failed ? MessageCategory.Warning : MessageCategory.Info);
          }
        }
        break;
      case TokenType.PayDB:
        // paydb recipient or uri
        if (paydbParseValid(value)) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SendScreen(_ws, value)),
          );
          if (tx != null) _updateBalance();
          return;
        }
        break;
    }
    // other uris we support
    try {
      if (!await processUri(value))
        flushbarMsg(context, 'invalid QR code',
            category: MessageCategory.Warning);
    } on FormatException {
      flushbarMsg(context, 'invalid QR code',
          category: MessageCategory.Warning);
    }
  }

  void _send() async {
    var tx = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SendScreen(_ws, '')),
    );
    if (tx != null) _updateBalance();
  }

  void _receive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ReceiveScreen(
              _ws.testnet, _ws.addrOrAccountValue(), _txNotification)),
    );
  }

  void _buyZap() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => BronzeScreen(_ws, BronzeSide.Buy)));
  }

  void _sellZap() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => BronzeScreen(_ws, BronzeSide.Sell)));
  }

  bool _canReward() {
    switch (AppTokenType) {
      case TokenType.Waves:
        return UseMerchantApi &&
            UseReward &&
            _ws.haveCapabililty(Capability.Spend);
      case TokenType.PayDB:
        return UseReward &&
            (_ws.haveRole(PayDbRole.admin) ||
                _ws.haveRole(PayDbRole.authorizer));
    }
  }

  void _reward() async {
    var sentFunds = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) =>
              RewardScreen(_ws.walletMnemonic, _ws.fee, _ws.balance)),
    );
    if (sentFunds == true) _updateBalance();
  }

  void _settlement() async {
    var sentFunds = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SettlementScreen(_ws.walletMnemonic, _ws.fee, _ws.balance)),
    );
    if (sentFunds == true) _updateBalance();
  }

  void _toggleAlerts() {
    setState(() => _showAlerts = !_showAlerts);
  }

  void _init() async {
    // get app version
    _appVersion = await AppVersion.parsePubspec();
    setState(() {
      _appVersion = _appVersion;
    });
    // init wallet state
    await _ws.init(context);
    // init firebase push notifications
    _fcm = FCM(context, PremioStageIndexUrl, PremioStageName);
    // init uni links
    initUniLinks();
  }

  Future<void> _updateBalance() async {
    await _ws.updateBalance();
  }

  void _walletStateUpdate(
      WalletState ws, bool updatingBalance, bool loading, bool inited) {
    setState(() {
      _updatingBalance = updatingBalance;
      _walletOrAcctLoading = loading;
      _walletOrAcctInited = inited;
      _ws = _ws;
    });
  }

  void _tabChange() {
    print(_tabController.index);
    if (_tabController.index == _buildTabCount() ~/ 2)
      _tabController.index = _tabController.previousIndex;
  }

  int _buildTabCount() {
    var count = 3;
    if (WebviewURL != null) count++;
    if (ZapButton) count++;
    return count;
  }

  ScrollPhysics _buildTabPhysics() {
    return WebviewURL != null || ZapButton
        ? NeverScrollableScrollPhysics()
        : ClampingScrollPhysics();
  }

  Widget _tab(IconData icon, String label) {
    var fontSize = 8.0;
    var iconSize = 24.0;
    var ssc = ScreenSizeClass.calc(context);
    if (ssc.width != DimensionClass.Small) {
      fontSize = 10;
      iconSize = 28;
    }
    if (ssc.width == DimensionClass.Large &&
        ssc.height != DimensionClass.Small) {
      fontSize = 12;
      iconSize = 32;
    }
    var ico = Icon(icon, size: iconSize, color: ZapBlue);
    var txt = Text(
      label,
      style: TextStyle(color: ZapBlue, fontSize: fontSize),
      overflow: TextOverflow.visible,
      maxLines: 1,
    );
    return Tab(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: TabLabels ? [ico, txt] : [ico],
    ));
  }

  List<Widget> _buildTabs() {
    var tabs = [
      _tab(Icons.account_balance_wallet_outlined,
          _ws.walletOrAccount().toUpperCase()),
      _tab(FlutterIcons.swap_horizontal_bold_mco, 'HISTORY'),
      _tab(Icons.settings_applications_outlined, 'SETTINGS'),
    ];
    if (WebviewURL != null) {
      tabs.insert(0, _tab(Icons.home_outlined, 'HOME'));
    }
    if (ZapButton) {
      tabs.insert(tabs.length ~/ 2, Tab(child: SizedBox()));
    }
    return tabs;
  }

  FabWithIcons _buildFab() {
    var menuItems = [
      MenuItem(
          MaterialCommunityIcons.chevron_double_down,
          'RECEIVE $AssetShortNameUpper',
          ZapWhite,
          ZapGreen,
          ZapGreenGradient,
          _receive),
    ];
    if (_ws.haveCapabililty(Capability.Spend)) {
      menuItems = [
            MenuItem(
                MaterialCommunityIcons.chevron_double_up,
                'SEND $AssetShortNameUpper',
                ZapWhite,
                ZapYellow,
                ZapYellowGradient,
                _send),
            MenuItem(MaterialCommunityIcons.qrcode_scan, 'SCAN QR CODE',
                ZapWhite, ZapBlue, ZapBlueGradient, _scanQrCode)
          ] +
          menuItems;
    }
    if (_canReward())
      menuItems.insert(
          0,
          MenuItem(MaterialCommunityIcons.gift, '$AssetShortNameUpper REWARDS',
              ZapWhite, ZapBlue, ZapBlueGradient, _reward));
    if (UseBronze && AppTokenType == TokenType.Waves) {
      if (_ws.haveCapabililty(Capability.Spend))
        menuItems.insert(
            0,
            MenuItem(Icons.trending_down, 'SELL ZAP', ZapWhite, ZapBlue,
                ZapBlueGradient, _sellZap));
      menuItems.insert(
          0,
          MenuItem(Icons.trending_up, 'BUY ZAP', ZapWhite, ZapBlue,
              ZapBlueGradient, _buyZap));
    }
    var fabSize = 56.0;
    var ssc = ScreenSizeClass.calc(context);
    if (ssc.width != DimensionClass.Small) fabSize = 60;
    if (ssc.width == DimensionClass.Large) fabSize = 64;
    return FabWithIcons(
      icon: ZapButtonIcon,
      menuItems: menuItems,
      onTapped: _fabTapped,
      onMenuIconTapped: _selectedMenuItem,
      expanded: _fabExpanded,
      size: fabSize,
    );
  }

  void _fabTapped(bool expanded) {
    setState(() => _fabExpanded = expanded);
  }

  void _selectedMenuItem(MenuItem item) {
    print('FAB: ${item.label}');
    setState(() => _fabExpanded = false);
    item.action();
  }

  List<Widget> _buildTabBodies(Widget body) {
    var content = [body, TransactionsScreen(_ws), SettingsScreen(_ws, _fcm)];
    if (WebviewURL != null) {
      content.insert(0, Webview(WebviewURL!, WebviewURLWhitelist));
    }
    if (ZapButton) {
      content.insert(content.length ~/ 2, Text('dummy tab'));
    }
    return content;
  }

  Widget _buildPrice({bool small = false}) {
    const smIndicator = 14.0;
    const lgIndicator = 28.0;
    const smFont = 12.0;
    const lgFont = 28.0;
    const smIcon = 12.0;
    const lgIcon = 20.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _updatingBalance
            ? SizedBox(
                child: CircularProgressIndicator(strokeWidth: small ? 2 : 4),
                height: small ? smIndicator : lgIndicator,
                width: small ? smIndicator : lgIndicator)
            : Text(_ws.balanceText,
                style: TextStyle(
                    color: ZapBlue, fontSize: small ? smFont : lgFont)),
        SizedBox(width: 4),
        AssetBalanceIcon == null
            ? Text(AssetShortNameUpper,
                style: TextStyle(
                    color: ZapBlue, fontSize: small ? smFont : lgFont))
            : AssetBalanceIcon!.toLowerCase().endsWith('.svg')
                ? SvgPicture.asset(AssetBalanceIcon!,
                    height: small ? smIcon : lgIcon)
                : Image.asset(AssetBalanceIcon!,
                    height: small ? smIcon : lgIcon),
        SizedBox(width: small ? 2 : 0),
      ],
    );
  }

  Widget _appScaffold(Widget body) {
    var navHeight = 50.0;
    var ssc = ScreenSizeClass.calc(context);
    if (ssc.height != DimensionClass.Small) navHeight = 55;
    if (ssc.height == DimensionClass.Large) navHeight = 60;
    var fab = _buildFab();
    return Stack(alignment: Alignment.bottomCenter, children: [
      Scaffold(
          appBar: AppBar(
              title: Stack(alignment: AlignmentDirectional.center, children: [
            Positioned(
                left: 0,
                child: Visibility(
                    child: IconButton(
                        onPressed: _toggleAlerts,
                        icon: Icon(Icons.warning,
                            color: _showAlerts ? ZapGrey : ZapWarning)),
                    visible: _ws.alerts.length > 0)),
            Align(child: Image.asset(AssetHeaderIconPng, height: 30)),
            Positioned(right: 0, child: _buildPrice(small: true)),
          ])),
          bottomNavigationBar: SizedBox(
              height: navHeight,
              child: Container(
                  decoration: BoxDecoration(color: ZapWhite, boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 3,
                        blurRadius: 5,
                        offset: Offset(-3, 0))
                  ]),
                  child: TabBar(
                      controller: _tabController,
                      tabs: _buildTabs(),
                      labelPadding: EdgeInsets.symmetric(horizontal: 4)))),
          body: Column(children: [
            Visibility(
                visible: _showAlerts && _ws.alerts.length > 0,
                child: AlertDrawer(_toggleAlerts, _ws.alerts)),
            Expanded(
                child: TabBarView(
              physics: _buildTabPhysics(),
              controller: _tabController,
              children: _buildTabBodies(body),
            ))
          ])),
      _fabExpanded
          ? GestureDetector(
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
              onTap: () {
                setState(() => _fabExpanded = false);
              },
            )
          : SizedBox(),
      Positioned(
        child: fab,
        bottom: 5,
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_walletOrAcctInited)
      return Scaffold(
          body: Column(children: [
        SizedBox(height: 100),
        Center(child: Image.asset(AssetHeaderIconPng, height: 30)),
        Visibility(
            visible: _appVersion != null,
            child: Center(
                child: Text("${_appVersion?.version}+${_appVersion?.build}",
                    style: TextStyle(fontSize: 10)))),
        SizedBox(height: 50),
        Visibility(
            visible: _walletOrAcctLoading,
            child: SizedBox(
                child: CircularProgressIndicator(), height: 28.0, width: 28.0))
      ]));

    return _appScaffold(
      RefreshIndicator(
        onRefresh: _updateBalance,
        child: ListView(
          children: [
            Visibility(
                visible: _ws.haveCapabililty(Capability.Balance),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(top: 28.0),
                      child: Text(
                        capFirst('my balance:'),
                        style: TextStyle(
                            color: ZapBlackMed, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      height: 100,
                      width: MediaQuery.of(context).size.width,
                      child: Card(
                        child: Align(
                            alignment: Alignment.center, child: _buildPrice()),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        margin: EdgeInsets.all(10),
                      ),
                    ),
                  ],
                )),
            Visibility(
                visible: _ws.haveCapabililty(Capability.Receive),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.only(top: 28.0),
                    child: Text(capFirst('${_ws.addrOrAccount()}:'),
                        style: TextStyle(
                            color: ZapBlackMed, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                  Container(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ws.profileImage(),
                            Text(_ws.addrOrAccountValue(),
                                style: TextStyle(color: ZapBlackLight),
                                textAlign: TextAlign.center),
                          ])),
                  Divider(),
                  ZapButton
                      ? Container(
                          child: Column(children: [
                          QrWidget(_ws.addrOrAccountValue(), size: 200),
                          RoundedButton(
                            _copyAddrOrAccount,
                            ZapWhite,
                            ZapBlue,
                            ZapBlueGradient,
                            capFirst('copy ${_ws.addrOrAccount()}'),
                            icon: Icons.copy,
                            width: MediaQuery.of(context).size.width / 2,
                          )
                        ]))
                      : Container(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                              RoundedButton(_showQrCode, ZapBlue, ZapWhite,
                                  null, 'view QR code',
                                  icon: MaterialCommunityIcons.qrcode,
                                  width: MediaQuery.of(context).size.width / 2 -
                                      20),
                              RoundedButton(
                                  _copyAddrOrAccount,
                                  ZapWhite,
                                  ZapBlue,
                                  ZapBlueGradient,
                                  'copy ${_ws.addrOrAccount()}',
                                  width: MediaQuery.of(context).size.width / 2 -
                                      20),
                            ]))
                ])),
            ZapButton
                ? SizedBox()
                : Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.only(top: 20),
                    color: ZapWhite,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget?>[
                            _ws.haveCapabililty(Capability.Spend)
                                ? SquareButton(
                                    _send,
                                    MaterialCommunityIcons.chevron_double_up,
                                    ZapYellow,
                                    'SEND $AssetShortNameUpper')
                                : null,
                            _ws.haveCapabililty(Capability.Spend)
                                ? SquareButton(
                                    _scanQrCode,
                                    MaterialCommunityIcons.qrcode_scan,
                                    ZapBlue,
                                    'SCAN QR CODE')
                                : null,
                            SquareButton(
                                _receive,
                                MaterialCommunityIcons.chevron_double_down,
                                ZapGreen,
                                'RECEIVE $AssetShortNameUpper'),
                          ]
                              .where((child) => child != null)
                              .toList()
                              .cast<Widget>(),
                        ),
                        SizedBox.fromSize(size: Size(1, 10)),
                        Visibility(
                          visible: _canReward(),
                          child: ListButton(
                              _reward, '$AssetShortNameLower rewards'),
                        ),
                        Visibility(
                          visible: _ws.haveCapabililty(Capability.Spend) &&
                              UseSettlement,
                          child: ListButton(_settlement, 'make settlement'),
                        ),
                        ListButtonEnd(),
                      ],
                    )),
          ],
        ),
      ),
    );
  }
}
