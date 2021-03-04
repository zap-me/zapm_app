import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';

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
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(child: Container(), preferredSize: Size(0, 0),),
      body: Form(key: _formKey,
        child: Container(padding: EdgeInsets.all(20), child: Center(child: Column(
          children: <Widget>[
            Text(widget.instructions == null ? "Enter your email and password to login" : widget.instructions),
            TextFormField(controller: _emailController,
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter an email';
                if (!EmailValidator.validate(value))
                  return 'Invalid email';
                return null;
              }),
            TextFormField(controller: _passwordController, obscureText: true,
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter a password';
                return null;
              }),
            RaisedButton(
              child: Text("Ok"),
              onPressed: () {
                if (_formKey.currentState.validate()) {
                  var accountLogin = AccountLogin(_emailController.text, _passwordController.text);
                  Navigator.of(context).pop(accountLogin);
                }
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
      )
    );
  }
}
