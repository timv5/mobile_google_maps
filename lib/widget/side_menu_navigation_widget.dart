import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SideMenuNavigationWidget extends StatelessWidget {

  final Function onTap;

  const SideMenuNavigationWidget(this.onTap);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Drawer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.map),
              title: Text("Polyline map"),
              onTap: ()=>onTap(0),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: Text("Directions Map"),
              onTap: ()=>onTap(1),
            ),
          ],
        ),
      ),
    );
  }
}
