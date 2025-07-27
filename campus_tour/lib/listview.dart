import 'package:flutter/material.dart';

class LocationList extends StatelessWidget {
  const LocationList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Locations"),
        backgroundColor: const Color.fromARGB(255, 52, 209, 94),
        centerTitle: true,
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(color: Colors.black), 
        itemCount: 12,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text("text"),
            subtitle: Text("text")
          ); 
        }),
    );
  }
}