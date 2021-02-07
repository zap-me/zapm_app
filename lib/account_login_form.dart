import 'package:flutter/material.dart';

class AccountLogin {
  final String email;
  final String password;

  AccountLogin(this.email, this.password);
}

class AccountLoginForm extends StatefulWidget {
  final String instructions;
  
  AccountLoginForm({this.instructions}) : super();

  @override
  AccountLoginFormState createState() {
    return AccountLoginFormState();
  }
}

class AccountLoginFormState extends State<AccountLoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(child: Container(), preferredSize: Size(0, 0),),
      body: Container(padding: EdgeInsets.all(20), child: Center(child: Column(
        children: <Widget>[
          Text(widget.instructions == null ? "Enter your email and password to login" : widget.instructions),
          TextField(controller: _emailController),
          TextField(controller: _passwordController),
          RaisedButton(
            child: Text("Ok"),
            onPressed: () {
              var accountLogin = AccountLogin(_emailController.text, _passwordController.text);
              Navigator.of(context).pop(accountLogin);
            },
          ),
          RaisedButton(
            child: Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      )))
    );
  }
}
