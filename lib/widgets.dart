import 'package:flutter/material.dart';

const zapblue = Color(0xFF3765CB);
const zapyellow = Color(0xFFFFBB00);
const zapgreen = Color(0xFF009075);

class SquareButton extends StatelessWidget {
  SquareButton(this.onPressed, this.icon, this.color, this.title) : super();

  final VoidCallback onPressed;
  final Image icon;
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
              child: icon
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
                  Text('  $title'), Icon(Icons.arrow_right)
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