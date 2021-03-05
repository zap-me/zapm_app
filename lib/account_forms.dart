import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'paydb.dart';

class AccountLogin {
  final String email;
  final String password;

  AccountLogin(this.email, this.password);
}

class AccountRegisterForm extends StatefulWidget {
  final String instructions;
  
  AccountRegisterForm({this.instructions}) : super();

  @override
  AccountRegisterFormState createState() {
    return AccountRegisterFormState();
  }
}

class AccountRegisterFormState extends State<AccountRegisterForm> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _imgString;
  String _imgType;

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
  }
  
  void _imgFromCamera() async {
  var file = await ImagePicker().getImage(source: ImageSource.camera, imageQuality: 50);
  var imgString = base64Encode(await file.readAsBytes());
  setState(() {
    _imgString = imgString;
    _imgType = 'raster';
  });
}

void _imgFromGallery() async {
  var file = await  ImagePicker().getImage(source: ImageSource.gallery, imageQuality: 50);
  var imgString = base64Encode(await file.readAsBytes());
  setState(() {
    _imgString = imgString;
    _imgType = 'raster';
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(child: Container(), preferredSize: Size(0, 0),),
      body: Form(key: _formKey,
        child: Container(padding: EdgeInsets.all(20), child: Center(child: Column(
          children: <Widget>[
            Text(widget.instructions == null ? "Enter your details to register" : widget.instructions),
            TextFormField(controller: _firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter a first name';
                return null;
            }),
            TextFormField(controller: _lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
              keyboardType: TextInputType.name,
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter a last name';
                return null;
            }),
            InputDecorator(decoration: InputDecoration(labelText: 'Profile Image'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    paydbAccountImage(_imgString, _imgType),
                    IconButton(icon: Icon(Icons.folder_open), onPressed: _imgFromGallery),
                    IconButton(icon: Icon(Icons.camera), onPressed: _imgFromCamera),
                  ]),
                ],
              ),
            ),
            TextFormField(controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter an email';
                if (!EmailValidator.validate(value))
                  return 'Invalid email';
                return null;
            }),
            TextFormField(controller: _passwordController, obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter a password';
                return null;
            }),
            TextFormField(controller: _passwordConfirmController, obscureText: true,
              decoration: InputDecoration(labelText: 'Password Confirmation'),
              validator: (value) {
                if (value.isEmpty)
                  return 'Please confirm your password';
                if (value != _passwordController.text)
                  return 'Password does not match';
                return null;
            }),
            RaisedButton(
              child: Text("Ok"),
              onPressed: () async {
                if (_formKey.currentState.validate()) {
                  var accountReg = AccountRegistration(_firstNameController.text, _lastNameController.text, _emailController.text, _passwordController.text,
                    _imgString, _imgType);
                  Navigator.of(context).pop(accountReg);
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
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value.isEmpty)
                  return 'Please enter an email';
                if (!EmailValidator.validate(value))
                  return 'Invalid email';
                return null;
              }),
            TextFormField(controller: _passwordController, obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
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
