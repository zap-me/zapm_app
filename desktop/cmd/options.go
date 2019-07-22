package main

import (
	"github.com/go-flutter-desktop/go-flutter"
    "github.com/go-flutter-desktop/plugins/url_launcher"


)

var options = []flutter.Option{
	flutter.WindowInitialDimensions(800, 600),

    flutter.AddPlugin(&url_launcher.UrlLauncherPlugin{}),
}
