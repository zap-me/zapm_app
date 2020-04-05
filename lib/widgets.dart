import 'package:flutter/material.dart';
import 'package:flushbar/flushbar.dart';

const zapgrey =         Color(0xFFF8F6F1);
const zapblue =         Color(0xFF3765CB);
const zapyellow =       Color(0xFFFFBB00);
const zapgreen =        Color(0xFF009075);
const zapwarning =      zapyellow;
const zapwarninglight = Color(0x80FFBB00);

enum MessageCategory {
  Info,
  Warning,
}

Widget backButton(BuildContext context) {
  return IconButton(icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.subtitle2.color), onPressed: () => Navigator.of(context).pop());
}


void flushbarMsg(BuildContext context, String msg, {int seconds = 3, MessageCategory category = MessageCategory.Info}) {
  IconData icon;
  switch (category) {
    case MessageCategory.Info:
      icon = Icons.info;
      break;
    case MessageCategory.Warning:
      icon = Icons.warning;
      break;
  }
  Flushbar(
    messageText: Text(msg, style: TextStyle(color: zapblue)),
    icon: Icon(icon, size: 28.0, color: category == MessageCategory.Info ? zapblue : zapwarning),
    duration: Duration(seconds: seconds),
    leftBarIndicatorColor: zapblue,
    backgroundColor: Colors.white,
  )..show(context);
}

class RoundedButton extends StatelessWidget {
  RoundedButton(this.onPressed, this.textColor, this.fillColor, this.title, {this.icon, this.borderColor}) : super();

  final VoidCallback onPressed;
  final Color textColor;
  final Color fillColor;
  final String title;
  final IconData icon;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    Widget child = Text(title, style: TextStyle(color: textColor, fontSize: 14));
    if (icon != null)
      child = Row(children: <Widget>[
        Icon(icon, color: textColor, size: 14),
        SizedBox.fromSize(size: Size(4, 1)),
        child]);
    var _borderColor = borderColor != null ? borderColor : fillColor;
    return RaisedButton(
      child: child, 
      color: fillColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0), side: BorderSide(color: _borderColor)),
      onPressed: onPressed);
  }
}

class SquareButton extends StatelessWidget {
  SquareButton(this.onPressed, this.icon, this.color, this.title) : super();

  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(width: 5.0, color: color),
              color: color
            ),
            child: Container(
              padding: EdgeInsets.all(30),
              child: Icon(icon, color: Colors.white)
            )
          ),
        ),
        SizedBox.fromSize(size: Size(1, 12)),
        Text(title, style: TextStyle(fontSize: 10, color: zapblue))
      ],
    );
  }
}

class ListButton extends StatelessWidget {
  ListButton(this.onPressed, this.title, this.last) : super();

  final VoidCallback onPressed;
  final String title;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onPressed,
          child: Column(
            children: <Widget>[
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('  $title'), Icon(Icons.arrow_right, color: Theme.of(context).highlightColor,)
              ]),
              Visibility(
                visible: last,
                child: Divider()
              )
            ],
          ),
        ),
      ],
    );
  }
}

class AlertDrawer extends StatelessWidget {
  AlertDrawer(this.onPressed, this.alerts) : super();

  final VoidCallback onPressed;
  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onPressed,
          child: Container(color: zapwarninglight,
            child: Column(
              children: List<Widget>.generate(alerts.length, (index) {
                return Container(
                  padding: EdgeInsets.all(8),
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: zapwarning))),
                  child: Text(alerts[index], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54))
                );
              })
            )
          ),
        ),
      ],
    );
  }
}

class CustomCurve extends CustomPainter{
  CustomCurve(this.color, this.curveStart, this.curveBottom) : super();

  final Color color;
  final double curveStart;
  final double curveBottom;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    var paint = Paint();
    path.moveTo(0, 0);
    path.lineTo(0, curveStart);
    path.quadraticBezierTo(size.width / 2, curveBottom, size.width, curveStart);
    path.lineTo(size.width, 0);
    path.close();
    paint.color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

}