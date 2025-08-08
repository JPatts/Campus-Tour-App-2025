import 'package:campus_tour/main.dart';
import 'package:campus_tour/models/hotspot.dart';
import 'package:flutter/material.dart';

class LocationList extends MyApp{
  const LocationList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Hotspot> children = myService.getHostpots();
    return Scaffold(
      appBar: AppBar(
        title: Text("Locations"),
        backgroundColor: const Color.fromARGB(255, 52, 209, 94),
        centerTitle: true,
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) => Divider(color: Colors.grey), 
        itemCount: children.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(children[index].name),
            subtitle: Text(children[index].description)
          ); 
        },
        hitTestBehavior: HitTestBehavior.translucent,),
    );
  }
}