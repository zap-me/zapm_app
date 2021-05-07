import 'package:flutter/material.dart';

class MenuItem {
  MenuItem(this.icon, this.label, this.color, this.background, this.action);
  final IconData icon;
  final String label;
  final Color? color;
  final Color? background;
  final Function() action;
}

// https://stackoverflow.com/questions/46480221/flutter-floating-action-button-with-speed-dail
class FabWithIcons extends StatefulWidget {
  FabWithIcons(
      {required this.icon,
      required this.menuItems,
      required this.onTapped,
      required this.onMenuIconTapped,
      required this.expanded});
  final IconData icon;
  final List<MenuItem> menuItems;
  final ValueChanged<bool> onTapped;
  final ValueChanged<MenuItem> onMenuIconTapped;
  final bool expanded;

  @override
  State createState() => FabWithIconsState();
}

class FabWithIconsState extends State<FabWithIcons>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(FabWithIcons oldWidget) {
    if ((_controller.isDismissed || _controller.isAnimating) &&
        widget.expanded) {
      _controller.reset();
      _controller.forward();
    } else if (_controller.isCompleted ||
        _controller.isAnimating && !widget.expanded) {
      _controller.reverse();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.menuItems.length, (int index) {
        return _buildChild(index);
      }).toList()
        ..add(
          _buildFab(),
        ),
    );
  }

  Widget _buildChild(int index) {
    Color backgroundColor = Theme.of(context).cardColor;
    Color foregroundColor = Theme.of(context).accentColor;
    var mi = widget.menuItems[index];
    if (mi.color != null) foregroundColor = mi.color!;
    if (mi.background != null) backgroundColor = mi.background!;
    return Container(
      height: 100.0,
      width: 100.0,
      alignment: FractionalOffset.topCenter,
      child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _controller,
            curve: Interval(0.0, 1.0 - index / widget.menuItems.length / 2.0,
                curve: Curves.easeOut),
          ),
          child: Column(children: [
            FloatingActionButton(
              backgroundColor: backgroundColor,
              mini: false,
              child: Icon(mi.icon, color: foregroundColor),
              onPressed: () => _onTapped(index),
            ),
            SizedBox(height: 5),
            Text(
              mi.label,
              style: TextStyle(color: foregroundColor, fontSize: 12),
            )
          ])),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () {
        widget.onTapped(_controller.isDismissed);
        if (_controller.isDismissed) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      child: Icon(!widget.expanded ? widget.icon : Icons.remove),
      elevation: 2.0,
    );
  }

  void _onTapped(int index) {
    _controller.reverse();
    widget.onMenuIconTapped(widget.menuItems[index]);
  }
}
